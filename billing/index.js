/**
 * Import function triggers from their respective submodules:
 *
 * const {onCall} = require("firebase-functions/v2/https");
 * const {onDocumentWritten} = require("firebase-functions/v2/firestore");
 *
 * See a full list of supported triggers at https://firebase.google.com/docs/functions
 */

const admin = require("firebase-admin");
const {setGlobalOptions} = require("firebase-functions");
const {onRequest} = require("firebase-functions/https");
const {onSchedule} = require("firebase-functions/v2/scheduler");
const logger = require("firebase-functions/logger");

// For cost control, you can set the maximum number of containers that can be
// running at the same time. This helps mitigate the impact of unexpected
// traffic spikes by instead downgrading performance. This limit is a
// per-function limit. You can override the limit for each function using the
// `maxInstances` option in the function's options, e.g.
// `onRequest({ maxInstances: 5 }, (req, res) => { ... })`.
// NOTE: setGlobalOptions does not apply to functions using the v1 API. V1
// functions should each use functions.runWith({ maxInstances: 10 }) instead.
// In the v1 API, each function can only serve one request per container, so
// this will be the maximum concurrent request count.
setGlobalOptions({ maxInstances: 10 });

admin.initializeApp();

// Create and deploy your first functions
// https://firebase.google.com/docs/functions/get-started

exports.health = onRequest((request, response) => {
	logger.info("Health check", {structuredData: true});
	response.status(200).send("OK");
});

const db = admin.firestore();

function toJsDate(value) {
	if (!value) return null;
	if (value instanceof Date) return value;
	if (typeof value.toDate === "function") return value.toDate();
	if (value._seconds) return new Date(value._seconds * 1000);
	if (typeof value === "string") return new Date(value);
	return null;
}

async function getUserKeyFromAuth(req) {
	const authHeader = req.headers.authorization || "";
	if (!authHeader.startsWith("Bearer ")) return null;
	const idToken = authHeader.replace("Bearer ", "").trim();
	const decoded = await admin.auth().verifyIdToken(idToken);
	return decoded.email || decoded.uid || null;
}

function getUserCreditsRef(companyId, userKey) {
	return db.collection("userCredits").doc(companyId).collection("users").doc(userKey);
}

function getPlanDetails(subscriptionId) {
	const normalizedSubscriptionId = (subscriptionId || "").toLowerCase();
	const isAnnual = normalizedSubscriptionId.includes("annual");
	const isDaily = normalizedSubscriptionId.includes("daily");

	return {
		creditsToDeduct: isAnnual ? 999 : (isDaily ? 49 : 99),
		durationDays: isAnnual ? 365 : (isDaily ? 1 : 30),
	};
}

function toIsoOrNull(value) {
	const date = toJsDate(value);
	if (!date || Number.isNaN(date.getTime())) return null;
	return date.toISOString();
}

async function getEntitlementByIdentity({uid, companyId, moduleId}) {
	if (!uid || !companyId || !moduleId) return null;
	const entitlementId = `${uid}_${moduleId}`;
	const entRef = db.collection("companies").doc(companyId).collection("entitlements").doc(entitlementId);
	const entSnap = await entRef.get();
	if (!entSnap.exists) return null;
	return {
		entRef,
		entData: entSnap.data(),
		companyId,
	};
}

