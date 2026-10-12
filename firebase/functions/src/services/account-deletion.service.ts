/**
 * Account deletion ("Apagar minha conta") — docs/ACCOUNT_DELETION.md
 *
 * Runs on the server so the app makes one request instead of walking every
 * document. Rules:
 * - sole owner of a company → the company is deleted (Storage + Firestore tree);
 * - owner of a company with other members → blocked (nothing is deleted);
 * - member (not owner) → only leaves the company;
 * - then users/{uid} (recursive) and the Firebase Auth user are deleted.
 *
 * Every company is checked before anything is deleted, and each step is safe
 * to repeat, so a retry after a timeout finishes the job.
 * Logs carry only uid/companyId and counts.
 */

/** Max age of the sign-in (token `auth_time`) to accept a deletion. */
export const RECENT_LOGIN_MAX_AGE_SECONDS = 5 * 60;

export const COMPANY_HAS_MEMBERS_MESSAGE =
  'Você é o proprietário de uma empresa com outros membros. ' +
  'Transfira a propriedade ou remova os membros antes de excluir sua conta.';

export type AccountDeletionErrorCode = 'REQUIRES_RECENT_LOGIN' | 'COMPANY_HAS_MEMBERS';

export const ACCOUNT_DELETION_HTTP_STATUS: Record<AccountDeletionErrorCode, number> = {
  REQUIRES_RECENT_LOGIN: 401,
  COMPANY_HAS_MEMBERS: 409,
};

export class AccountDeletionError extends Error {
  constructor(
    public readonly code: AccountDeletionErrorCode,
    message: string,
    public readonly details?: Record<string, unknown>,
  ) {
    super(message);
    this.name = 'AccountDeletionError';
  }
}

export interface CompanyInfo {
  exists: boolean;
  ownerId: string | null;
}

/** Data access used by [deleteAccount]; production wiring in account-deletion.deps.ts. */
export interface AccountDeletionDeps {
  /** Company ids listed in users/{uid}.companies, or null when the doc is gone. */
  getUserCompanyIds(uid: string): Promise<string[] | null>;
  getCompany(companyId: string): Promise<CompanyInfo>;
  /** True when anyone other than [uid] is a member of the company. */
  hasOtherMembers(companyId: string, uid: string): Promise<boolean>;
  /** Deletes every Storage object under [prefix]. */
  deleteStoragePrefix(prefix: string): Promise<void>;
  /** Recursively deletes companies/{companyId} and all its subcollections. */
  deleteCompanyTree(companyId: string): Promise<void>;
  /** Removes [uid] from a company it does not own (membership doc and member map). */
  leaveCompany(companyId: string, uid: string): Promise<void>;
  /** Deletes channel links (WhatsApp) that point to [uid]. */
  deleteUserChannelLinks(uid: string): Promise<void>;
  /** Recursively deletes users/{uid}. */
  deleteUserTree(uid: string): Promise<void>;
  /** Deletes the Firebase Auth user; resolves false when it no longer exists. */
  deleteAuthUser(uid: string): Promise<boolean>;
}

export interface AccountDeletionResult {
  deletedCompanies: number;
  leftCompanies: number;
  authUserDeleted: boolean;
}

/**
 * Throws REQUIRES_RECENT_LOGIN unless the token's `auth_time` (seconds) is
 * within [RECENT_LOGIN_MAX_AGE_SECONDS] of [nowMs].
 */
export function assertRecentLogin(authTimeSeconds: unknown, nowMs: number): void {
  const ok =
    typeof authTimeSeconds === 'number' &&
    Number.isFinite(authTimeSeconds) &&
    nowMs / 1000 - authTimeSeconds <= RECENT_LOGIN_MAX_AGE_SECONDS;
  if (!ok) {
    throw new AccountDeletionError('REQUIRES_RECENT_LOGIN', 'Recent sign-in is required to delete the account');
  }
}

/** Storage prefixes that hold a company's files. */
export function companyStoragePrefixes(companyId: string): string[] {
  return [`tenants/${companyId}/`, `companies/${companyId}/`];
}

export async function deleteAccount(uid: string, deps: AccountDeletionDeps): Promise<AccountDeletionResult> {
  if (!uid) throw new Error('uid is required');

  const companyIds = Array.from(new Set((await deps.getUserCompanyIds(uid)) ?? []));

  // 1. Plan: check every company before deleting anything.
  const owned: string[] = [];
  const memberOf: string[] = [];
  const blocked: string[] = [];
  for (const companyId of companyIds) {
    const company = await deps.getCompany(companyId);
    if (!company.exists) continue; // already deleted (e.g. earlier partial run)
    if (company.ownerId === uid) {
      if (await deps.hasOtherMembers(companyId, uid)) {
        blocked.push(companyId);
      } else {
        owned.push(companyId);
      }
    } else {
      memberOf.push(companyId);
    }
  }

  if (blocked.length > 0) {
    console.warn(`[accountDeletion] uid=${uid} blocked companies=${blocked.join(',')}`);
    throw new AccountDeletionError('COMPANY_HAS_MEMBERS', COMPANY_HAS_MEMBERS_MESSAGE, { companyIds: blocked });
  }

  // 2. Owned companies: Storage first, then Firestore. The company doc goes
  //    last, so an interrupted run is retried with the owner check intact.
  for (const companyId of owned) {
    for (const prefix of companyStoragePrefixes(companyId)) {
      await deps.deleteStoragePrefix(prefix);
    }
    await deps.deleteCompanyTree(companyId);
    console.log(`[accountDeletion] uid=${uid} company=${companyId} deleted`);
  }

  // 3. Companies owned by someone else: just leave.
  for (const companyId of memberOf) {
    await deps.leaveCompany(companyId, uid);
    console.log(`[accountDeletion] uid=${uid} company=${companyId} left`);
  }

  // 4. User data, then the sign-in itself.
  await deps.deleteUserChannelLinks(uid);
  await deps.deleteUserTree(uid);
  const authUserDeleted = await deps.deleteAuthUser(uid);

  console.log(
    `[accountDeletion] uid=${uid} done deletedCompanies=${owned.length} leftCompanies=${memberOf.length} ` +
      `authUserDeleted=${authUserDeleted}`,
  );
  return { deletedCompanies: owned.length, leftCompanies: memberOf.length, authUserDeleted };
}
