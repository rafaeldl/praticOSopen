jest.mock('../firestore.service', () => jest.requireActual('../../__tests__/helpers/fake-firestore').firestoreServiceMock);

import { read, resetFakeDb, seed } from '../../__tests__/helpers/fake-firestore';
import { countNewOrderPhotos, newPhotoCount, recountFormTemplates, recountUsers } from '../usage-counter.service';

const C1 = 'companies/c1';
const usage = () => (read(C1)?.subscription as { usage?: Record<string, number> } | undefined)?.usage;

describe('usage-counter.service (contadores do plano pelo servidor)', () => {
  beforeEach(() => {
    resetFakeDb();
    seed(C1, { name: 'Empresa', subscription: { plan: 'free', usage: { photosThisMonth: 2, formTemplatesActive: 9, usersActive: 9 } } });
  });

  it('com a flag desligada não recalcula os checklists (o app ainda grava)', async () => {
    seed(`${C1}/forms/f1`, { title: 'A', isActive: true });
    seed(`${C1}/forms/f2`, { title: 'B' });

    expect(await recountFormTemplates('c1')).toBeNull();
    expect(usage()?.formTemplatesActive).toBe(9);
  });

  it('conta os checklists ativos em forms (sem isActive conta como ativo)', async () => {
    seed('config/usageCounters', { serverOnly: true });
    seed(`${C1}/forms/f1`, { title: 'A', isActive: true });
    seed(`${C1}/forms/f2`, { title: 'B' });
    seed(`${C1}/forms/f3`, { title: 'C', isActive: false });
    seed('companies/c2/forms/f9', { title: 'Outra empresa', isActive: true });

    expect(await recountFormTemplates('c1')).toBe(2);
    expect(usage()).toEqual({ photosThisMonth: 2, formTemplatesActive: 2, usersActive: 9 });
  });

  it('conta membros mais convites pendentes que não venceram', async () => {
    seed(`${C1}/memberships/u1`, { role: 'owner' });
    seed(`${C1}/memberships/u2`, { role: 'technician' });
    const tokens = 'links/invites/tokens';
    seed(`${tokens}/INV_a`, { company: { id: 'c1' }, status: 'pending', expiresAt: '2099-01-01T00:00:00.000Z' });
    seed(`${tokens}/INV_b`, { company: { id: 'c1' }, status: 'pending' });
    seed(`${tokens}/INV_c`, { company: { id: 'c1' }, status: 'pending', expiresAt: '2020-01-01T00:00:00.000Z' });
    seed(`${tokens}/INV_d`, { company: { id: 'c1' }, status: 'accepted' });
    seed(`${tokens}/INV_e`, { company: { id: 'c2' }, status: 'pending' });

    expect(await recountUsers('c1', new Date('2026-11-03T00:00:00.000Z'))).toBe(4);
    expect(usage()?.usersActive).toBe(4);
  });

  it('empresa que não existe não é criada', async () => {
    seed('config/usageCounters', { serverOnly: true });
    seed('companies/ghost/forms/f1', { isActive: true });
    await recountFormTemplates('ghost');
    expect(read('companies/ghost')).toBeUndefined();
  });

  it('fotos novas: só as que não estavam antes', () => {
    expect(newPhotoCount(undefined, { photos: [{ id: 'p1' }, { id: 'p2' }] })).toBe(2);
    expect(newPhotoCount({ photos: [{ id: 'p1' }] }, { photos: [{ id: 'p1' }, { id: 'p2' }] })).toBe(1);
    expect(newPhotoCount({ photos: [{ id: 'p1' }, { id: 'p2' }] }, { photos: [{ id: 'p1' }] })).toBe(0);
    expect(newPhotoCount({ status: 'quote' }, { status: 'approved' })).toBe(0);
  });

  it('com a flag desligada não soma fotos (o app ainda soma)', async () => {
    expect(await countNewOrderPhotos('c1', undefined, { photos: [{ id: 'p1' }] })).toBe(0);
    expect(usage()?.photosThisMonth).toBe(2);
  });

  it('com a flag ligada soma as fotos novas da OS', async () => {
    seed('config/usageCounters', { serverOnly: true });
    const before = { photos: [{ id: 'p1' }] };
    const after = { photos: [{ id: 'p1' }, { id: 'p2' }, { id: 'p3' }] };
    expect(await countNewOrderPhotos('c1', before, after)).toBe(2);
    expect(usage()?.photosThisMonth).toBe(4);
  });
});
