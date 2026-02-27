const {getUserCreditsRef} = require("./userCreditsStore");

function createCreditsHandlers({admin, db, logger, onRequest, onSchedule}) {
	async function getUserKeyFromAuth(req) {
		const authHeader = req.headers.authorization || "";
		if (!authHeader.startsWith("Bearer ")) return null;
		const idToken = authHeader.replace("Bearer ", "").trim();
		const decoded = await admin.auth().verifyIdToken(idToken);
		return decoded.email || decoded.uid || null;
	}

	const getWorkspaceCredits = onRequest(async (req, res) => {
		try {
			const {companyId} = req.body;
			const userKey = await getUserKeyFromAuth(req);

			if (!companyId || !userKey) {
				return res.status(400).send("Missing companyId or user identity");
			}

			const billingRef = getUserCreditsRef(db, companyId, userKey);
			const billingSnap = await billingRef.get();

			if (!billingSnap.exists) {
				return res.status(404).json({
					balance: 0,
					transactionHistory: [],
					autoTopupEnabled: false,
				});
			}

			const billingData = billingSnap.data();
			const transactions = (billingData.transactionHistory || []).map((t) => ({
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

			const allTransactions = transactions.sort((a, b) => new Date(b.date).getTime() - new Date(a.date).getTime());

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

	const topupWorkspaceCredits = onRequest(async (req, res) => {
		try {
			const {companyId, credits, platform, purchaseId} = req.body;
			const userKey = await getUserKeyFromAuth(req);
			logger.info("Topup request received", {companyId, credits, platform, purchaseId});

			if (!companyId || !userKey || !credits || credits <= 0) {
				logger.warn("Invalid parameters", {companyId, credits});
				return res.status(400).send("Missing or invalid parameters");
			}

			const billingRef = getUserCreditsRef(db, companyId, userKey);
			const billingSnap = await billingRef.get();
			logger.info("Got billing snapshot", {companyIdLength: companyId.length, docExists: billingSnap.exists});

			const currentBalance = billingSnap.exists ? (billingSnap.data().balance || 0) : 0;
			const newBalance = currentBalance + credits;
			const amountUsd = credits * 0.01;

			const newTopup = {
				amount: amountUsd,
				credits,
				date: new Date().toISOString(),
				type: "topup",
			};

			if (platform) newTopup.platform = platform;
			if (purchaseId) newTopup.purchaseId = purchaseId;

			let transactionHistory = billingSnap.exists && billingSnap.data().transactionHistory
				? Array.isArray(billingSnap.data().transactionHistory)
					? billingSnap.data().transactionHistory
					: []
				: [];

			transactionHistory.push(newTopup);
			await billingRef.set({
				balance: newBalance,
				transactionHistory,
				companyId,
				userKey,
				lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
			}, {merge: true});

			logger.info("Credits topup recorded", {companyId, credits, newBalance});

			const formattedTransactions = transactionHistory.map((t) => ({
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
			})).sort((a, b) => new Date(b.date).getTime() - new Date(a.date).getTime());

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

	const setAutoTopup = onRequest(async (req, res) => {
		try {
			const {companyId, enabled, amount} = req.body;
			const userKey = await getUserKeyFromAuth(req);

			if (!companyId || !userKey) {
				return res.status(400).send("Missing companyId or user identity");
			}

			const billingRef = getUserCreditsRef(db, companyId, userKey);
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

			const formattedTransactions = currentTransactionHistory.map((t) => ({
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
			})).sort((a, b) => new Date(b.date).getTime() - new Date(a.date).getTime());

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

	const monthlyAutoTopup = onSchedule({
		schedule: "0 0 1 * *",
		timeZone: "UTC",
	}, async () => {
		logger.info("Starting monthly auto-topup process");

		try {
			const creditsSnapshot = await db.collectionGroup("billing")
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

	return {
		getWorkspaceCredits,
		topupWorkspaceCredits,
		setAutoTopup,
		monthlyAutoTopup,
	};
}

module.exports = {
	createCreditsHandlers,
};
