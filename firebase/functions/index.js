const functions = require('firebase-functions');

const admin = require('firebase-admin');
admin.initializeApp();

const db = admin.firestore();

exports.firestoreUpdateOSNumber = functions.region('southamerica-east1').firestore.document('orders/{id}').onCreate(async (snapshot, context) => {
  const data = snapshot.data();
  if (data.number) return;
  const companyAggr = data.company;
  if (!companyAggr) return;
  const companyRef = db.collection('companies').doc(companyAggr.id);
  const company = await companyRef.get();
  if (!company.exists) return;
  const companyData = company.data();

  let nextOrderNumber;
  let number = companyData.nextOrderNumber;
  if (!number) {
    number = 1;
    nextOrderNumber = 2;
  } else {
    nextOrderNumber = admin.firestore.FieldValue.increment(1)
  }
  companyRef.set({nextOrderNumber}, {merge: true});
  snapshot.ref.set({number}, {merge: true});
});

// // Create and Deploy Your First Cloud Functions
// // https://firebase.google.com/docs/functions/write-firebase-functions
//
// exports.helloWorld = functions.https.onRequest((request, response) => {
//  response.send("Hello from Firebase!");
// });

const claims = require('./claims');
exports.updateUserClaims = claims.updateUserClaims;
