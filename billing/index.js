/**
 * Import function triggers from their respective submodules:
 *
 * const {onCall} = require("firebase-functions/v2/https");
 * const {onDocumentWritten} = require("firebase-functions/v2/firestore");
 *
 * See a full list of supported triggers at https://firebase.google.com/docs/functions
 */

const functions = require("firebase-functions");
const admin = require("firebase-admin");
const {setGlobalOptions} = require("firebase-functions");
const {onRequest} = require("firebase-functions/https");
const {onMessagePublished} = require("firebase-functions/v2/pubsub");
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
	return db.collection("userCredits").doc(`${companyId}_${userKey}`);
}

function normalizeStatus(notificationType) {
	// Google Play RTDN types: https://developer.android.com/google/play/billing/rtdn-reference
	switch (notificationType) {
		case 1: // SUBSCRIPTION_RECOVERED
		case 2: // SUBSCRIPTION_RENEWED
		case 4: // SUBSCRIPTION_PURCHASED
		case 7: // SUBSCRIPTION_RESTARTED
		case 10: // SUBSCRIPTION_PRICE_CHANGE_CONFIRMED
			return "active";
		case 3: // SUBSCRIPTION_CANCELED
			return "canceled";
		case 5: // SUBSCRIPTION_ON_HOLD
			return "grace";
		case 6: // SUBSCRIPTION_IN_GRACE_PERIOD
			return "grace";
		case 12: // SUBSCRIPTION_EXPIRED
			return "expired";
		default:
			return "unknown";
	}
}

async function writeBillingEvent(payload, source) {
	await db.collection("billingEvents").add({
		source,
		payload,
		createdAt: admin.firestore.FieldValue.serverTimestamp(),
	});
}

const projectId = process.env.GCLOUD_PROJECT || "driveerp-1d5d5";
const rtdnTopic = `projects/${projectId}/topics/driver-erp-google-play-rtdn`;

// Helper to get Play Developer API access token
async function getPlayDeveloperAccessToken() {
	const serviceAccount = JSON.parse(process.env.GOOGLE_APPLICATION_CREDENTIALS_JSON || "{}");
	const jwtClient = new (require("google-auth-library")).JWT({
		email: serviceAccount.client_email,
		key: serviceAccount.private_key,
		scopes: ["https://www.googleapis.com/auth/androidpublisher"],
	});
	const tokens = await jwtClient.authorize();
	return tokens.access_token;
}

