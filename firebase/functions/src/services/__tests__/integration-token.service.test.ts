const mockAdd = jest.fn();
const mockGet = jest.fn();
const mockUpdate = jest.fn();
const mockDocGet = jest.fn();

jest.mock('../firestore.service', () => ({
  db: {
    collection: () => ({
      add: mockAdd,
      where: () => ({ where: () => ({ orderBy: () => ({ get: mockGet }) }) }),
      doc: () => ({ get: mockDocGet, update: mockUpdate }),
    }),
  },
}));

import {
  createIntegrationToken,
  listIntegrationTokens,
  revokeIntegrationToken,
} from '../integration-token.service';

describe('integration-token.service', () => {
  beforeEach(() => jest.clearAllMocks());

  it('gera token com prefixo mcp_ e URL do hosting', async () => {
    mockAdd.mockResolvedValue({ id: 'tok1' });

    const result = await createIntegrationToken('comp1', 'user1', 'Meu ChatGPT');

    expect(result.token).toMatch(/^mcp_[0-9a-f]{48}$/);
    expect(result.url).toBe(`https://praticos.web.app/mcp/t/${result.token}`);
    expect(result.id).toBe('tok1');
    expect(mockAdd).toHaveBeenCalledWith(
      expect.objectContaining({
        companyId: 'comp1',
        userId: 'user1',
        name: 'Meu ChatGPT',
        type: 'mcp',
        active: true,
      }),
    );
  });

  it('gera tokens diferentes a cada chamada', async () => {
    mockAdd.mockResolvedValue({ id: 'tok1' });
    const a = await createIntegrationToken('comp1', 'user1', 'A');
    const b = await createIntegrationToken('comp1', 'user1', 'B');
    expect(a.token).not.toBe(b.token);
  });

  it('lista datas ausentes como null, nunca string vazia', async () => {
    mockGet.mockResolvedValue({
      docs: [
        { id: 'tok1', data: () => ({ name: 'Sem datas', active: true }) },
        {
          id: 'tok2',
          data: () => ({
            name: 'Com datas',
            active: true,
            createdAt: { toDate: () => new Date('2026-09-12T10:00:00.000Z') },
            lastUsedAt: { toDate: () => new Date('2026-09-13T10:00:00.000Z') },
            expiresAt: { toDate: () => new Date('2026-12-11T10:00:00.000Z') },
          }),
        },
      ],
    });

    const tokens = await listIntegrationTokens('comp1');

    expect(tokens).toEqual([
      { id: 'tok1', name: 'Sem datas', createdAt: null, lastUsedAt: null, expiresAt: null },
      {
        id: 'tok2',
        name: 'Com datas',
        createdAt: '2026-09-12T10:00:00.000Z',
        lastUsedAt: '2026-09-13T10:00:00.000Z',
        expiresAt: '2026-12-11T10:00:00.000Z',
      },
    ]);
  });

  it('não revoga token de outra empresa', async () => {
    mockDocGet.mockResolvedValue({
      exists: true,
      data: () => ({ companyId: 'outra', type: 'mcp' }),
    });

    const ok = await revokeIntegrationToken('comp1', 'tok1');

    expect(ok).toBe(false);
    expect(mockUpdate).not.toHaveBeenCalled();
  });
});
