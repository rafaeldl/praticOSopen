import { Response, NextFunction } from 'express';
import { db } from '../services/firestore.service';
import { AuthenticatedRequest, ApiKeyData, toDate } from '../models/types';

/**
 * Resolves the MCP token carried in the request path into an auth context.
 *
 * The token travels in the URL because neither ChatGPT nor claude.ai allow a
 * custom header on a connector. This is a phase 1 bridge, replaced by OAuth.
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
      .where('active', '==', true)
      .limit(1)
      .get();

    if (snap.empty) {
      unauthorized();
      return;
    }

    const data = snap.docs[0].data() as ApiKeyData;

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
