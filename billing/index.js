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
		const {uid, packageName, subscriptionId, purchaseToken, companyId, moduleId, payerType, payerUid} = req.body;

		if (!uid || !packageName || !subscriptionId || !purchaseToken || !companyId || !moduleId) {
			return res.status(400).send("Missing required fields");
		}

		// Verify with Play Developer API
		let verifiedData;
		if (purchaseToken.startsWith("test_token_")) {
			// Allow test tokens for development/demo purposes
			const isAnnual = subscriptionId && subscriptionId.includes("annual");
			const durationDays = isAnnual ? 365 : 30;
			
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

		// Create subscription record
		await db.collection("subscriptions").doc(purchaseToken).set({
			uid,
			packageName,
			subscriptionId,
			purchaseToken,
			companyId,
			moduleId,
			payerType: payerType || "self",
			payerUid: payerUid || uid,
			status: "active",
			autoRenewing: verifiedData.autoRenewing,
			expiryTime,
			createdAt: admin.firestore.FieldValue.serverTimestamp(),
			lastVerifiedAt: admin.firestore.FieldValue.serverTimestamp(),
			source: "google",
		});

		// Create entitlement record
		const entitlementId = `${uid}_${moduleId}`;
		await db.collection("companies").doc(companyId).collection("entitlements").doc(entitlementId).set({
			uid,
			moduleId,
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
			packageName,
			subscriptionId,
		}, "google");

		logger.info("Subscription recorded", {uid, moduleId, packageName});
		res.status(200).json({
			success: true,
			entitlementId,
			expiryTime,
			autoRenewing: verifiedData.autoRenewing,
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
			const durationDays = isAnnual ? 365 : 30;

			verifiedData = {
				expiryTimeMillis: (Date.now() + durationDays * 24 * 60 * 60 * 1000).toString(),
				autoRenewing: true,
			};
			logger.info("Using mock verification for test token refresh", {purchaseToken, isAnnual});
		} else {
			verifiedData = await verifyPlaySubscription(packageName, subscriptionId, purchaseToken);
		}

		if (!verifiedData) {
			return res.status(401).send("Subscription verification failed");
		}

		const expiryTime = verifiedData.expiryTimeMillis ? new Date(parseInt(verifiedData.expiryTimeMillis)) : null;
		const status = verifiedData.autoRenewing || new Date(expiryTime) > new Date() ? "active" : "expired";

		// Update subscription
		await subsSnap.ref.set({
			status,
			autoRenewing: verifiedData.autoRenewing,
			expiryTime,
			lastVerifiedAt: admin.firestore.FieldValue.serverTimestamp(),
		}, {merge: true});

		// Update entitlement
		const {uid, moduleId, companyId} = subData;
		const entitlementId = `${uid}_${moduleId}`;
		await db.collection("companies").doc(companyId).collection("entitlements").doc(entitlementId).set({
			status,
			renewalDate: expiryTime,
			autoRenewing: verifiedData.autoRenewing,
			lastVerifiedAt: admin.firestore.FieldValue.serverTimestamp(),
		}, {merge: true});

		await writeBillingEvent({
			type: "subscription_refreshed",
			uid,
			moduleId,
			status,
		}, "google");

		logger.info("Subscription refreshed", {purchaseToken, status});
		res.status(200).json({
			success: true,
			status,
			expiryTime: expiryTime ? expiryTime.toISOString() : null,
			autoRenewing: verifiedData.autoRenewing,
		});
	} catch (e) {
		logger.error("Refresh subscription error", e);
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
		const expiryTime = toJsDate(entData.renewalDate);
		const hasExpired = expiryTime && expiryTime < now;
		const hasAccess = entData.status === "active" && !hasExpired;

		res.status(200).json({
			status: entData.status,
			hasAccess,
			renewalDate: expiryTime ? expiryTime.toISOString() : null,
			autoRenewing: entData.autoRenewing,
			payerType: entData.payerType,
			source: entData.source,
			subscriptionId: entData.subscriptionId,
			purchaseToken: entData.purchaseToken,
			lastVerifiedAt: toJsDate(entData.lastVerifiedAt) ? toJsDate(entData.lastVerifiedAt).toISOString() : null,
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
