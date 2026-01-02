const functions = require('firebase-functions');
const admin = require('firebase-admin');

/**
 * Atualiza Custom Claims quando um usuário é criado ou modificado.
 *
 * Claims structure:
 * {
 *   roles: {
 *     'companyId1': 'admin',
 *     'companyId2': 'user',
 *     ...
 *   }
 * }
 *
 * Uso nas Security Rules:
 * - Verificar acesso: request.auth.token.roles[companyId] != null
 * - Verificar role: request.auth.token.roles[companyId] == 'admin'
 */
exports.updateUserClaims = functions.region('southamerica-east1').firestore
  .document('users/{userId}')
  .onWrite(async (change, context) => {
    const userId = context.params.userId;

    // Se usuário foi deletado, remove claims
    if (!change.after.exists) {
      console.log(`User ${userId} deleted, removing claims.`);
      return admin.auth().setCustomUserClaims(userId, null);
    }

    const userData = change.after.data();

    // Estrutura do campo 'companies' no User:
    // List<CompanyRoleAggr> onde CompanyRoleAggr = { company: { id: ... }, role: ... }
    const roles = {};

    if (userData.companies && Array.isArray(userData.companies)) {
      userData.companies.forEach(item => {
        if (item.company && item.company.id && item.role) {
          const companyId = item.company.id;
          // Converte role para lowercase para consistência nas rules
          roles[companyId] = String(item.role).toLowerCase();
        }
      });
    }

    // Claims simplificado - apenas o mapa de roles
    // As companies são inferidas das chaves: Object.keys(roles) ou roles.keys() nas rules
    const claims = { roles };

    console.log(`Updating claims for user ${userId}:`, JSON.stringify(claims));

    try {
      await admin.auth().setCustomUserClaims(userId, claims);
      console.log(`Claims updated successfully for ${userId}`);
    } catch (error) {
      console.error(`Error updating claims for ${userId}:`, error);
    }
  });
