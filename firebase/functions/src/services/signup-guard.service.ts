/**
 * Signup limit per IP (blockSuspiciousSignups in index.ts, issue #191).
 *
 * Up to SIGNUP_LIMIT_PER_IP new Auth users per IP in a SIGNUP_WINDOW_MS window,
 * counted in signupRateLimits/{ip}. The window starts at the first signup and
 * resets after it ends.
 *
 * Why 20 a day (was 5 in 10 minutes): mobile carriers put many phones behind one
 * IP (CGNAT), and a workshop signs its team in from the office Wi-Fi in a few
 * minutes (each invited person who signs in with Google is a new Auth user).
 * Five in ten minutes stopped the sixth person of a team. Twenty a day still
 * stops a script running from one machine. There is no e-mail rule: the old
 * `name.1234@gmail.com` pattern also refused real people (joao.1985@gmail.com).
 */

export const SIGNUP_LIMIT_PER_IP = 20;
export const SIGNUP_WINDOW_MS = 24 * 60 * 60 * 1000;

export interface SignupWindow {
  count: number;
  windowStart: number;
}

/** The next state of an IP's counter, or `blocked` when this signup is over the limit. */
export function nextSignupWindow(current: SignupWindow | undefined, now: number): { blocked: true } | { blocked: false; next: SignupWindow } {
  if (!current || now - current.windowStart > SIGNUP_WINDOW_MS) return { blocked: false, next: { count: 1, windowStart: now } };
  if (current.count >= SIGNUP_LIMIT_PER_IP) return { blocked: true };
  return { blocked: false, next: { count: current.count + 1, windowStart: current.windowStart } };
}

interface TxLike {
  get(ref: unknown): Promise<{ data(): unknown }>;
  set(ref: unknown, data: SignupWindow): unknown;
}
interface DbLike {
  collection(name: string): { doc(id: string): unknown };
  runTransaction<T>(fn: (tx: TxLike) => Promise<T>): Promise<T>;
}

/**
 * Counts this signup for `ip` and says whether it goes over the limit. No IP
 * (Auth did not send one) never blocks. A Firestore error propagates: the
 * caller lets the person in rather than refusing on our failure.
 */
export async function isSignupRateLimited(db: DbLike, ip: string, now: number = Date.now()): Promise<boolean> {
  if (!ip) return false;
  // An IPv6 address has ':' (fine in an id); '/' would make a path.
  const ref = db.collection('signupRateLimits').doc(ip.replace(/\//g, '_'));
  return db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const decision = nextSignupWindow((snap.data() as SignupWindow | undefined) ?? undefined, now);
    if (decision.blocked) return true;
    tx.set(ref, decision.next);
    return false;
  });
}

interface ConfigDbLike {
  collection(name: string): { doc(id: string): { get(): Promise<{ data(): unknown }> } };
}

/**
 * E-mails refused one by one: config/signup.blockedEmails (lower case). Set by
 * hand in the console to stop a specific abuser; no pattern, so a real
 * `joao.1985@gmail.com` is never caught by accident. Missing doc: nobody.
 */
export async function isEmailBlocked(db: ConfigDbLike, email: string): Promise<boolean> {
  const normalized = email.toLowerCase().trim();
  if (!normalized) return false;
  const snap = await db.collection('config').doc('signup').get();
  const list = (snap.data() as { blockedEmails?: unknown } | undefined)?.blockedEmails;
  return Array.isArray(list) && list.some((item) => typeof item === 'string' && item.toLowerCase().trim() === normalized);
}
