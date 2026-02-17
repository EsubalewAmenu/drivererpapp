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

exports.googlePlayRtdn = onMessagePublished("google-play-rtdn", async (event) => {
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

		const purchaseToken = sub.purchaseToken;
		const notificationType = sub.notificationType;
		const status = normalizeStatus(notificationType);

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

		await subDoc.ref.set(
			{
				status,
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
				renewalDate: subData.renewalDate || null,
				lastVerifiedAt: admin.firestore.FieldValue.serverTimestamp(),
				source: "google",
			},
			{ merge: true }
		);
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