// Verify subscription with Play Developer API
async function verifyPlaySubscription(packageName, subscriptionId, purchaseToken) {
	try {
		const accessToken = await getPlayDeveloperAccessToken();
		const endpoint = `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${packageName}/subscriptions/${subscriptionId}/purchases/tokens/${purchaseToken}`;
		
		const response = await fetch(endpoint, {
			headers: {
				Authorization: `Bearer ${accessToken}`,
			},
		});

		if (!response.ok) {
			logger.warn(`Play API verification failed: ${response.status}`, {
				packageName,
				subscriptionId,
				purchaseToken,
			});
			return null;
		}

		const data = await response.json();
		logger.info("Play subscription verified", {
			packageName,
			subscriptionId,
			expiryTime: data.expiryTimeMillis,
			autoRenewing: data.autoRenewing,
		});
		return data;
	} catch (e) {
		logger.error("Play API verification error", e, {
			packageName,
			subscriptionId,
		});
		return null;
	}
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

async function renewSubscriptionWithCredits({
	purchaseToken,
	forceRenew = false,
	reason = "system",
	fallbackUid = null,
	fallbackCompanyId = null,
	fallbackModuleId = null,
	fallbackModuleName = null,
}) {
	const subsRef = db.collection("subscriptions").doc(purchaseToken);
	const subsSnap = await subsRef.get();

	if (!subsSnap.exists) {
		throw new Error("Subscription not found");
	}

	const subData = subsSnap.data();
	const {uid, moduleId, companyId, subscriptionId, payerUid} = subData;
	const resolvedUid = uid || fallbackUid;
	const resolvedModuleId = moduleId || fallbackModuleId;
	const resolvedCompanyId = companyId || fallbackCompanyId;
	const resolvedModuleName = subData.moduleName || fallbackModuleName || resolvedModuleId;
	const resolvedPayerUid = payerUid || resolvedUid;

	if (!resolvedUid || !resolvedModuleId || !resolvedCompanyId) {
		throw new Error(`Missing subscription metadata for renewal: uid=${resolvedUid}, moduleId=${resolvedModuleId}, companyId=${resolvedCompanyId}`);
	}

	const entitlementId = `${resolvedUid}_${resolvedModuleId}`;
	const now = new Date();
	const expiryDate = toJsDate(subData.expiryTime);

	if (!forceRenew && subData.autoRenewing !== true) {
		return {
			renewed: false,
			reason: "auto_renew_disabled",
			status: subData.status || "expired",
			expiryTime: expiryDate,
		};
	}

	const dueForRenewal = forceRenew || (expiryDate && expiryDate <= now);
	if (!dueForRenewal) {
		return {
			renewed: false,
			reason: "not_due",
			status: subData.status || "active",
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
		await subsRef.set({
			status: "expired",
			autoRenewing: false,
			lastVerifiedAt: admin.firestore.FieldValue.serverTimestamp(),
		}, {merge: true});

		await db.collection("companies").doc(resolvedCompanyId).collection("entitlements").doc(entitlementId).set({
			status: "expired",
			autoRenewing: false,
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

	await subsRef.set({
		status: "active",
		expiryTime: newExpiryDate,
		lastVerifiedAt: admin.firestore.FieldValue.serverTimestamp(),
	}, {merge: true});

	await db.collection("companies").doc(resolvedCompanyId).collection("entitlements").doc(entitlementId).set({
		status: "active",
		renewalDate: newExpiryDate,
		lastVerifiedAt: admin.firestore.FieldValue.serverTimestamp(),
	}, {merge: true});

	await writeBillingEvent({
		type: forceRenew ? "subscription_manual_renewed" : "subscription_auto_renewed",
		reason,
		companyId: resolvedCompanyId,
		uid: resolvedUid,
		moduleId: resolvedModuleId,
		moduleName: resolvedModuleName,
		purchaseToken,
		creditsDeducted: creditsToDeduct,
		newBalance,
		newExpiryDate: newExpiryDate.toISOString(),
	}, "system");

	return {
		renewed: true,
		reason,
		status: "active",
		expiryTime: newExpiryDate,
		autoRenewing: subData.autoRenewing,
		newBalance,
		creditsDeducted: creditsToDeduct,
	};
}

exports.googlePlayRtdn = onMessagePublished({ topic: rtdnTopic }, async (event) => {
		let payload = null;
		try {
			const message = event.data.message;
			if (message.json) {
				payload = message.json;
			} else if (message.data) {
				const decoded = Buffer.from(message.data, "base64").toString("utf8");
				payload = JSON.parse(decoded);
			}
		} catch (e) {
			logger.error("Failed to parse RTDN payload", e);
		}

		if (!payload) return;

		await writeBillingEvent(payload, "google");

		const sub = payload.subscriptionNotification;
		if (!sub || !sub.purchaseToken) return;

		const packageName = payload.packageName;
		const purchaseToken = sub.purchaseToken;
		const subscriptionId = sub.subscriptionId;
		const notificationType = sub.notificationType;
		const status = normalizeStatus(notificationType);

		// Verify with Play Developer API
		const verifiedData = await verifyPlaySubscription(packageName, subscriptionId, purchaseToken);
		if (!verifiedData) {
			logger.warn("Skipping update for unverified subscription", { purchaseToken });
			return;
		}

		const subsSnap = await db
			.collection("subscriptions")
			.where("purchaseToken", "==", purchaseToken)
			.limit(1)
			.get();

		if (subsSnap.empty) {
			logger.warn("No subscription found for purchaseToken", purchaseToken);
			return;
		}

		const subDoc = subsSnap.docs[0];
		const subData = subDoc.data();
		const uid = subData.uid;
		const moduleId = subData.moduleId;
		const companyId = subData.companyId;

		const expiryTime = verifiedData.expiryTimeMillis ? new Date(parseInt(verifiedData.expiryTimeMillis)) : null;

		await subDoc.ref.set(
			{
				status,
				autoRenewing: verifiedData.autoRenewing,
				expiryTime,
				lastVerifiedAt: admin.firestore.FieldValue.serverTimestamp(),
				source: "google",
			},
			{ merge: true }
		);

		if (!uid || !moduleId || !companyId) {
			logger.warn("Missing uid/moduleId/companyId for entitlement update", {
				uid,
				moduleId,
				companyId,
			});
			return;
		}

		const entitlementId = `${uid}_${moduleId}`;
		const entitlementRef = db
			.collection("companies")
			.doc(companyId)
			.collection("entitlements")
			.doc(entitlementId);

		await entitlementRef.set(
			{
				uid,
				moduleId,
				moduleName: subData.moduleName || moduleId,
				status,
				payerType: subData.payerType || "self",
				payerUid: subData.payerUid || uid,
				renewalDate: expiryTime,
				autoRenewing: verifiedData.autoRenewing,
				lastVerifiedAt: admin.firestore.FieldValue.serverTimestamp(),
				source: "google",
			},
			{ merge: true }
		);
	});

// Handle initial subscription purchase from Play Store
exports.recordPlaySubscription = onRequest(async (req, res) => {
	try {
		const {uid, packageName, subscriptionId, purchaseToken, companyId, moduleId, moduleName, payerType, payerUid} = req.body;

		if (!uid || !packageName || !subscriptionId || !purchaseToken || !companyId || !moduleId) {
			return res.status(400).send("Missing required fields");
		}

		// Verify with Play Developer API
		let verifiedData;
		if (purchaseToken.startsWith("test_token_")) {
			// Allow test tokens for development/demo purposes
			const isAnnual = subscriptionId && subscriptionId.includes("annual");
			const isDaily = subscriptionId && subscriptionId.includes("daily");
			const durationDays = isAnnual ? 365 : (isDaily ? 1 : 30);
			
			verifiedData = {
				expiryTimeMillis: (Date.now() + durationDays * 24 * 60 * 60 * 1000).toString(),
				autoRenewing: true,
			};
			logger.info("Using mock verification for test token", {uid, purchaseToken, isAnnual});
		} else {
			verifiedData = await verifyPlaySubscription(packageName, subscriptionId, purchaseToken);
		}

		if (!verifiedData) {
			return res.status(401).send("Subscription verification failed");
		}

		const expiryTime = verifiedData.expiryTimeMillis ? new Date(parseInt(verifiedData.expiryTimeMillis)) : null;

		// Determine plan type and credits needed
		const isAnnual = subscriptionId && subscriptionId.toLowerCase().includes("annual");
		const isDaily = subscriptionId && subscriptionId.toLowerCase().includes("daily");
		const creditsNeeded = isAnnual ? 999 : (isDaily ? 49 : 99); // annual=999, daily=49, monthly=99
		
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

		await writeBillingEvent({
			type: "credits_deducted",
			companyId,
			uid,
			moduleId,
			moduleName: effectiveModuleName,
			subscriptionId,
			creditsDeducted: creditsNeeded,
			balanceAfter: newBalance,
		}, "system");

		logger.info("Credits deducted", {companyId, creditsDeducted: creditsNeeded, newBalance});

		// Create subscription record
		await db.collection("subscriptions").doc(purchaseToken).set({
			uid,
			packageName,
			subscriptionId,
			purchaseToken,
			companyId,
			moduleId,
			moduleName: effectiveModuleName,
			payerType: payerType || "self",
			payerUid: payerUid || uid,
			status: "active",
			autoRenewing: verifiedData.autoRenewing,
			expiryTime,
			creditsCharged: creditsNeeded,
			createdAt: admin.firestore.FieldValue.serverTimestamp(),
			lastVerifiedAt: admin.firestore.FieldValue.serverTimestamp(),
			source: "google",
		});

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
			autoRenewing: verifiedData.autoRenewing,
			subscriptionId,
			purchaseToken,
			createdAt: admin.firestore.FieldValue.serverTimestamp(),
			lastVerifiedAt: admin.firestore.FieldValue.serverTimestamp(),
			source: "google",
		});

		await writeBillingEvent({
			type: "subscription_recorded",
			uid,
			moduleId,
			moduleName: effectiveModuleName,
			packageName,
			subscriptionId,
		}, "google");

		logger.info("Subscription recorded", {uid, moduleId, packageName, creditsCharged: creditsNeeded});
		res.status(200).json({
			success: true,
			entitlementId,
			expiryTime,
			autoRenewing: verifiedData.autoRenewing,
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
		const {purchaseToken} = req.body;

		if (!purchaseToken) {
			return res.status(400).send("Missing purchaseToken");
		}

		const subsSnap = await db.collection("subscriptions").doc(purchaseToken).get();
		if (!subsSnap.exists) {
			return res.status(404).send("Subscription not found");
		}

		const subData = subsSnap.data();
		const {packageName, subscriptionId} = subData;

		// Verify with Play Developer API
		let verifiedData;
		if (purchaseToken.startsWith("test_token_")) {
			// Allow test tokens for development/demo purposes
			const isAnnual = subscriptionId && subscriptionId.includes("annual");
			const isDaily = subscriptionId && subscriptionId.includes("daily");
			const durationDays = isAnnual ? 365 : (isDaily ? 1 : 30);
			const storedExpiry = toJsDate(subData.expiryTime);
			const expiryMillis = storedExpiry
				? storedExpiry.getTime()
				: Date.now() + durationDays * 24 * 60 * 60 * 1000;

			verifiedData = {
				expiryTimeMillis: expiryMillis.toString(),
				autoRenewing: subData.autoRenewing !== undefined ? subData.autoRenewing : true,
			};
			logger.info("Using mock verification for test token refresh", {purchaseToken, isAnnual});
		} else {
			verifiedData = await verifyPlaySubscription(packageName, subscriptionId, purchaseToken);
		}

		if (!verifiedData) {
			return res.status(401).send("Subscription verification failed");
		}

		const expiryTime = verifiedData.expiryTimeMillis ? new Date(parseInt(verifiedData.expiryTimeMillis)) : null;
		const newStatus = verifiedData.autoRenewing || new Date(expiryTime) > new Date() ? "active" : "expired";
		const previousStatus = subData.status;
		const wasRenewed = previousStatus !== "active" && newStatus === "active" && verifiedData.autoRenewing;

		// Update subscription
		await subsSnap.ref.set({
			status: newStatus,
			autoRenewing: verifiedData.autoRenewing,
			expiryTime,
			lastVerifiedAt: admin.firestore.FieldValue.serverTimestamp(),
		}, {merge: true});

		// Update entitlement
		const {uid, moduleId, companyId, payerUid} = subData;
		const entitlementId = `${uid}_${moduleId}`;
		await db.collection("companies").doc(companyId).collection("entitlements").doc(entitlementId).set({
			status: newStatus,
			renewalDate: expiryTime,
			autoRenewing: verifiedData.autoRenewing,
			lastVerifiedAt: admin.firestore.FieldValue.serverTimestamp(),
		}, {merge: true});

		// Deduct credits if subscription was renewed (renewed via refresh call and autoRenewing is true)
		if (wasRenewed && verifiedData.autoRenewing) {
			try {
				const isAnnual = subscriptionId && subscriptionId.includes("annual");
				const isDaily = subscriptionId && subscriptionId.includes("daily");
				const creditsToDeduct = isAnnual ? 999 : (isDaily ? 49 : 99);
				const amountUsd = creditsToDeduct * 0.01;

				const creditOwner = payerUid || uid;
				const billingRef = getUserCreditsRef(companyId, creditOwner);
				const billingSnap = await billingRef.get();

				const currentBalance = billingSnap.exists ? (billingSnap.data().balance || 0) : 0;

				if (currentBalance >= creditsToDeduct) {
					const newBalance = currentBalance - creditsToDeduct;

					const renewalTransaction = {
						amount: -amountUsd,
						credits: -creditsToDeduct,
						date: new Date().toISOString(),
						type: "subscription",
						renewalSource: "auto",
						moduleId,
						moduleName: subData.moduleName,
						subscriptionId,
						uid,
						userEmail: uid,
					};

					let transactionHistory = billingSnap.exists && billingSnap.data().transactionHistory
						? Array.isArray(billingSnap.data().transactionHistory)
							? billingSnap.data().transactionHistory
							: []
						: [];

					transactionHistory.push(renewalTransaction);

					await billingRef.set({
						balance: newBalance,
						transactionHistory: transactionHistory,
						companyId,
						userKey: creditOwner,
						lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
					}, {merge: true});

					logger.info("Subscription renewal credits deducted", {
						companyId,
						uid,
						moduleId,
						creditsDeducted: creditsToDeduct,
						newBalance,
					});
				} else {
					logger.warn("Insufficient credits for subscription renewal", {
						companyId,
						uid,
						moduleId,
						currentBalance,
						creditsNeeded: creditsToDeduct,
					});
				}
			} catch (creditError) {
				logger.error("Failed to deduct credits for subscription renewal", creditError);
				// Still allow the refresh to succeed, just log the credit error
			}
		}

		await writeBillingEvent({
			type: "subscription_refreshed",
			uid,
			moduleId,
			moduleName: subData.moduleName,
			status: newStatus,
			wasRenewed,
		}, "google");

		logger.info("Subscription refreshed", {purchaseToken, status: newStatus, wasRenewed});
		res.status(200).json({
			success: true,
			status: newStatus,
			expiryTime: expiryTime ? expiryTime.toISOString() : null,
			autoRenewing: verifiedData.autoRenewing,
		});
	} catch (e) {
		logger.error("Refresh subscription error", e);
		res.status(500).send("ERROR");
	}
});

exports.manualRenewSubscription = onRequest(async (req, res) => {
	try {
		const {purchaseToken, uid, companyId, moduleId, moduleName} = req.body;

		if (!purchaseToken) {
			return res.status(400).send("Missing purchaseToken");
		}

		const renewalResult = await renewSubscriptionWithCredits({
			purchaseToken,
			forceRenew: true,
			reason: "manual_request",
			fallbackUid: uid,
			fallbackCompanyId: companyId,
			fallbackModuleId: moduleId,
			fallbackModuleName: moduleName,
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
		const {purchaseToken} = req.body;

		if (!purchaseToken) {
			return res.status(400).send("Missing purchaseToken");
		}

		const subsSnap = await db.collection("subscriptions").doc(purchaseToken).get();
		if (!subsSnap.exists) {
			return res.status(404).send("Subscription not found");
		}

		const subData = subsSnap.data();
		const {packageName, subscriptionId, companyId, uid, moduleId} = subData;

		if (!packageName || !subscriptionId) {
			return res.status(400).send("Missing subscription metadata");
		}

		if (purchaseToken.startsWith("test_token_")) {
			const expiryTime = toJsDate(subData.expiryTime);
			const status = expiryTime && expiryTime > new Date() ? "active" : "expired";

			await subsSnap.ref.set({
				autoRenewing: false,
				status,
				lastVerifiedAt: admin.firestore.FieldValue.serverTimestamp(),
			}, {merge: true});

			if (companyId && uid && moduleId) {
				const entitlementId = `${uid}_${moduleId}`;
				await db.collection("companies").doc(companyId).collection("entitlements").doc(entitlementId).set({
					autoRenewing: false,
					status,
					renewalDate: expiryTime,
					lastVerifiedAt: admin.firestore.FieldValue.serverTimestamp(),
				}, {merge: true});
			}

			await writeBillingEvent({
				type: "subscription_auto_renew_disabled",
				uid,
				moduleId,
				moduleName: subData.moduleName,
			}, "google");

			return res.status(200).json({
				success: true,
				status,
				autoRenewing: false,
				expiryTime: expiryTime ? expiryTime.toISOString() : null,
			});
		}

		const accessToken = await getPlayDeveloperAccessToken();
		const endpoint = `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${packageName}/subscriptions/${subscriptionId}/purchases/tokens/${purchaseToken}:cancel`;

		const response = await fetch(endpoint, {
			method: "POST",
			headers: {
				Authorization: `Bearer ${accessToken}`,
			},
		});

		if (!response.ok) {
			logger.warn("Play API cancel failed", {
				status: response.status,
				packageName,
				subscriptionId,
				purchaseToken,
			});
			return res.status(502).send("Play cancel failed");
		}

		const verifiedData = await verifyPlaySubscription(packageName, subscriptionId, purchaseToken);
		if (!verifiedData) {
			return res.status(401).send("Subscription verification failed");
		}

		const expiryTime = verifiedData.expiryTimeMillis
			? new Date(parseInt(verifiedData.expiryTimeMillis))
			: null;
		const status = expiryTime && expiryTime > new Date() ? "active" : "expired";

		await subsSnap.ref.set({
			autoRenewing: verifiedData.autoRenewing,
			status,
			expiryTime,
			lastVerifiedAt: admin.firestore.FieldValue.serverTimestamp(),
		}, {merge: true});

		if (companyId && uid && moduleId) {
			const entitlementId = `${uid}_${moduleId}`;
			await db.collection("companies").doc(companyId).collection("entitlements").doc(entitlementId).set({
				autoRenewing: verifiedData.autoRenewing,
				status,
				renewalDate: expiryTime,
				lastVerifiedAt: admin.firestore.FieldValue.serverTimestamp(),
			}, {merge: true});
		}

		await writeBillingEvent({
			type: "subscription_auto_renew_disabled",
			uid,
			moduleId,
			moduleName: subData.moduleName,
		}, "google");

		return res.status(200).json({
			success: true,
			status,
			autoRenewing: verifiedData.autoRenewing,
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
		const {purchaseToken} = req.body;

		if (!purchaseToken) {
			return res.status(400).send("Missing purchaseToken");
		}

		const subsSnap = await db.collection("subscriptions").doc(purchaseToken).get();
		if (!subsSnap.exists) {
			return res.status(404).send("Subscription not found");
		}

		const subData = subsSnap.data();
		const {companyId, uid, moduleId} = subData;

		if (purchaseToken.startsWith("test_token_")) {
			const expiryTime = toJsDate(subData.expiryTime);
			const status = expiryTime && expiryTime > new Date() ? "active" : "expired";

			await subsSnap.ref.set({
				autoRenewing: true,
				status,
				lastVerifiedAt: admin.firestore.FieldValue.serverTimestamp(),
			}, {merge: true});

			if (companyId && uid && moduleId) {
				const entitlementId = `${uid}_${moduleId}`;
				await db.collection("companies").doc(companyId).collection("entitlements").doc(entitlementId).set({
					autoRenewing: true,
					status,
					renewalDate: expiryTime,
					lastVerifiedAt: admin.firestore.FieldValue.serverTimestamp(),
				}, {merge: true});
			}

			await writeBillingEvent({
				type: "subscription_auto_renew_enabled",
				uid,
				moduleId,
				moduleName: subData.moduleName,
			}, "google");

			return res.status(200).json({
				success: true,
				status,
				autoRenewing: true,
				expiryTime: expiryTime ? expiryTime.toISOString() : null,
			});
		}

		return res.status(400).send("Enable auto-renew in Google Play Store and refresh.");
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

		if (hasExpired && currentEntData.autoRenewing === true && currentEntData.purchaseToken) {
			try {
				const renewalResult = await renewSubscriptionWithCredits({
					purchaseToken: currentEntData.purchaseToken,
					forceRenew: false,
					reason: "status_check",
					fallbackUid: uid,
					fallbackCompanyId: companyId,
					fallbackModuleId: moduleId,
					fallbackModuleName: currentEntData.moduleName || moduleId,
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

			if (currentEntData.purchaseToken) {
				await db.collection("subscriptions").doc(currentEntData.purchaseToken).set({
					status: "expired",
					lastVerifiedAt: admin.firestore.FieldValue.serverTimestamp(),
				}, {merge: true});
			}

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
			source: currentEntData.source,
			subscriptionId: currentEntData.subscriptionId,
			purchaseToken: currentEntData.purchaseToken,
			lastVerifiedAt: toJsDate(currentEntData.lastVerifiedAt) ? toJsDate(currentEntData.lastVerifiedAt).toISOString() : null,
		});
	} catch (e) {
		logger.error("Get entitlement error", e);
		res.status(500).send("ERROR");
	}
});

exports.appleServerNotifications = onRequest(async (req, res) => {
	try {
		const payload = req.body;
		await writeBillingEvent(payload, "apple");
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

		await writeBillingEvent({
			type: "credits_topup",
			companyId,
			credits,
			amountUsd,
		}, "system");

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

		await writeBillingEvent({
			type: "auto_topup_set",
			companyId,
			enabled,
			amount: enabled ? (amount || 1000) : null,
		}, "system");

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
		const creditsSnapshot = await db.collection("userCredits")
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

				await writeBillingEvent({
					type: "auto_topup_executed",
					companyId,
					userKey,
					credits: autoTopupAmount,
					amountUsd,
					balanceAfter: newBalance,
				}, "system");

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

// Scheduled function: Process subscription renewals daily and deduct credits
exports.processSubscriptionRenewals = onSchedule({
	schedule: "0 0 * * *", // Run at midnight UTC every day
	timeZone: "UTC",
}, async (context) => {
	try {
		const now = new Date();
		logger.info("Starting subscription renewal process", {timestamp: now.toISOString()});

		const companiesSnapshot = await db.collection("companies").get();
		let totalSubscriptions = 0;
		let renewedCount = 0;
		let failedCount = 0;

		// Iterate through all companies
		for (const companyDoc of companiesSnapshot.docs) {
			const companyId = companyDoc.id;

			// Get all subscriptions for this company
			const subscriptionsSnapshot = await db.collection("subscriptions")
				.where("companyId", "==", companyId)
				.where("autoRenewing", "==", true)
				.get();

			totalSubscriptions += subscriptionsSnapshot.size;

			for (const subDoc of subscriptionsSnapshot.docs) {
				const subData = subDoc.data();
				const {uid, moduleId, expiryTime, subscriptionId, payerUid} = subData;
				const creditOwner = payerUid || uid;

				const expiryDate = expiryTime instanceof admin.firestore.Timestamp 
					? expiryTime.toDate() 
					: new Date(expiryTime);

				// Check if subscription is due for renewal (expiry date has passed)
				if (expiryDate <= now) {
					try {
						// Calculate credits to deduct based on subscription type
						const normalizedSubscriptionId = (subscriptionId || "").toLowerCase();
						const isAnnual = normalizedSubscriptionId.includes("annual");
						const isDaily = normalizedSubscriptionId.includes("daily");
						const creditsToDeduct = isAnnual ? 999 : (isDaily ? 49 : 99);
						const amountUsd = creditsToDeduct * 0.01;

						// Get fresh billing data for each renewal to avoid stale balance across modules
						const billingRef = getUserCreditsRef(companyId, creditOwner);
						const latestBillingSnap = await billingRef.get();
						const currentBillingData = latestBillingSnap.exists ? latestBillingSnap.data() : {};
						const currentBalance = currentBillingData.balance || 0;

						// Check if company has sufficient credits
						if (currentBalance < creditsToDeduct) {
							logger.warn("Insufficient credits for renewal", {
								companyId,
								uid,
								moduleId,
								currentBalance,
								creditsNeeded: creditsToDeduct,
							});
							// Update entitlement status to expired if insufficient credits
							const entitlementId = `${uid}_${moduleId}`;
							await db.collection("companies").doc(companyId)
								.collection("entitlements").doc(entitlementId).set({
									status: "expired",
									autoRenewing: false,
									lastVerifiedAt: admin.firestore.FieldValue.serverTimestamp(),
								}, {merge: true});
							await subDoc.ref.set({
								status: "expired",
								autoRenewing: false,
								lastVerifiedAt: admin.firestore.FieldValue.serverTimestamp(),
							}, {merge: true});
							failedCount++;
							continue;
						}

						const newBalance = currentBalance - creditsToDeduct;

						// Record renewal transaction
						const renewalTransaction = {
							amount: -amountUsd,
							credits: -creditsToDeduct,
							date: new Date().toISOString(),
							type: "subscription",
							renewalSource: "auto",
							moduleId,
							moduleName: subData.moduleName,
							subscriptionId,
							uid,
							userEmail: uid,
						};

						// Get existing transaction history
						let transactionHistory = currentBillingData.transactionHistory
							? Array.isArray(currentBillingData.transactionHistory)
								? currentBillingData.transactionHistory
								: []
							: [];

						transactionHistory.push(renewalTransaction);

						// Update billing with new balance and transaction
						await billingRef.set({
							balance: newBalance,
							transactionHistory: transactionHistory,
							companyId,
							userKey: creditOwner,
							lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
						}, {merge: true});

						// Calculate new expiry date (add 30/365 days based on plan)
						const durationDays = isAnnual ? 365 : (isDaily ? 1 : 30);
						const newExpiryDate = new Date(expiryDate.getTime() + durationDays * 24 * 60 * 60 * 1000);

						// Update subscription with new expiry date
						await subDoc.ref.set({
							expiryTime: newExpiryDate,
							status: "active",
							lastVerifiedAt: admin.firestore.FieldValue.serverTimestamp(),
						}, {merge: true});

						// Update entitlement
						const entitlementId = `${uid}_${moduleId}`;
						await db.collection("companies").doc(companyId)
							.collection("entitlements").doc(entitlementId).set({
								renewalDate: newExpiryDate,
								status: "active",
								lastVerifiedAt: admin.firestore.FieldValue.serverTimestamp(),
							}, {merge: true});

						// Record billing event
						await writeBillingEvent({
							type: "subscription_auto_renewed",
							companyId,
							uid,
							moduleId,
							moduleName: subData.moduleName,
							creditsDeducted: creditsToDeduct,
							newBalance,
						}, "system");

						logger.info("Subscription renewed successfully", {
							companyId,
							uid,
							moduleId,
							creditsDeducted: creditsToDeduct,
							newBalance,
							newExpiryDate: newExpiryDate.toISOString(),
						});

						renewedCount++;
					} catch (renewalError) {
						logger.error("Failed to process subscription renewal", renewalError, {
							companyId,
							subscriptionId: subDoc.id,
							error: renewalError.message,
						});
						failedCount++;
					}
				}
			}
		}

		logger.info("Subscription renewal process completed", {
			totalSubscriptions,
			renewedCount,
			failedCount,
		});

		return {
			success: true,
			totalSubscriptions,
			renewedCount,
			failedCount,
		};
	} catch (error) {
		logger.error("Subscription renewal process failed", error);
		throw error;
	}
});
