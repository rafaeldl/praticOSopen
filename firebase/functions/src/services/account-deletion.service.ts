/**
 * Account deletion ("Apagar minha conta") — docs/ACCOUNT_DELETION.md
 *
 * Runs on the server so the app makes one request instead of walking every
 * document. Rules:
 * - sole owner of a company → the company is deleted (Storage + Firestore tree);
 * - owner of a company with other members → blocked (nothing is deleted);
 * - `owner` field and server-only member map disagree → blocked (nothing is
 *   deleted), since admins can edit the `owner` field;
 * - member (not owner) → only leaves the company (if really a member);
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

export const OWNERSHIP_MISMATCH_MESSAGE =
  'Não foi possível confirmar quem é o proprietário de uma das suas empresas. ' +
  'Fale com o suporte do PraticOS para excluir sua conta.';

export type AccountDeletionErrorCode = 'REQUIRES_RECENT_LOGIN' | 'COMPANY_HAS_MEMBERS' | 'OWNERSHIP_MISMATCH';

export const ACCOUNT_DELETION_HTTP_STATUS: Record<AccountDeletionErrorCode, number> = {
  REQUIRES_RECENT_LOGIN: 401,
  COMPANY_HAS_MEMBERS: 409,
  OWNERSHIP_MISMATCH: 409,
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

/** Server-side view of one company, relative to the user being deleted. */
export interface CompanyInfo {
  exists: boolean;
  /** `companies/{id}.owner` (editable by company admins). */
  ownerId: string | null;
  /** `private/membership.members[uid]` (Admin SDK only), lowercase, or null. */
  privateRole: string | null;
  /** Another uid has role 'owner' in the private member map. */
  otherOwnerInPrivateMap: boolean;
  /** Anyone other than uid in memberships/*, the private map or `company.users`. */
  hasOtherMembers: boolean;
  /** uid is in memberships/* or the private member map. */
  isMember: boolean;
}

/** Data access used by [deleteAccount]; production wiring in account-deletion.deps.ts. */
export interface AccountDeletionDeps {
  /** Company ids listed in users/{uid}.companies, or null when the doc is gone. */
  getUserCompanyIds(uid: string): Promise<string[] | null>;
  /** Companies whose `owner` field points to uid (covers ones missing from users.companies). */
  getOwnedCompanyIds(uid: string): Promise<string[]>;
  getCompany(companyId: string, uid: string): Promise<CompanyInfo>;
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

/** Storage prefix of the user's photo inside a company. */
export function memberStoragePrefix(companyId: string, uid: string): string {
  return `tenants/${companyId}/users/${uid}/`;
}

export type CompanyDecision = 'delete' | 'leave' | 'skip' | 'blocked' | 'mismatch';

/**
 * Decides what to do with one company. Ownership needs both the `owner` field
 * (editable by admins) and the server-only member map to agree: the map must
 * not give uid another role nor name another owner. Companies created by the
 * app keep the owner out of the map (the client cannot write it and the
 * membership seed skips owners), so "no entry" is accepted for the owner.
 */
export function decideCompany(company: CompanyInfo, uid: string): CompanyDecision {
  if (!company.exists) return 'skip'; // already deleted (e.g. earlier partial run)
  const ownerField = company.ownerId === uid;
  const mapSaysOwner = company.privateRole === 'owner';
  if (ownerField) {
    if ((company.privateRole && !mapSaysOwner) || company.otherOwnerInPrivateMap) return 'mismatch';
    return company.hasOtherMembers ? 'blocked' : 'delete';
  }
  if (mapSaysOwner) return 'mismatch';
  // users.companies[] is user-writable: only leave companies uid really belongs to.
  return company.isMember ? 'leave' : 'skip';
}

export async function deleteAccount(uid: string, deps: AccountDeletionDeps): Promise<AccountDeletionResult> {
  if (!uid) throw new Error('uid is required');

  const [listed, ownedByField] = await Promise.all([deps.getUserCompanyIds(uid), deps.getOwnedCompanyIds(uid)]);
  const companyIds = Array.from(new Set([...(listed ?? []), ...ownedByField]));

  // 1. Plan: check every company before deleting anything.
  const owned: string[] = [];
  const memberOf: string[] = [];
  const blocked: string[] = [];
  const mismatched: string[] = [];
  for (const companyId of companyIds) {
    const decision = decideCompany(await deps.getCompany(companyId, uid), uid);
    if (decision === 'delete') owned.push(companyId);
    else if (decision === 'leave') memberOf.push(companyId);
    else if (decision === 'blocked') blocked.push(companyId);
    else if (decision === 'mismatch') mismatched.push(companyId);
  }

  if (mismatched.length > 0) {
    console.warn(`[accountDeletion] uid=${uid} ownership mismatch companies=${mismatched.join(',')}`);
    throw new AccountDeletionError('OWNERSHIP_MISMATCH', OWNERSHIP_MISMATCH_MESSAGE, { companyIds: mismatched });
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

  // 3. Companies owned by someone else: delete the user's photo there and leave.
  for (const companyId of memberOf) {
    await deps.deleteStoragePrefix(memberStoragePrefix(companyId, uid));
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
