const {getUserCreditsRef} = require("./userCreditsStore");

function toJsDate(value) {
	if (!value) return null;
	if (value instanceof Date) return value;
	if (typeof value.toDate === "function") return value.toDate();
	if (value._seconds) return new Date(value._seconds * 1000);
	if (typeof value === "string") return new Date(value);
	return null;
}

function toIsoOrNull(value) {
	const date = toJsDate(value);
	if (!date || Number.isNaN(date.getTime())) return null;
	return date.toISOString();
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

function createSubscriptionHandlers({admin, db, logger, onRequest}) {
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

		const billingRef = getUserCreditsRef(db, resolvedCompanyId, resolvedPayerUid);
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

	const recordPlaySubscription = onRequest(async (req, res) => {
		try {
			const {uid, subscriptionId, companyId, moduleId, moduleName, payerType, payerUid} = req.body;

			if (!uid || !subscriptionId || !companyId || !moduleId) {
				return res.status(400).send("Missing required fields");
			}

			const isAnnual = subscriptionId && subscriptionId.toLowerCase().includes("annual");
			const isDaily = subscriptionId && subscriptionId.toLowerCase().includes("daily");
			const durationDays = isAnnual ? 365 : (isDaily ? 1 : 30);
			const creditsNeeded = isAnnual ? 999 : (isDaily ? 49 : 99);
			const expiryTime = new Date(Date.now() + durationDays * 24 * 60 * 60 * 1000);

			logger.info("Calculating credits for subscription", {subscriptionId, isAnnual, isDaily, creditsNeeded});

			const creditOwner = payerUid || uid;
			const billingRef = getUserCreditsRef(db, companyId, creditOwner);
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
			const effectiveModuleName = moduleName || moduleId;

			const deductionTransaction = {
				amount: -(creditsNeeded * 0.01),
				credits: -creditsNeeded,
				date: new Date().toISOString(),
				type: "subscription",
				renewalSource: "subscription",
				moduleId,
				moduleName: effectiveModuleName,
				subscriptionId,
				uid,
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
				transactionHistory,
				companyId,
				userKey: creditOwner,
				lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
			}, {merge: true});

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

	const refreshPlaySubscription = onRequest(async (req, res) => {
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

			await entRef.set({
				status: newStatus,
				autoRenewing: refreshedData.autoRenewing,
				renewalDate: refreshedExpiry,
				lastVerifiedAt: admin.firestore.FieldValue.serverTimestamp(),
			}, {merge: true});

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

	const manualRenewSubscription = onRequest(async (req, res) => {
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

	const disablePlayAutoRenew = onRequest(async (req, res) => {
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

	const enablePlayAutoRenew = onRequest(async (req, res) => {
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

	const getModulePricing = onRequest(async (req, res) => {
		try {
			const {moduleName, moduleId} = req.body;
			if (!moduleName && !moduleId) {
				return res.status(400).send("Missing moduleName or moduleId");
			}

			const normalize = (value) => value.toString().toLowerCase().trim();
			const normalizedName = moduleName ? normalize(moduleName) : "";
			const normalizedId = moduleId ? normalize(moduleId) : "";
			const freeModules = ["crm", "inventory", "hr", "finance"];
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

	const getEntitlementStatus = onRequest(async (req, res) => {
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

	const appleServerNotifications = onRequest(async (req, res) => {
		try {
			res.status(200).send("OK");
		} catch (e) {
			logger.error("Apple notification error", e);
			res.status(500).send("ERROR");
		}
	});

	return {
		recordPlaySubscription,
		refreshPlaySubscription,
		manualRenewSubscription,
		disablePlayAutoRenew,
		enablePlayAutoRenew,
		getModulePricing,
		getEntitlementStatus,
		appleServerNotifications,
	};
}

module.exports = {
	createSubscriptionHandlers,
};