async function renewSubscriptionWithCredits({
	uid,
	companyId,
	moduleId,
	forceRenew = false,
	reason = "system",
	moduleName = null,
}) {
	const entitlement = await getEntitlementByIdentity({uid, companyId, moduleId});

	if (!entitlement) {
		throw new Error("Entitlement not found");
	}

	const {entRef, entData, companyId: companyIdFromEnt} = entitlement;
	const {uid: entUid, moduleId: entModuleId, companyId: entCompanyId, subscriptionId, payerUid} = entData;
	const resolvedUid = entUid || uid;
	const resolvedModuleId = entModuleId || moduleId;
	const resolvedCompanyId = entCompanyId || companyIdFromEnt || companyId;
	const resolvedModuleName = entData.moduleName || moduleName || resolvedModuleId;
	const resolvedPayerUid = payerUid || resolvedUid;

	if (!resolvedUid || !resolvedModuleId || !resolvedCompanyId) {
		throw new Error(`Missing subscription metadata for renewal: uid=${resolvedUid}, moduleId=${resolvedModuleId}, companyId=${resolvedCompanyId}`);
	}

	const entitlementId = `${resolvedUid}_${resolvedModuleId}`;
	const now = new Date();
	const expiryDate = toJsDate(entData.renewalDate);

	if (!forceRenew && entData.autoRenewing !== true) {
		return {
			renewed: false,
			reason: "auto_renew_disabled",
			status: entData.status || "expired",
			expiryTime: expiryDate,
		};
	}

	const dueForRenewal = forceRenew || (expiryDate && expiryDate <= now);
	if (!dueForRenewal) {
		return {
			renewed: false,
			reason: "not_due",
			status: entData.status || "active",
			expiryTime: expiryDate,
		};
	}

	const {creditsToDeduct, durationDays} = getPlanDetails(subscriptionId);
	const amountUsd = creditsToDeduct * 0.01;

	const billingRef = getUserCreditsRef(resolvedCompanyId, resolvedPayerUid);
	const billingSnap = await billingRef.get();
	const billingData = billingSnap.exists ? billingSnap.data() : {};
	const currentBalance = billingData.balance || 0;

	if (currentBalance < creditsToDeduct) {
		await entRef.set({
			status: "expired",
			autoRenewing: false,
			renewalDate: expiryDate,
			source: "credits",
			lastVerifiedAt: admin.firestore.FieldValue.serverTimestamp(),
		}, {merge: true});

		await db.collection("companies").doc(resolvedCompanyId).collection("entitlements").doc(entitlementId).set({
			status: "expired",
			autoRenewing: false,
			source: "credits",
			lastVerifiedAt: admin.firestore.FieldValue.serverTimestamp(),
		}, {merge: true});

		return {
			renewed: false,
			reason: "insufficient_credits",
			status: "expired",
			expiryTime: expiryDate,
			currentBalance,
			creditsNeeded: creditsToDeduct,
		};
	}

	const newBalance = currentBalance - creditsToDeduct;
	const transactionHistory = Array.isArray(billingData.transactionHistory) ? billingData.transactionHistory : [];
	transactionHistory.push({
		amount: -amountUsd,
		credits: -creditsToDeduct,
		date: new Date().toISOString(),
		type: "subscription",
		renewalSource: forceRenew ? "manual" : "auto",
		moduleId: resolvedModuleId,
		moduleName: resolvedModuleName,
		subscriptionId,
		uid: resolvedUid,
		userEmail: resolvedUid,
	});

	await billingRef.set({
		balance: newBalance,
		transactionHistory,
		companyId: resolvedCompanyId,
		userKey: resolvedPayerUid,
		lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
	}, {merge: true});

	const renewalBaseDate = expiryDate && expiryDate > now ? expiryDate : now;
	const newExpiryDate = new Date(renewalBaseDate.getTime() + durationDays * 24 * 60 * 60 * 1000);

	await entRef.set({
		status: "active",
		renewalDate: newExpiryDate,
		source: "credits",
		lastVerifiedAt: admin.firestore.FieldValue.serverTimestamp(),
	}, {merge: true});

	await db.collection("companies").doc(resolvedCompanyId).collection("entitlements").doc(entitlementId).set({
		status: "active",
		renewalDate: newExpiryDate,
		source: "credits",
		lastVerifiedAt: admin.firestore.FieldValue.serverTimestamp(),
	}, {merge: true});

	return {
		renewed: true,
		reason,
		status: "active",
		expiryTime: newExpiryDate,
		autoRenewing: entData.autoRenewing,
		newBalance,
		creditsDeducted: creditsToDeduct,
	};
}

