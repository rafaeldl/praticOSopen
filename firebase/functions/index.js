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
 * Usa transação para evitar race conditions na numeração.
 */
exports.firestoreUpdateTenantOSNumber = functions.region('southamerica-east1').firestore.document('companies/{companyId}/orders/{orderId}').onCreate(async (snapshot, context) => {
  const data = snapshot.data();
  if (data.number) return;

  const companyId = context.params.companyId;
  const companyRef = db.collection('companies').doc(companyId);
  const orderRef = snapshot.ref;

  // Usa transação para garantir atomicidade na numeração
  await db.runTransaction(async (transaction) => {
    const companyDoc = await transaction.get(companyRef);

    if (!companyDoc.exists) {
      console.error(`Company ${companyId} não encontrada.`);
      return;
    }

    const companyData = companyDoc.data();
    let currentNumber = companyData.nextOrderNumber || 1;

    // Atribui o número atual à ordem
    transaction.update(orderRef, { number: currentNumber });

    // Incrementa o próximo número na empresa
    transaction.update(companyRef, { nextOrderNumber: currentNumber + 1 });

    console.log(`OS #${currentNumber} atribuída à ordem ${orderRef.id} da empresa ${companyId}`);
  });
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

/**
 * [HTTP] Recebimento de logs de eventos do carro.
 * Endpoint: POST /receiveCarEventLogs
 *
 * Recebe eventos do Android Automotive (velocidade, marcha, temperatura, etc.)
 * e salva no Firestore em /carSessions/{sessionId}/events/{eventId}
 */
const carEventLogs = require('./carEventLogs');
exports.receiveCarEventLogs = carEventLogs.receiveCarEventLogs;
