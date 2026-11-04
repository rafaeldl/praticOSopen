/**
 * Documents of an order (order.document.open): the files attached to the order
 * (nota, contrato, garantia, outro) go to everyone who reads the order, the
 * same people the Firestore rules let read it. Payment proofs (type receipt or
 * linked to a transaction) are money and go only to who sees values.
 */
import { projectOrder } from '../services/order-projection';
import type { Order } from '../models/types';

const doc = (id: string, extra: Record<string, unknown> = {}) => ({ id, url: `https://x/${id}`, storagePath: `tenants/c/orders/o/documents/${id}.pdf`, fileName: `${id}.pdf`, ...extra });

const order = {
  id: 'o',
  status: 'done',
  total: 100,
  documents: [
    doc('nota', { type: 'invoice' }),
    doc('garantia', { type: 'warranty' }),
    doc('sem-tipo'),
    doc('comprovante', { type: 'receipt' }),
    doc('prova', { type: 'other', linkedTransactionId: 'tx1' }),
  ],
} as unknown as Order;

const ids = (value: unknown) => ((value as { id: string }[] | undefined) ?? []).map((d) => d.id);

describe('documentos na projeção da OS', () => {
  it('quem vê valores recebe todos os documentos', () => {
    expect(ids(projectOrder(order, true).documents)).toEqual(['nota', 'garantia', 'sem-tipo', 'comprovante', 'prova'])
  });

  it('quem não vê valores recebe os documentos, sem comprovante de pagamento', () => {
    const projected = projectOrder(order, false);
    expect(ids(projected.documents)).toEqual(['nota', 'garantia', 'sem-tipo']);
    expect(projected.total).toBeUndefined();
  });

  it('OS sem documentos não manda o campo para quem não vê valores', () => {
    expect(projectOrder({ ...order, documents: [doc('c', { type: 'receipt' })] } as unknown as Order, false).documents).toBeUndefined();
  });
});