// Handle initial module subscription purchase using internal credits
exports.recordPlaySubscription = onRequest(async (req, res) => {
	try {
		const {uid, subscriptionId, companyId, moduleId, moduleName, payerType, payerUid} = req.body;

		if (!uid || !subscriptionId || !companyId || !moduleId) {
			return res.status(400).send("Missing required fields");
		}

		// Determine plan type and credits needed
		const isAnnual = subscriptionId && subscriptionId.toLowerCase().includes("annual");
		const isDaily = subscriptionId && subscriptionId.toLowerCase().includes("daily");
		const durationDays = isAnnual ? 365 : (isDaily ? 1 : 30);
		const creditsNeeded = isAnnual ? 999 : (isDaily ? 49 : 99); // annual=999, daily=49, monthly=99
		const expiryTime = new Date(Date.now() + durationDays * 24 * 60 * 60 * 1000);
		
		logger.info("Calculating credits for subscription", {subscriptionId, isAnnual, isDaily, creditsNeeded});

		// Deduct credits from the payer's balance (individual credits)
		const creditOwner = payerUid || uid;
		const billingRef = getUserCreditsRef(companyId, creditOwner);
		const billingSnap = await billingRef.get();
		const currentBalance = billingSnap.exists ? (billingSnap.data().balance || 0) : 0;

		if (currentBalance < creditsNeeded) {
			logger.warn("Insufficient credits", {companyId, currentBalance, creditsNeeded});
			return res.status(402).json({
				error: "Insufficient credits",
				currentBalance,
				creditsNeeded,
			});
		}

		const newBalance = currentBalance - creditsNeeded;
		
		// Use module name and uid (which is the user email) for transaction record
		const effectiveModuleName = moduleName || moduleId;
		const userEmail = uid; // uid is actually the user's email
		
		logger.info("Recording transaction", {moduleName: effectiveModuleName, userEmail});
		
		// Record the deduction and add to transaction history
		const deductionTransaction = {
			amount: -(creditsNeeded * 0.01),
			credits: -creditsNeeded,
			date: new Date().toISOString(),
			type: "subscription",
			renewalSource: "subscription",
			moduleId: moduleId,
			moduleName: effectiveModuleName,
			subscriptionId: subscriptionId,
			uid: uid,
			userEmail: uid,
		};

		const transactionHistory = billingSnap.exists && billingSnap.data().transactionHistory
			? Array.isArray(billingSnap.data().transactionHistory)
				? billingSnap.data().transactionHistory
				: []
			: [];
		transactionHistory.push(deductionTransaction);

		await billingRef.set({
			balance: newBalance,
			transactionHistory: transactionHistory,
			companyId,
			userKey: creditOwner,
			lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
		}, {merge: true});

		logger.info("Credits deducted", {companyId, creditsDeducted: creditsNeeded, newBalance});

		// Create entitlement record
		const entitlementId = `${uid}_${moduleId}`;
		await db.collection("companies").doc(companyId).collection("entitlements").doc(entitlementId).set({
			uid,
			moduleId,
			moduleName: effectiveModuleName,
			status: "active",
			payerType: payerType || "self",
			payerUid: payerUid || uid,
			renewalDate: expiryTime,
			autoRenewing: true,
			subscriptionId,
			creditsCharged: creditsNeeded,
			createdAt: admin.firestore.FieldValue.serverTimestamp(),
			lastVerifiedAt: admin.firestore.FieldValue.serverTimestamp(),
			source: "credits",
		});

		logger.info("Subscription recorded", {uid, moduleId, creditsCharged: creditsNeeded});
		res.status(200).json({
			success: true,
			entitlementId,
			expiryTime,
			autoRenewing: true,
			creditsCharged: creditsNeeded,
			creditsRemaining: newBalance,
		});
	} catch (e) {
		logger.error("Record subscription error", e);
		res.status(500).send("ERROR");
	}
});

