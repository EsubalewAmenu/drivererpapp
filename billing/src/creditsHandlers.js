const {getUserCreditsRef} = require("./userCreditsStore");
const {google} = require("googleapis");
const crypto = require("crypto");

const TOPUP_PRODUCT_CREDITS = {
	credits_100: 100,
	credits_500: 500,
	credits_1000: 1000,
	credits_5000: 5000,
	credits_10000: 10000,
};

const APPLE_VERIFY_RECEIPT_PRODUCTION_URL = "https://buy.itunes.apple.com/verifyReceipt";
const APPLE_VERIFY_RECEIPT_SANDBOX_URL = "https://sandbox.itunes.apple.com/verifyReceipt";

function purchaseFingerprint(platform, purchaseId) {
	return crypto
		.createHash("sha256")
		.update(`${platform || "unknown"}:${purchaseId || ""}`)
		.digest("hex");
}

function createCreditsHandlers({admin, db, logger, onRequest, onSchedule}) {
	async function verifyGooglePlayPurchase({purchaseToken, productId, packageName}) {
		const auth = new google.auth.GoogleAuth({
			scopes: ["https://www.googleapis.com/auth/androidpublisher"],
		});

		const authClient = await auth.getClient();
		const androidpublisher = google.androidpublisher({
			version: "v3",
			auth: authClient,
		});

		const response = await androidpublisher.purchases.products.get({
			packageName,
			productId,
			token: purchaseToken,
		});

		const purchaseState = response?.data?.purchaseState;
		const consumptionState = response?.data?.consumptionState;

		if (purchaseState !== 0) {
			throw new Error(`Google Play purchaseState=${purchaseState} (expected 0)`);
		}

		return {
			purchaseState,
			consumptionState,
			orderId: response?.data?.orderId || null,
		};
	}

	async function verifyApplePurchase({receiptData, productId}) {
		const requestPayload = {
			"receipt-data": receiptData,
			"exclude-old-transactions": true,
		};

		const sharedSecret =
			process.env.APPLE_SHARED_SECRET ||
			process.env.APPLE_APP_SHARED_SECRET ||
			null;

		if (sharedSecret) {
			requestPayload.password = sharedSecret;
		}

		const verifyReceipt = async (url) => {
			const response = await fetch(url, {
				method: "POST",
				headers: {
					"Content-Type": "application/json",
				},
				body: JSON.stringify(requestPayload),
			});

			if (!response.ok) {
				throw new Error(`Apple verifyReceipt HTTP ${response.status}`);
			}

			return response.json();
		};

		let verifyResponse = await verifyReceipt(APPLE_VERIFY_RECEIPT_PRODUCTION_URL);

		if (verifyResponse.status === 21007) {
			verifyResponse = await verifyReceipt(APPLE_VERIFY_RECEIPT_SANDBOX_URL);
		}

		if (verifyResponse.status !== 0) {
			throw new Error(`Apple verifyReceipt status=${verifyResponse.status}`);
		}

		const expectedBundleId = process.env.APPLE_BUNDLE_ID || null;
		const responseBundleId = verifyResponse?.receipt?.bundle_id || null;

		if (expectedBundleId && responseBundleId && expectedBundleId !== responseBundleId) {
			throw new Error("Apple receipt bundle_id does not match APPLE_BUNDLE_ID");
		}

		const receiptTransactions = Array.isArray(verifyResponse?.receipt?.in_app)
			? verifyResponse.receipt.in_app
			: [];
		const latestReceiptTransactions = Array.isArray(verifyResponse?.latest_receipt_info)
			? verifyResponse.latest_receipt_info
			: [];

		const allTransactions = receiptTransactions.concat(latestReceiptTransactions);
		const matchingTransactions = allTransactions.filter(
			(transaction) => transaction?.product_id === productId,
		);

		if (!matchingTransactions.length) {
			throw new Error(`Apple receipt does not contain productId=${productId}`);
		}

		const verifiedTransaction = matchingTransactions.reduce((latest, current) => {
			const latestDate = Number(latest.purchase_date_ms || 0);
			const currentDate = Number(current.purchase_date_ms || 0);
			return currentDate > latestDate ? current : latest;
		});

		const transactionId =
			verifiedTransaction.transaction_id ||
			verifiedTransaction.original_transaction_id ||
			null;

		if (!transactionId) {
			throw new Error("Apple receipt missing transaction_id");
		}

		return {
			status: verifyResponse.status,
			environment: verifyResponse.environment || null,
			bundleId: responseBundleId,
			transactionId,
			originalTransactionId: verifiedTransaction.original_transaction_id || null,
			purchaseDateMs: verifiedTransaction.purchase_date_ms || null,
		};
	}

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
		// Deployment marker: force refresh after Android Publisher API enablement.
		try {
			const {companyId, credits, platform, purchaseId, productId, packageName} = req.body;
			const userKey = await getUserKeyFromAuth(req);
			logger.info("Topup request received", {companyId, credits, platform, productId});

			if (!companyId || !userKey || !credits || credits <= 0) {
				logger.warn("Invalid parameters", {companyId, credits});
				return res.status(400).send("Missing or invalid parameters");
			}

			if (!platform || !purchaseId || !productId) {
				return res.status(400).json({
					error: "Missing purchase verification fields",
					message: "platform, purchaseId, and productId are required",
				});
			}

			if (purchaseId.startsWith("test_")) {
				return res.status(400).json({
					error: "Test purchase IDs are not allowed in production",
				});
			}

			const expectedCredits = TOPUP_PRODUCT_CREDITS[productId];
			if (!expectedCredits) {
				return res.status(400).json({
					error: "Unknown productId",
					message: `Unrecognized product: ${productId}`,
				});
			}

			if (Number(credits) !== expectedCredits) {
				return res.status(400).json({
					error: "Credits mismatch",
					message: `Product ${productId} must credit ${expectedCredits}`,
				});
			}

			if (platform !== "google_play" && platform !== "apple") {
				return res.status(400).json({
					error: "Unsupported platform",
					message: "Supported topup platforms are google_play and apple",
				});
			}

			let normalizedPurchaseId = purchaseId;
			let resolvedPackageName = null;
			let verification;

			if (platform === "google_play") {
				resolvedPackageName = process.env.ANDROID_PACKAGE_NAME || packageName;
				if (!resolvedPackageName) {
					return res.status(500).json({
						error: "Missing package name configuration",
						message: "Set ANDROID_PACKAGE_NAME env var on Cloud Functions",
					});
				}

				verification = await verifyGooglePlayPurchase({
					purchaseToken: purchaseId,
					productId,
					packageName: resolvedPackageName,
				});
			} else {
				verification = await verifyApplePurchase({
					receiptData: purchaseId,
					productId,
				});

				normalizedPurchaseId = verification.transactionId;
			}

			const purchaseHash = purchaseFingerprint(platform, normalizedPurchaseId);
			const purchaseLogRef = db.collection("purchase_verifications").doc(purchaseHash);
			const purchaseLogSnap = await purchaseLogRef.get();
			if (purchaseLogSnap.exists) {
				return res.status(409).json({
					error: "Duplicate purchase",
					message: "This purchase token was already used",
				});
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
				productId,
			};

			if (platform) newTopup.platform = platform;
			if (normalizedPurchaseId) newTopup.purchaseId = normalizedPurchaseId;

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

			const purchaseLogData = {
				platform,
				purchaseId: normalizedPurchaseId,
				productId,
				companyId,
				userKey,
				credits,
				verification,
				verifiedAt: admin.firestore.FieldValue.serverTimestamp(),
			};

			if (resolvedPackageName) {
				purchaseLogData.packageName = resolvedPackageName;
			}

			await purchaseLogRef.set(purchaseLogData);

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
