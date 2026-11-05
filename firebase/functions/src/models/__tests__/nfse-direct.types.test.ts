import { directAutoIssueOf, fiscalEmitterAggr, nfseProviderOf } from '../nfse-direct.types';

describe('directAutoIssueOf', () => {
  it.each(['never', 'selectedCustomers', 'allOrders'] as const)('keeps %s', (value) => {
    expect(directAutoIssueOf(value)).toBe(value);
  });

  it.each([undefined, null, '', 'manual', 'paid', 'completed', 'ALLORDERS', 1])(
    'reads %p (missing or an Asaas value) as never',
    (value) => {
      expect(directAutoIssueOf(value)).toBe('never');
    },
  );
});

describe('nfseProviderOf', () => {
  it('is direct only when the document says so', () => {
    expect(nfseProviderOf({ provider: 'direct' })).toBe('direct');
  });

  it.each([{}, { provider: 'asaas' }, { provider: 'other' }, null, undefined])(
    'treats %p as the Asaas engine (invoices before the direct one)',
    (doc) => {
      expect(nfseProviderOf(doc)).toBe('asaas');
    },
  );
});

describe('fiscalEmitterAggr', () => {
  it('keeps only what the invoice embeds', () => {
    const aggr = fiscalEmitterAggr({
      id: 'e1',
      taxId: '00000000000191',
      legalName: 'OFICINA EXEMPLO LTDA',
      regime: 'mei',
      ...({ dpsSeries: '10', certificate: { holderName: 'X' } } as object),
    });
    expect(aggr).toEqual({ id: 'e1', taxId: '00000000000191', legalName: 'OFICINA EXEMPLO LTDA', regime: 'mei' });
  });
});