// Verify and refresh a subscription
exports.refreshPlaySubscription = onRequest(async (req, res) => {
	try {
		const {uid, companyId, moduleId} = req.body;

		if (!uid || !companyId || !moduleId) {
			return res.status(400).send("Missing uid, companyId, or moduleId");
		}

		const entitlement = await getEntitlementByIdentity({uid, companyId, moduleId});
		if (!entitlement) {
			return res.status(404).send("Entitlement not found");
		}

		const {entRef, entData: subData, companyId: companyIdFromEnt} = entitlement;
		const expiryTime = toJsDate(subData.renewalDate);
		const isExpired = !expiryTime || expiryTime <= new Date();
		const shouldAutoRenew = isExpired && subData.autoRenewing === true;
		let wasRenewed = false;

		if (shouldAutoRenew) {
			const renewalResult = await renewSubscriptionWithCredits({
				uid,
				companyId,
				moduleId,
				forceRenew: false,
				reason: "refresh",
				moduleName: subData.moduleName,
			});
			wasRenewed = renewalResult.renewed;
		}

		const refreshedEntitlement = await getEntitlementByIdentity({uid, companyId, moduleId});
		const refreshedData = refreshedEntitlement?.entData ?? subData;
		const refreshedExpiry = toJsDate(refreshedData.renewalDate);
		const hasActiveAccess = refreshedData.status == "active" && refreshedExpiry && refreshedExpiry > new Date();
		const newStatus = hasActiveAccess ? "active" : (refreshedData.status || "expired");

		// Update entitlement status
		await entRef.set({
			status: newStatus,
			autoRenewing: refreshedData.autoRenewing,
			renewalDate: refreshedExpiry,
			lastVerifiedAt: admin.firestore.FieldValue.serverTimestamp(),
		}, {merge: true});

		// Update entitlement
		const {uid: entUid, moduleId: entModuleId, companyId: entCompanyId} = subData;
		const effectiveCompanyId = entCompanyId || companyIdFromEnt;
		const entitlementId = `${entUid}_${entModuleId}`;
		await db.collection("companies").doc(effectiveCompanyId).collection("entitlements").doc(entitlementId).set({
			status: newStatus,
			renewalDate: refreshedExpiry,
			autoRenewing: refreshedData.autoRenewing,
			lastVerifiedAt: admin.firestore.FieldValue.serverTimestamp(),
		}, {merge: true});

		logger.info("Subscription refreshed", {
			uid: entUid,
			companyId: effectiveCompanyId,
			moduleId: entModuleId,
			status: newStatus,
			wasRenewed,
		});
		res.status(200).json({
			success: true,
			status: newStatus,
			expiryTime: refreshedExpiry ? refreshedExpiry.toISOString() : null,
			autoRenewing: refreshedData.autoRenewing,
		});
	} catch (e) {
		logger.error("Refresh subscription error", e);
		res.status(500).send("ERROR");
	}
});

exports.manualRenewSubscription = onRequest(async (req, res) => {
	try {
		const {uid, companyId, moduleId, moduleName} = req.body;

		if (!uid || !companyId || !moduleId) {
			return res.status(400).send("Missing uid, companyId, or moduleId");
		}

		const renewalResult = await renewSubscriptionWithCredits({
			uid,
			companyId,
			moduleId,
			forceRenew: true,
			reason: "manual_request",
			moduleName,
		});

		if (!renewalResult.renewed && renewalResult.reason === "insufficient_credits") {
			return res.status(402).json({
				error: "Insufficient credits",
				currentBalance: renewalResult.currentBalance,
				creditsNeeded: renewalResult.creditsNeeded,
				status: renewalResult.status,
				expiryTime: toIsoOrNull(renewalResult.expiryTime),
			});
		}

		res.status(200).json({
			success: true,
			status: renewalResult.status,
			expiryTime: toIsoOrNull(renewalResult.expiryTime),
			autoRenewing: renewalResult.autoRenewing,
			creditsDeducted: renewalResult.creditsDeducted,
			newBalance: renewalResult.newBalance,
		});
	} catch (e) {
		logger.error("Manual renew subscription error", e);
		res.status(500).json({
			error: "Manual renew failed",
			message: e.message || "Unknown error",
		});
	}
});

// Disable auto-renew for a subscription
exports.disablePlayAutoRenew = onRequest(async (req, res) => {
	try {
		const {uid, companyId, moduleId} = req.body;

		if (!uid || !companyId || !moduleId) {
			return res.status(400).send("Missing uid, companyId, or moduleId");
		}

		const entitlement = await getEntitlementByIdentity({uid, companyId, moduleId});
		if (!entitlement) {
			return res.status(404).send("Entitlement not found");
		}

		const {entRef, entData: subData, companyId: companyIdFromEnt} = entitlement;
		const {companyId: entCompanyId, uid: entUid, moduleId: entModuleId} = subData;
		const effectiveCompanyId = entCompanyId || companyIdFromEnt;
		const expiryTime = toJsDate(subData.renewalDate);
		const status = expiryTime && expiryTime > new Date() ? "active" : "expired";

		await entRef.set({
			autoRenewing: false,
			status,
			renewalDate: expiryTime,
			lastVerifiedAt: admin.firestore.FieldValue.serverTimestamp(),
		}, {merge: true});

		if (effectiveCompanyId && entUid && entModuleId) {
			const entitlementId = `${entUid}_${entModuleId}`;
			await db.collection("companies").doc(effectiveCompanyId).collection("entitlements").doc(entitlementId).set({
				autoRenewing: false,
				status,
				renewalDate: expiryTime,
				lastVerifiedAt: admin.firestore.FieldValue.serverTimestamp(),
			}, {merge: true});
		}

		return res.status(200).json({
			success: true,
			status,
			autoRenewing: false,
			expiryTime: expiryTime ? expiryTime.toISOString() : null,
		});
	} catch (e) {
		logger.error("Disable auto-renew error", e);
		res.status(500).send("ERROR");
	}
});

