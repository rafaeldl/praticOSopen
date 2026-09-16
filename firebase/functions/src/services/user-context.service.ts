/**
 * User Context Service
 * Resolves the user + company context of an authenticated user, shared by the
 * bearer branch of resolveCompanyContext and by mcpAuth so both stay in sync.
 */

import { db } from './firestore.service';
import { CompanyAggr, UserContext } from '../models/types';
import { getRolePermissions, normalizeRole } from '../middleware/auth.middleware';

export type UserContextFailure = 'user_not_found' | 'company_not_found' | 'no_access';

export type UserContextResult =
  | { ok: true; context: UserContext }
  | { ok: false; reason: UserContextFailure };

/**
 * Loads the user and the company and resolves the user's role in it.
 * Each caller maps a failure reason to its own response format.
 */
export async function resolveUserContext(
  userId: string,
  companyId: string,
): Promise<UserContextResult> {
  // Get user info
  const userDoc = await db.collection('users').doc(userId).get();

  if (!userDoc.exists) {
    return { ok: false, reason: 'user_not_found' };
  }

  const userData = userDoc.data();

  // Get company info
  const companyDoc = await db.collection('companies').doc(companyId).get();

  if (!companyDoc.exists) {
    return { ok: false, reason: 'company_not_found' };
  }

  const companyData = companyDoc.data();

  // Find user's role in this company
  const companies = userData?.companies || [];
  const companyRole = companies.find(
    (c: { company: CompanyAggr }) => c.company.id === companyId
  );

  if (!companyRole) {
    return { ok: false, reason: 'no_access' };
  }

  const normalizedRole = normalizeRole(companyRole.role);

  return {
    ok: true,
    context: {
      userId: userId,
      userName: userData?.name || '',
      companyId: companyId,
      companyName: companyData?.name || '',
      role: normalizedRole,
      permissions: getRolePermissions(normalizedRole),
    },
  };
}
