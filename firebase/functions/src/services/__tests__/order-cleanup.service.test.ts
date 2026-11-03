jest.mock('../firestore.service', () => jest.requireActual('../../__tests__/helpers/fake-firestore').firestoreServiceMock);

import { fakeStorage, read, resetFakeDb, seed } from '../../__tests__/helpers/fake-firestore';
import { cleanupDeletedOrder } from '../order-cleanup.service';

const O1 = 'companies/c1/orders/o1';

describe('order-cleanup.service (OS apagada direto no Firestore)', () => {
  beforeEach(() => {
    resetFakeDb();
    seed(`${O1}/comments/cm1`, { text: 'oi' });
    seed(`${O1}/forms/f1`, { title: 'Checklist' });
    seed(`${O1}/forms/f1/items/i1`, { answer: 'ok' });
    seed(`${O1}/photos/p1`, { url: 'x' });
    seed(`${O1}/charges/ch1`, { value: 100 });
    seed('companies/c1/orders/o10/comments/cm1', { text: 'outra OS' });
    seed('companies/c2/orders/o1/comments/cm1', { text: 'outra empresa' });
  });

  it('apaga comentários, checklists, fotos e arquivos só da pasta da OS', async () => {
    await cleanupDeletedOrder('c1', 'o1');

    expect(read(`${O1}/comments/cm1`)).toBeUndefined();
    expect(read(`${O1}/forms/f1`)).toBeUndefined();
    expect(read(`${O1}/forms/f1/items/i1`)).toBeUndefined();
    expect(read(`${O1}/photos/p1`)).toBeUndefined();
    expect(fakeStorage.deletedPrefixes).toEqual(['tenants/c1/orders/o1/']);
    expect(fakeStorage.deleted).toEqual([]);
  });

  it('não toca em cobranças, em outra OS nem em outra empresa', async () => {
    await cleanupDeletedOrder('c1', 'o1');

    expect(read(`${O1}/charges/ch1`)).toEqual({ value: 100 });
    expect(read('companies/c1/orders/o10/comments/cm1')).toEqual({ text: 'outra OS' });
    expect(read('companies/c2/orders/o1/comments/cm1')).toEqual({ text: 'outra empresa' });
  });

  it('OS que voltou a existir (mesmo id) fica como está', async () => {
    seed(O1, { status: 'quote' });

    await cleanupDeletedOrder('c1', 'o1');

    expect(read(`${O1}/comments/cm1`)).toEqual({ text: 'oi' });
    expect(fakeStorage.deletedPrefixes).toEqual([]);
  });

  it.each([
    ['', 'o1'],
    ['c1', ''],
    ['c1', 'o1/../o2'],
    ['c1/x', 'o1'],
    ['c1', '..'],
  ])('ids inválidos (%p, %p) não apagam nada', async (companyId, orderId) => {
    await cleanupDeletedOrder(companyId, orderId);

    expect(read(`${O1}/comments/cm1`)).toEqual({ text: 'oi' });
    expect(fakeStorage.deletedPrefixes).toEqual([]);
  });
});
