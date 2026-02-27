const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

// Placeholder HTTPS function to verify deployment works.
exports.health = functions.https.onRequest((req, res) => {
  res.status(200).send('OK');
});
