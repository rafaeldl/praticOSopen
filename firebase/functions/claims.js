const functions = require('firebase-functions');
const admin = require('firebase-admin');

/**
 * Perfis de usuário no PraticOS (RBAC)
 *
 * Hierarquia de perfis:
 * - admin: Administrador - Acesso total ao sistema
 * - gerente: Gerente (Financeiro) - Gestão financeira
 * - supervisor: Supervisor - Gestão operacional
 * - consultor: Consultor (Vendedor) - Perfil comercial
 * - tecnico: Técnico - Execução de serviços
 *
 * Roles legados (mapeados automaticamente):
 * - manager -> supervisor
 * - user -> tecnico
 */
const ROLE_MAPPINGS = {
  'manager': 'supervisor',
  'user': 'tecnico'
};

/**
 * Normaliza roles legados para os novos perfis.
 * @param {string} role - O role a ser normalizado
 * @returns {string} O role normalizado
 */
function normalizeRole(role) {
  const lowerRole = String(role).toLowerCase();
  return ROLE_MAPPINGS[lowerRole] || lowerRole;
}

/**
 * Atualiza Custom Claims quando um usuário é criado ou modificado.
 *
 * Claims structure:
 * {
 *   roles: {
 *     'companyId1': 'admin',
 *     'companyId2': 'tecnico',
 *     ...
 *   }
 * }
 *
 * Uso nas Security Rules:
 * - Verificar acesso: request.auth.token.roles[companyId] != null
 * - Verificar role: request.auth.token.roles[companyId] == 'admin'
 * - Verificar múltiplos roles: request.auth.token.roles[companyId] in ['admin', 'gerente']
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
    const seenCompanies = new Set();

    if (userData.companies && Array.isArray(userData.companies)) {
      userData.companies.forEach(item => {
        if (item.company && item.company.id && item.role) {
          const companyId = item.company.id;

          // Detecta e ignora duplicatas
          if (seenCompanies.has(companyId)) {
            console.warn(`[Claims] Duplicate company detected for user ${userId}: ${companyId}. Ignoring duplicate entry.`);
            return; // Mantém a primeira ocorrência
          }

          seenCompanies.add(companyId);
          // Normaliza e converte role para lowercase para consistência nas rules
          roles[companyId] = normalizeRole(item.role);
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