// Enable auto-renew for a subscription
exports.enablePlayAutoRenew = onRequest(async (req, res) => {
	try {
		const {uid, companyId, moduleId} = req.body;

		if (!uid || !companyId || !moduleId) {
			return res.status(400).send("Missing uid, companyId, or moduleId");
		}

		const entitlement = await getEntitlementByIdentity({uid, companyId, moduleId});
		if (!entitlement) {
			return res.status(404).send("Entitlement not found");
		}

		const {entRef, entData: subData, companyId: companyIdFromEnt} = entitlement;
		const {companyId: entCompanyId, uid: entUid, moduleId: entModuleId} = subData;
		const effectiveCompanyId = entCompanyId || companyIdFromEnt;

		const expiryTime = toJsDate(subData.renewalDate);
		const status = expiryTime && expiryTime > new Date() ? "active" : "expired";

		await entRef.set({
			autoRenewing: true,
			status,
			lastVerifiedAt: admin.firestore.FieldValue.serverTimestamp(),
		}, {merge: true});

		if (effectiveCompanyId && entUid && entModuleId) {
			const entitlementId = `${entUid}_${entModuleId}`;
			await db.collection("companies").doc(effectiveCompanyId).collection("entitlements").doc(entitlementId).set({
				autoRenewing: true,
				status,
				renewalDate: expiryTime,
				lastVerifiedAt: admin.firestore.FieldValue.serverTimestamp(),
			}, {merge: true});
		}

		return res.status(200).json({
			success: true,
			status,
			autoRenewing: true,
			expiryTime: expiryTime ? expiryTime.toISOString() : null,
		});
	} catch (e) {
		logger.error("Enable auto-renew error", e);
		res.status(500).send("ERROR");
	}
});

// Get module pricing and free-plan status
exports.getModulePricing = onRequest(async (req, res) => {
	try {
		const {moduleName, moduleId} = req.body;
		if (!moduleName && !moduleId) {
			return res.status(400).send("Missing moduleName or moduleId");
		}

		const normalize = (value) =>
			value
				.toString()
				.toLowerCase()
				.trim();

		const normalizedName = moduleName ? normalize(moduleName) : "";
		const normalizedId = moduleId ? normalize(moduleId) : "";
		const freeModules = ["crm", "inventory", "hr"];
		const isFree = freeModules.includes(normalizedId) || freeModules.includes(normalizedName);
		
		res.status(200).json({
			moduleName,
			moduleId,
			isFree,
			dailyPrice: isFree ? 0 : 0.49,
			monthlyPrice: isFree ? 0 : 0.99,
			annualPrice: isFree ? 0 : 9.99,
			currency: "USD",
		});
	} catch (e) {
		logger.error("Get module pricing error", e);
		res.status(500).send("ERROR");
	}
});

