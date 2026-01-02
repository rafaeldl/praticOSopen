const functions = require('firebase-functions');

const admin = require('firebase-admin');
admin.initializeApp();

const db = admin.firestore();

/**
 * [LEGACY] Numeração de OS para estrutura antiga (Field-based).
 * DESATIVADO: Migração concluída para Subcollections.
 */
exports.firestoreUpdateOSNumber = functions.region('southamerica-east1').firestore.document('orders/{id}').onCreate(async (_snapshot, _context) => {
  console.log('[LEGACY] firestoreUpdateOSNumber disparada, mas desativada via código.');
  return null;
  /*
  const data = snapshot.data();
  // ... resto do código comentado ...
  */
});

/**
 * [V2] Numeração de OS para nova estrutura (Subcollections).
 * Gatilho: /companies/{companyId}/orders/{orderId}
 * 
 * Esta é a função definitiva para o modelo Multi-Tenant.
 */
exports.firestoreUpdateTenantOSNumber = functions.region('southamerica-east1').firestore.document('companies/{companyId}/orders/{orderId}').onCreate(async (snapshot, context) => {
  const data = snapshot.data();
  if (data.number) return;
  
  // Na nova estrutura, temos o ID da empresa no path
  const companyId = context.params.companyId;
  const companyRef = db.collection('companies').doc(companyId);
  
  const company = await companyRef.get();
  if (!company.exists) return;
  const companyData = company.data();

  let nextOrderNumber;
  let number = companyData.nextOrderNumber;
  
  if (!number) {
    number = 1;
    nextOrderNumber = 2;
  } else {
    nextOrderNumber = admin.firestore.FieldValue.increment(1);
  }
  
  await companyRef.set({nextOrderNumber}, {merge: true});
  await snapshot.ref.set({number}, {merge: true});
});

/**
 * [GLOBAL] Gerenciamento de Custom Claims.
 * Gatilho: /users/{userId}
 * 
 * Atualiza os claims de autenticação (companies, roles) sempre que o usuário é modificado.
 * Essencial para as Security Rules da nova estrutura.
 */
const claims = require('./claims');
exports.updateUserClaims = claims.updateUserClaims;
