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
const {createSubscriptionHandlers} = require("./src/subscriptionHandlers");
const {createCreditsHandlers} = require("./src/creditsHandlers");

setGlobalOptions({maxInstances: 10});

if (!admin.apps.length) {
	admin.initializeApp();
}

const db = admin.firestore();

exports.health = onRequest((request, response) => {
	logger.info("Health check", {structuredData: true});
	response.status(200).send("OK");
});

const context = {
	admin,
	db,
	logger,
	onRequest,
	onSchedule,
};

Object.assign(exports, createSubscriptionHandlers(context));
Object.assign(exports, createCreditsHandlers(context));