// Check entitlement status
exports.getEntitlementStatus = onRequest(async (req, res) => {
	try {
		const {uid, companyId, moduleId} = req.body;

		if (!uid || !companyId || !moduleId) {
			return res.status(400).send("Missing required fields");
		}

		const entitlementId = `${uid}_${moduleId}`;
		const entSnap = await db.collection("companies").doc(companyId).collection("entitlements").doc(entitlementId).get();

		if (!entSnap.exists) {
			return res.status(404).json({
				status: "none",
				hasAccess: false,
			});
		}

		const entData = entSnap.data();
		const now = new Date();
		let currentEntData = entData;
		let expiryTime = toJsDate(currentEntData.renewalDate);
		let hasExpired = expiryTime && expiryTime < now;

		if (hasExpired && currentEntData.autoRenewing === true) {
			try {
				const renewalResult = await renewSubscriptionWithCredits({
					uid,
					companyId,
					moduleId,
					forceRenew: false,
					reason: "status_check",
					moduleName: currentEntData.moduleName || moduleId,
				});

				logger.info("Status-check auto-renew attempt", {
					companyId,
					uid,
					moduleId,
					renewed: renewalResult.renewed,
					reason: renewalResult.reason,
				});

				const refreshedEntSnap = await entSnap.ref.get();
				if (refreshedEntSnap.exists) {
					currentEntData = refreshedEntSnap.data();
					expiryTime = toJsDate(currentEntData.renewalDate);
					hasExpired = expiryTime && expiryTime < now;
				}
			} catch (renewalError) {
				logger.error("Status-check auto-renew failed", renewalError, {
					companyId,
					uid,
					moduleId,
				});
			}
		}

		let effectiveStatus = currentEntData.status;
		if (hasExpired && currentEntData.status !== "expired") {
			effectiveStatus = "expired";
			await entSnap.ref.set({
				status: "expired",
				lastVerifiedAt: admin.firestore.FieldValue.serverTimestamp(),
			}, {merge: true});

			logger.info("Entitlement auto-expired by backend", {
				companyId,
				uid,
				moduleId,
				renewalDate: expiryTime ? expiryTime.toISOString() : null,
			});
		}

		const hasAccess = effectiveStatus === "active" && !hasExpired;

		res.status(200).json({
			status: effectiveStatus,
			hasAccess,
			renewalDate: expiryTime ? expiryTime.toISOString() : null,
			autoRenewing: currentEntData.autoRenewing,
			payerType: currentEntData.payerType,
			source: currentEntData.source || "credits",
			subscriptionId: currentEntData.subscriptionId,
			lastVerifiedAt: toJsDate(currentEntData.lastVerifiedAt) ? toJsDate(currentEntData.lastVerifiedAt).toISOString() : null,
		});
	} catch (e) {
		logger.error("Get entitlement error", e);
		res.status(500).send("ERROR");
	}
});

exports.appleServerNotifications = onRequest(async (req, res) => {
	try {
		// TODO: verify with App Store Server API and update subscriptions/entitlements
		res.status(200).send("OK");
	} catch (e) {
		logger.error("Apple notification error", e);
		res.status(500).send("ERROR");
	}
});

// Get workspace credits and topup history
exports.getWorkspaceCredits = onRequest(async (req, res) => {
	try {
		const {companyId} = req.body;
		const userKey = await getUserKeyFromAuth(req);

		if (!companyId || !userKey) {
			return res.status(400).send("Missing companyId or user identity");
		}

		const billingRef = getUserCreditsRef(companyId, userKey);
		const billingSnap = await billingRef.get();

		if (!billingSnap.exists) {
			return res.status(404).json({
				balance: 0,
				transactionHistory: [],
				autoTopupEnabled: false,
			});
		}

		const billingData = billingSnap.data();
		
		const transactions = (billingData.transactionHistory || []).map(t => ({
			amount: t.amount,
			credits: t.credits,
			date: t.date instanceof admin.firestore.Timestamp ? t.date.toDate().toISOString() : t.date,
			type: t.type || "topup",
			renewalSource: t.renewalSource,
			moduleId: t.moduleId,
			moduleName: t.moduleName,
			subscriptionId: t.subscriptionId,
			uid: t.uid,
			userEmail: t.userEmail,
			platform: t.platform,
			purchaseId: t.purchaseId,
		}));

		// Sort by date (newest first)
		const allTransactions = transactions.sort((a, b) => 
			new Date(b.date).getTime() - new Date(a.date).getTime()
		);

		res.status(200).json({
			balance: billingData.balance || 0,
			transactionHistory: allTransactions,
			autoTopupEnabled: billingData.autoTopupEnabled || false,
			autoTopupAmount: billingData.autoTopupAmount,
			lastAutoTopupDate: billingData.lastAutoTopupDate
				? (billingData.lastAutoTopupDate instanceof admin.firestore.Timestamp
					? billingData.lastAutoTopupDate.toDate().toISOString()
					: billingData.lastAutoTopupDate)
				: null,
		});
	} catch (e) {
		logger.error("Get workspace credits error", e);
		res.status(500).send("ERROR");
	}
});

