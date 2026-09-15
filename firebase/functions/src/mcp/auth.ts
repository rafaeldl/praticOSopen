import { Response, NextFunction } from 'express';
import { db } from '../services/firestore.service';
import { resolveUserContext } from '../services/user-context.service';
import { AuthenticatedRequest, ApiKeyData, DateValue, toDate } from '../models/types';

/** At most one lastUsedAt write per token per hour. */
export const LAST_USED_WRITE_INTERVAL_MS = 60 * 60 * 1000;

// Per-instance guard against a burst of calls writing before the first write
// lands. The stored lastUsedAt is the cross-instance guard.
const lastUsedWrites = new Map<string, number>();

/** Test-only: clears the per-instance throttle. */
export function resetLastUsedThrottle(): void {
  lastUsedWrites.clear();
}

/**
 * Records that the token was used, fire-and-forget: never awaited, and a
 * failure is logged without affecting the request. Logs only the error —
 * never the token.
 */
function recordTokenUse(
  doc: FirebaseFirestore.QueryDocumentSnapshot,
  storedLastUsedAt: DateValue | undefined,
): void {
  try {
    const now = Date.now();
    const lastWrite = Math.max(
      toDate(storedLastUsedAt)?.getTime() ?? 0,
      lastUsedWrites.get(doc.id) ?? 0,
    );
    if (now - lastWrite < LAST_USED_WRITE_INTERVAL_MS) return;

    for (const [id, writtenAt] of lastUsedWrites) {
      if (now - writtenAt >= LAST_USED_WRITE_INTERVAL_MS) lastUsedWrites.delete(id);
    }
    lastUsedWrites.set(doc.id, now);

    doc.ref.update({ lastUsedAt: new Date(now) }).catch((error: unknown) => {
      console.error('mcpAuth lastUsedAt error:', error);
    });
  } catch (error) {
    console.error('mcpAuth lastUsedAt error:', error);
  }
}

/**
 * Resolves the MCP token carried in the request path into an auth context.
 *
 * The token travels in the URL because neither ChatGPT nor claude.ai allow a
 * custom header on a connector. This is a phase 1 bridge, replaced by OAuth.
 *
 * Populates both req.auth and req.userContext for use by downstream handlers.
 */
export async function mcpAuth(
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction,
): Promise<void> {
  const unauthorized = () => {
    res.status(401).json({
      jsonrpc: '2.0',
      error: { code: -32001, message: 'Invalid or expired connection token' },
      id: null,
    });
  };

  try {
    const token = req.params.token;
    if (!token) {
      unauthorized();
      return;
    }

    const snap = await db
      .collection('apiKeys')
      .where('key', '==', token)
      .limit(1)
      .get();

    if (snap.empty) {
      unauthorized();
      return;
    }

    const data = snap.docs[0].data() as ApiKeyData;

    if (!data.active) {
      unauthorized();
      return;
    }

    if (data.type !== 'mcp') {
      unauthorized();
      return;
    }

    const expiresAt = toDate(data.expiresAt);
    if (expiresAt && expiresAt < new Date()) {
      unauthorized();
      return;
    }

    req.auth = {
      type: 'mcp',
      companyId: data.companyId,
      userId: data.userId,
      permissions: data.permissions || [],
    };

    // Resolve user and company context for req.userContext. Any failure
    // answers the same 401, without revealing which check failed.
    const result = await resolveUserContext(data.userId!, data.companyId);

    if (!result.ok) {
      unauthorized();
      return;
    }

    req.userContext = result.context;

    recordTokenUse(snap.docs[0], data.lastUsedAt);

    next();
  } catch (error) {
    console.error('mcpAuth error:', error);
    res.status(500).json({
      jsonrpc: '2.0',
      error: { code: -32603, message: 'Authentication failed' },
      id: null,
    });
  }
}
