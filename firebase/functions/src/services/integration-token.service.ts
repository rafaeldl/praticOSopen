import { randomBytes } from 'crypto';
import { db } from './firestore.service';
import { ApiKeyData, toDate } from '../models/types';

const HOSTING_ORIGIN = 'https://praticos.web.app';
const TOKEN_TTL_DAYS = 90;

export interface CreatedToken {
  id: string;
  token: string;
  url: string;
  expiresAt: string;
}

export interface TokenSummary {
  id: string;
  name: string;
  createdAt: string;
  lastUsedAt: string | null;
  expiresAt: string;
}

export async function createIntegrationToken(
  companyId: string,
  userId: string,
  name: string,
): Promise<CreatedToken> {
  const token = `mcp_${randomBytes(24).toString('hex')}`;
  const now = new Date();
  const expiresAt = new Date(now.getTime() + TOKEN_TTL_DAYS * 24 * 60 * 60 * 1000);

  const ref = await db.collection('apiKeys').add({
    key: token,
    companyId,
    userId,
    name,
    type: 'mcp',
    permissions: ['read:all', 'write:all'],
    active: true,
    createdAt: now,
    expiresAt,
  });

  return {
    id: ref.id,
    token,
    url: `${HOSTING_ORIGIN}/mcp/t/${token}`,
    expiresAt: expiresAt.toISOString(),
  };
}

export async function listIntegrationTokens(
  companyId: string,
): Promise<TokenSummary[]> {
  const snap = await db
    .collection('apiKeys')
    .where('companyId', '==', companyId)
    .where('type', '==', 'mcp')
    .orderBy('createdAt', 'desc')
    .get();

  return snap.docs
    .map((doc) => {
      const data = doc.data() as ApiKeyData;
      return { doc, data };
    })
    .filter(({ data }) => data.active)
    .map(({ doc, data }) => ({
      id: doc.id,
      name: data.name,
      createdAt: toDate(data.createdAt)?.toISOString() ?? '',
      lastUsedAt: toDate(data.lastUsedAt)?.toISOString() ?? null,
      expiresAt: toDate(data.expiresAt)?.toISOString() ?? '',
    }));
}

export async function revokeIntegrationToken(
  companyId: string,
  id: string,
): Promise<boolean> {
  const ref = db.collection('apiKeys').doc(id);
  const doc = await ref.get();

  if (!doc.exists) return false;

  const data = doc.data() as ApiKeyData;
  if (data.companyId !== companyId || data.type !== 'mcp') return false;

  await ref.update({ active: false });
  return true;
}
