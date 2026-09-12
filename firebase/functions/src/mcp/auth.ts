import { Response, NextFunction } from 'express';
import { db } from '../services/firestore.service';
import { AuthenticatedRequest, ApiKeyData, toDate, CompanyAggr } from '../models/types';
import { normalizeRole, getRolePermissions } from '../middleware/auth.middleware';

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

    // Resolve user and company context for req.userContext
    const { companyId, userId } = req.auth;

    // Get user info
    const userDoc = await db.collection('users').doc(userId!).get();

    if (!userDoc.exists) {
      unauthorized();
      return;
    }

    const userData = userDoc.data();

    // Get company info
    const companyDoc = await db.collection('companies').doc(companyId).get();

    if (!companyDoc.exists) {
      unauthorized();
      return;
    }

    const companyData = companyDoc.data();

    // Find user's role in this company
    const companies = userData?.companies || [];
    const companyRole = companies.find(
      (c: { company: CompanyAggr }) => c.company.id === companyId
    );

    if (!companyRole) {
      unauthorized();
      return;
    }

    const normalizedRole = normalizeRole(companyRole.role);

    req.userContext = {
      userId: userId!,
      userName: userData?.name || '',
      companyId: companyId,
      companyName: companyData?.name || '',
      role: normalizedRole,
      permissions: getRolePermissions(normalizedRole),
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
