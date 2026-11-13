import * as fs from 'fs';
import * as path from 'path';
import { FakeFirestore } from '../__tests__/helpers/fake-firestore';
import { SIGNUP_LIMIT_PER_IP, SIGNUP_WINDOW_MS, isSignupRateLimited, nextSignupWindow } from './signup-guard.service';

describe('signup guard', () => {
  test('no e-mail rule: name.year@gmail.com is a real person (joao.1985@gmail.com)', () => {
    const index = fs.readFileSync(path.join(__dirname, '..', 'index.ts'), 'utf8');
    const start = index.indexOf('export const blockSuspiciousSignups');
    const body = index.slice(start, index.indexOf('\n);\n', start));
    expect(start).toBeGreaterThan(-1);
    expect(body).not.toMatch(/gmail|BOT_EMAIL|\.test\(email\)/);
  });

  test('the limit is 20 a day per IP', () => {
    expect(SIGNUP_LIMIT_PER_IP).toBe(20);
    expect(SIGNUP_WINDOW_MS).toBe(24 * 60 * 60 * 1000);
  });

  test('a team signing in from the same office Wi-Fi gets in (the old limit stopped the 6th)', async () => {
    const db = new FakeFirestore();
    const now = Date.UTC(2026, 10, 13, 12);
    for (let i = 0; i < SIGNUP_LIMIT_PER_IP; i++) {
      await expect(isSignupRateLimited(db as any, '200.1.2.3', now + i * 1000)).resolves.toBe(false);
    }
    await expect(isSignupRateLimited(db as any, '200.1.2.3', now + 60_000)).resolves.toBe(true);
    // Another IP is not affected.
    await expect(isSignupRateLimited(db as any, '200.1.2.4', now + 60_000)).resolves.toBe(false);
  });

  test('the window resets after a day', async () => {
    const db = new FakeFirestore();
    const now = Date.UTC(2026, 10, 13, 12);
    for (let i = 0; i <= SIGNUP_LIMIT_PER_IP; i++) await isSignupRateLimited(db as any, '2804:14c::1', now);
    await expect(isSignupRateLimited(db as any, '2804:14c::1', now + SIGNUP_WINDOW_MS - 1)).resolves.toBe(true);
    await expect(isSignupRateLimited(db as any, '2804:14c::1', now + SIGNUP_WINDOW_MS + 1)).resolves.toBe(false);
  });

  test('without an IP nothing is counted or blocked', async () => {
    const db = new FakeFirestore();
    await expect(isSignupRateLimited(db as any, '')).resolves.toBe(false);
    expect(db.docs.size).toBe(0);
  });

  test('nextSignupWindow', () => {
    expect(nextSignupWindow(undefined, 10)).toEqual({ blocked: false, next: { count: 1, windowStart: 10 } });
    expect(nextSignupWindow({ count: 19, windowStart: 0 }, 10)).toEqual({ blocked: false, next: { count: 20, windowStart: 0 } });
    expect(nextSignupWindow({ count: 20, windowStart: 0 }, 10)).toEqual({ blocked: true });
  });
});