// Topup workspace credits
exports.topupWorkspaceCredits = onRequest(async (req, res) => {
	try {
		const {companyId, credits, platform, purchaseId} = req.body;
		const userKey = await getUserKeyFromAuth(req);
		logger.info("Topup request received", {companyId, credits, platform, purchaseId});

		if (!companyId || !userKey || !credits || credits <= 0) {
			logger.warn("Invalid parameters", {companyId, credits});
			return res.status(400).send("Missing or invalid parameters");
		}

		const billingRef = getUserCreditsRef(companyId, userKey);
		const billingSnap = await billingRef.get();
		logger.info("Got billing snapshot", {companyIdLength: companyId.length, docExists: billingSnap.exists});

		const currentBalance = billingSnap.exists ? (billingSnap.data().balance || 0) : 0;
		const newBalance = currentBalance + credits;
		const amountUsd = credits * 0.01; // 1 credit = $0.01

		const newTopup = {
			amount: amountUsd,
			credits,
			date: new Date().toISOString(), // Use ISO string instead of serverTimestamp
			type: "topup",
		};

		// Add optional platform and purchaseId if provided
		if (platform) {
			newTopup.platform = platform;
		}
		if (purchaseId) {
			newTopup.purchaseId = purchaseId;
		}

		logger.info("About to write to Firestore", {
			currentBalance,
			newBalance,
			topupData: newTopup,
		});

		// Manually manage the array instead of using arrayUnion
		let transactionHistory = billingSnap.exists && billingSnap.data().transactionHistory 
			? Array.isArray(billingSnap.data().transactionHistory) 
				? billingSnap.data().transactionHistory 
				: []
			: [];

		try {
			logger.info("Starting Firestore write...", {billingPath: billingRef.path});
			
			transactionHistory.push(newTopup);
			logger.info("Updated transaction history", {historyLength: transactionHistory.length});
			
			await billingRef.set({
				balance: newBalance,
				transactionHistory: transactionHistory,
				companyId,
				userKey,
				lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
			}, {merge: true});
			logger.info("Firestore write succeeded", {newBalance});
		} catch (firebaseError) {
			logger.error("Firestore write failed", firebaseError, {
				newTopupKeys: Object.keys(newTopup),
				newTopupValues: `amount=${newTopup.amount}, credits=${newTopup.credits}, date=${newTopup.date}, type=${newTopup.type}`,
				errorMessage: firebaseError.message,
			});
			throw firebaseError;
		}

		logger.info("Credits topup recorded", {companyId, credits, newBalance});

		// Format and sort transaction history for response
		const formattedTransactions = transactionHistory.map(t => ({
			amount: t.amount,
			credits: t.credits,
			date: t.date instanceof admin.firestore.Timestamp ? t.date.toDate().toISOString() : t.date,
			type: t.type || "topup",
			renewalSource: t.renewalSource,
			moduleId: t.moduleId,
			moduleName: t.moduleName,
			subscriptionId: t.subscriptionId,
			uid: t.uid,
			userEmail: t.userEmail,
			platform: t.platform,
			purchaseId: t.purchaseId,
		})).sort((a, b) => 
			new Date(b.date).getTime() - new Date(a.date).getTime()
		);

		res.status(200).json({
			balance: newBalance,
			transactionHistory: formattedTransactions,
			autoTopupEnabled: billingSnap.exists ? (billingSnap.data().autoTopupEnabled || false) : false,
			autoTopupAmount: billingSnap.exists ? billingSnap.data().autoTopupAmount : null,
		});
	} catch (e) {
		logger.error("Topup credits error", e, {
			companyId: req.body.companyId,
			credits: req.body.credits,
			errorMessage: e.message,
			errorStack: e.stack,
		});
		res.status(500).json({
			error: "Topup failed",
			message: e.message,
			type: e.constructor.name,
		});
	}
});

