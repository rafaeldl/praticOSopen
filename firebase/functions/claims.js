const functions = require('firebase-functions');
const admin = require('firebase-admin');

// Function to update custom claims when a user is created or updated
exports.updateUserClaims = functions.region('southamerica-east1').firestore
  .document('users/{userId}')
  .onWrite(async (change, context) => {
    const userId = context.params.userId;
    
    // If user is deleted, remove claims
    if (!change.after.exists) {
      console.log(`User ${userId} deleted, removing claims.`);
      return admin.auth().setCustomUserClaims(userId, null);
    }

    const userData = change.after.data();
    
    // Structure of 'companies' field in User:
    // List<CompanyRoleAggr> where CompanyRoleAggr has { company: { id: ... }, role: ... }
    
    const companiesList = [];
    const rolesMap = {};

    if (userData.companies && Array.isArray(userData.companies)) {
      userData.companies.forEach(item => {
        if (item.company && item.company.id) {
          const companyId = item.company.id;
          
          // Add to companies list
          if (!companiesList.includes(companyId)) {
            companiesList.push(companyId);
          }
          
          // Add to roles map
          // Assuming role is stored as string matching the Security Rules expectation ('admin', etc.)
          // If stored as Enum index or otherwise, might need conversion.
          if (item.role) {
            // Convert to string just in case, or lowercase it?
            // Security rules expect: request.auth.token.roles[companyId] == 'admin'
            // We'll assume the data is correct or use generic string conversion.
            rolesMap[companyId] = String(item.role).toLowerCase();
          }
        }
      });
    }

    // Prepare claims
    // Note: Custom claims payload must be < 1000 bytes. 
    // If a user belongs to many companies, this might hit the limit.
    const claims = {
      companies: companiesList,
      roles: rolesMap,
      companyId: companiesList.length > 0 ? companiesList[0] : null // Legacy/Primary support if needed
    };

    console.log(`Updating claims for user ${userId}:`, JSON.stringify(claims));

    try {
      await admin.auth().setCustomUserClaims(userId, claims);
      console.log(`Claims updated successfully for ${userId}`);
    } catch (error) {
      console.error(`Error updating claims for ${userId}:`, error);
    }
  });