// Enable/disable auto-topup
exports.setAutoTopup = onRequest(async (req, res) => {
	try {
		const {companyId, enabled, amount} = req.body;
		const userKey = await getUserKeyFromAuth(req);

		if (!companyId || !userKey) {
			return res.status(400).send("Missing companyId or user identity");
		}

		const billingRef = getUserCreditsRef(companyId, userKey);
		const billingSnap = await billingRef.get();

		const currentBalance = billingSnap.exists ? (billingSnap.data().balance || 0) : 0;
		const lastAutoTopupDate = billingSnap.exists ? billingSnap.data().lastAutoTopupDate : null;
		const currentTransactionHistory = billingSnap.exists && billingSnap.data().transactionHistory
			? billingSnap.data().transactionHistory
			: [];

		await billingRef.set({
			autoTopupEnabled: enabled,
			autoTopupAmount: enabled ? (amount || 1000) : null,
			companyId,
			userKey,
			lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
		}, {merge: true});

		logger.info("Auto-topup setting updated", {companyId, enabled, amount});

		// Format and sort transaction history for response
		const formattedTransactions = currentTransactionHistory.map(t => ({
			amount: t.amount,
			credits: t.credits,
			date: t.date instanceof admin.firestore.Timestamp ? t.date.toDate().toISOString() : t.date,
			type: t.type || "topup",
			renewalSource: t.renewalSource,
			moduleId: t.moduleId,
			moduleName: t.moduleName,
			subscriptionId: t.subscriptionId,
			uid: t.uid,
			userEmail: t.userEmail,
			platform: t.platform,
			purchaseId: t.purchaseId,
		})).sort((a, b) => 
			new Date(b.date).getTime() - new Date(a.date).getTime()
		);

		res.status(200).json({
			balance: currentBalance,
			transactionHistory: formattedTransactions,
			autoTopupEnabled: enabled,
			autoTopupAmount: enabled ? (amount || 1000) : null,
			lastAutoTopupDate: lastAutoTopupDate 
				? (lastAutoTopupDate instanceof admin.firestore.Timestamp
					? lastAutoTopupDate.toDate().toISOString()
					: lastAutoTopupDate)
				: null,
		});
	} catch (e) {
		logger.error("Set auto-topup error", e);
		res.status(500).send("ERROR");
	}
});

// Scheduled function: Run monthly auto-topup on the 1st of each month
exports.monthlyAutoTopup = onSchedule({
	schedule: "0 0 1 * *", // Run at midnight UTC on the 1st day of every month
	timeZone: "UTC",
}, async (event) => {
	logger.info("Starting monthly auto-topup process");

	try {
		const creditsSnapshot = await db.collectionGroup("users")
			.where("autoTopupEnabled", "==", true)
			.get();

		let successCount = 0;
		let errorCount = 0;
		const errors = [];

		for (const creditDoc of creditsSnapshot.docs) {
			const creditData = creditDoc.data();
			const companyId = creditData.companyId;
			const userKey = creditData.userKey;

			if (!companyId || !userKey || !creditData.autoTopupAmount) {
				continue;
			}

			try {
				const autoTopupAmount = creditData.autoTopupAmount;
				const currentBalance = creditData.balance || 0;
				const newBalance = currentBalance + autoTopupAmount;
				const amountUsd = autoTopupAmount * 0.01;

				const autoTopupTransaction = {
					amount: amountUsd,
					credits: autoTopupAmount,
					date: new Date().toISOString(),
					type: "auto-topup",
					uid: userKey,
					userEmail: userKey,
				};

				const transactionHistory = Array.isArray(creditData.transactionHistory)
					? creditData.transactionHistory
					: [];
				transactionHistory.push(autoTopupTransaction);

				await creditDoc.ref.set({
					balance: newBalance,
					transactionHistory,
					companyId,
					userKey,
					lastAutoTopupDate: admin.firestore.FieldValue.serverTimestamp(),
					lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
				}, {merge: true});

				logger.info("Auto-topup successful", {
					companyId,
					userKey,
					credits: autoTopupAmount,
					newBalance,
				});

				successCount++;
			} catch (error) {
				logger.error("Auto-topup failed for user", error, {companyId, userKey});
				errors.push({companyId, userKey, error: error.message});
				errorCount++;
			}
		}

		logger.info("Monthly auto-topup completed", {
			totalUsers: creditsSnapshot.size,
			successCount,
			errorCount,
			errors: errors.length > 0 ? errors : undefined,
		});

		return {
			success: true,
			totalUsers: creditsSnapshot.size,
			successCount,
			errorCount,
		};
	} catch (error) {
		logger.error("Monthly auto-topup process failed", error);
		throw error;
	}
});

