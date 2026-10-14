import {
  CompanyCatalog,
  LLM_RESPONSE_SCHEMA,
  OrderAssistDeps,
  OrderAssistError,
  buildSystemPrompt,
  buildUserText,
  matchCatalog,
  orderAssistInputSchema,
  parseLlmDraft,
  runOrderAssist,
  serialVariants,
  todayLabel,
} from '../order-assist.service';
import { LlmUnavailableError } from '../llm.client';

const CATALOG: CompanyCatalog = {
  services: [
    { id: 's1', name: 'Polimento', value: 450 },
    { id: 's2', name: 'Pintura de capô', value: 500 },
    { id: 's3', name: 'Higienização de split', value: 180 },
  ],
  products: [
    { id: 'p1', name: 'Para-choque dianteiro', value: 850 },
    { id: 'p2', name: 'Gás R410A', value: null },
  ],
};

const PHOTO = Buffer.from('fake-jpeg').toString('base64');

function deps(overrides: Partial<OrderAssistDeps> = {}, answer: unknown = {}): OrderAssistDeps & {
  llm: { generateJson: jest.Mock };
} {
  return {
    llm: { generateJson: jest.fn().mockResolvedValue(JSON.stringify(answer)) },
    getSettings: jest.fn().mockResolvedValue({ enabled: true }),
    reserve: jest.fn().mockResolvedValue({ ok: true, used: 3, limit: 10, monthKey: '2026-10' }),
    release: jest.fn().mockResolvedValue(undefined),
    loadCatalog: jest.fn().mockResolvedValue(CATALOG),
    findCustomers: jest.fn().mockResolvedValue([]),
    findDeviceBySerial: jest.fn().mockResolvedValue(null),
    findDevices: jest.fn().mockResolvedValue([]),
    ...overrides,
  } as OrderAssistDeps & { llm: { generateJson: jest.Mock } };
}

describe('orderAssistInputSchema', () => {
  it('accepts text, audio or photos', () => {
    expect(orderAssistInputSchema.safeParse({ text: 'capô 500' }).success).toBe(true);
    expect(orderAssistInputSchema.safeParse({ audio: { mimeType: 'audio/mp4', data: PHOTO } }).success).toBe(true);
    expect(orderAssistInputSchema.safeParse({ photos: [{ mimeType: 'image/jpeg', data: PHOTO }], locale: 'es' }).success).toBe(true);
  });

  it.each([
    [{}],
    [{ text: '   ' }],
    [{ text: 'x'.repeat(2001) }],
    [{ photos: [] }],
    [{ photos: [{ mimeType: 'image/gif', data: PHOTO }] }],
    [{ photos: [{ mimeType: 'image/jpeg', data: 'not base64!' }] }],
    [{ photos: Array(5).fill({ mimeType: 'image/jpeg', data: PHOTO }) }],
    [{ audio: { mimeType: 'video/mp4', data: PHOTO } }],
    [{ text: 'ok', companyId: 'other' }],
    [{ text: 'ok', locale: 'fr' }],
  ])('rejects %j', (body) => {
    expect(orderAssistInputSchema.safeParse(body).success).toBe(false);
  });

  it('rejects a photo bigger than 2 MB', () => {
    const big = Buffer.alloc(2 * 1024 * 1024 + 10).toString('base64');
    expect(orderAssistInputSchema.safeParse({ photos: [{ mimeType: 'image/jpeg', data: big }] }).success).toBe(false);
  });
});

describe('parseLlmDraft', () => {
  it('reads JSON inside ``` fences', () => {
    const draft = parseLlmDraft('```json\n{"items":[{"kind":"service","name":"Polimento","value":450}]}\n```');
    expect(draft.items).toEqual([{ kind: 'service', name: 'Polimento', value: 450 }]);
  });

  it('drops invalid items and keeps the valid ones', () => {
    const draft = parseLlmDraft(
      JSON.stringify({
        customer: { name: '  Ana  ', phone: null },
        items: [{ kind: 'service', name: '' }, { kind: 'weird', name: 'Capô' }, { name: 'X', value: -5 }, 'oops'],
        notes: '',
      }),
    );
    expect(draft.items).toEqual([{ kind: 'service', name: 'Capô' }]);
    expect(draft.customer).toEqual({ name: 'Ana', phone: undefined });
    expect(draft.notes).toBeUndefined();
  });

  it('reads the deadline and drops a malformed one', () => {
    expect(parseLlmDraft(JSON.stringify({ items: [], dueDate: '2026-10-16', dueTime: '17:30' }))).toMatchObject({
      dueDate: '2026-10-16',
      dueTime: '17:30',
    });
    const bad = parseLlmDraft(JSON.stringify({ items: [], dueDate: 'sexta', dueTime: '25:00', notes: 'Barulho' }));
    expect(bad.dueDate).toBeUndefined();
    expect(bad.dueTime).toBeUndefined();
    expect(bad.notes).toBe('Barulho');
  });

  it('keeps items when top-level fields are garbage', () => {
    const draft = parseLlmDraft(JSON.stringify({ customer: 'Ana', device: 3, items: [{ kind: 'product', name: 'Gás' }] }));
    expect(draft.items).toEqual([{ kind: 'product', name: 'Gás' }]);
    expect(draft.customer).toBeUndefined();
  });

  it('throws LlmUnavailableError on non-JSON or non-object', () => {
    expect(() => parseLlmDraft('Claro! Aqui está')).toThrow(LlmUnavailableError);
    expect(() => parseLlmDraft('[1,2]')).toThrow(LlmUnavailableError);
  });
});

describe('matchCatalog', () => {
  it('matches ignoring accents and case', () => {
    expect(matchCatalog('pintura de capo', CATALOG.services).match?.id).toBe('s2');
  });

  it('matches when one name contains the other', () => {
    expect(matchCatalog('para-choque', CATALOG.products).match?.id).toBe('p1');
  });

  it('returns null when nothing is close', () => {
    expect(matchCatalog('troca de óleo', CATALOG.services)).toEqual({ match: null, alternatives: [] });
  });
});

describe('serialVariants', () => {
  it('covers the formats a plate may be stored in', () => {
    expect(serialVariants('abc 1234')).toEqual(expect.arrayContaining(['ABC1234', 'ABC-1234']));
    expect(serialVariants('NXS8620')).toContain('NXS-8620');
    expect(serialVariants('BRA2E19')).toEqual(['BRA2E19']);
  });
});

describe('prompt', () => {
  it('asks for the app language and lists the catalog with prices', () => {
    expect(buildSystemPrompt('es')).toContain('Spanish');
    expect(buildSystemPrompt('pt', undefined, '2026-10-13 (Tuesday)')).toContain('Today is 2026-10-13 (Tuesday)');
    expect(todayLabel(new Date('2026-10-14T02:00:00Z'))).toBe('2026-10-13 (Tuesday)');
    const text = buildUserText({ text: 'capô 500' }, CATALOG);
    expect(text).toContain('- Polimento (450)');
    expect(text).toContain('- Gás R410A\n');
    expect(text).toContain('capô 500');
  });

  it('response schema requires items', () => {
    expect(LLM_RESPONSE_SCHEMA.required).toEqual(['items']);
  });
});

describe('runOrderAssist', () => {
  const answer = {
    transcript: 'Revenda Sul, capô 500 e polimento, placa NXS 8620',
    customer: { name: 'Revenda Sul' },
    device: { name: 'Classic', serial: 'nxs 8620', manufacturer: 'Chevrolet' },
    items: [
      { kind: 'service', name: 'pintura de capo', value: 500 },
      { kind: 'service', name: 'polimento' },
      { kind: 'product', name: 'Para-choque dianteiro', quantity: 2 },
      { kind: 'service', name: 'Alinhamento' },
    ],
    notes: 'Risco na porta',
    dueDate: '2026-10-16',
  };

  it('off by default: without settings it refuses before counting or calling the model', async () => {
    const d = deps({ getSettings: jest.fn().mockResolvedValue(null) });
    await expect(runOrderAssist('c1', { text: 'oi' }, d)).rejects.toMatchObject({ code: 'AI_DISABLED' });
    expect(d.reserve).not.toHaveBeenCalled();
    expect(d.llm.generateJson).not.toHaveBeenCalled();
  });

  it('quota exceeded → AI_QUOTA_EXCEEDED with used/limit, model not called', async () => {
    const d = deps({ reserve: jest.fn().mockResolvedValue({ ok: false, used: 10, limit: 10, monthKey: '2026-10' }) });
    const error = await runOrderAssist('c1', { text: 'oi' }, d).catch((e) => e);
    expect(error).toBeInstanceOf(OrderAssistError);
    expect(error.code).toBe('AI_QUOTA_EXCEEDED');
    expect(error.details).toEqual({ used: 10, limit: 10 });
    expect(d.llm.generateJson).not.toHaveBeenCalled();
  });

  it('builds the draft: catalog match, spoken value wins, catalog value fills, unknown stays without value', async () => {
    const d = deps(
      {
        findCustomers: jest.fn().mockResolvedValue([{ id: 'cu1', name: 'Revenda Sul' }, { id: 'cu2', name: 'Revenda Sul Filial' }]),
        findDeviceBySerial: jest.fn(async (_c: string, serial: string) =>
          serial === 'NXS-8620' ? { id: 'd1', name: 'Classic 1.0', serial: 'NXS-8620' } : null,
        ),
      },
      answer,
    );
    const draft = await runOrderAssist('c1', { text: 'x', photos: [{ mimeType: 'image/jpeg', data: PHOTO }] }, d);

    expect(draft.transcript).toBe(answer.transcript);
    expect(draft.customer?.match).toEqual({ id: 'cu1', name: 'Revenda Sul' });
    expect(draft.customer?.alternatives).toEqual([{ id: 'cu2', name: 'Revenda Sul Filial' }]);
    expect(draft.device?.match?.id).toBe('d1');
    expect(draft.device?.guess?.serial).toBe('NXS8620');
    expect(draft.items).toEqual([
      expect.objectContaining({ name: 'Pintura de capô', catalogId: 's2', value: 500, quantity: 1 }),
      expect.objectContaining({ name: 'Polimento', catalogId: 's1', value: 450 }),
      expect.objectContaining({ kind: 'product', catalogId: 'p1', value: 850, quantity: 2 }),
      expect.objectContaining({ name: 'Alinhamento', catalogId: null, value: null }),
    ]);
    expect(draft.notes).toBe('Risco na porta');
    expect(draft.dueDate).toBe('2026-10-16');
    expect(draft.usage).toEqual({ used: 3, limit: 10 });

    const request = d.llm.generateJson.mock.calls[0][0];
    expect(request.media).toEqual([{ mimeType: 'image/jpeg', data: PHOTO }]);
    expect(request.responseSchema).toBe(LLM_RESPONSE_SCHEMA);
  });

  it('never sends customer names to the model', async () => {
    const d = deps({ findCustomers: jest.fn().mockResolvedValue([{ id: 'cu9', name: 'Cliente Secreto' }]) }, answer);
    await runOrderAssist('c1', { text: 'x' }, d);
    const request = d.llm.generateJson.mock.calls[0][0];
    expect(JSON.stringify(request)).not.toContain('Cliente Secreto');
  });

  it('a plate that is not registered does not pick a device by name', async () => {
    const d = deps({ findDevices: jest.fn().mockResolvedValue([{ id: 'd2', name: 'Classic' }]) }, answer);
    const draft = await runOrderAssist('c1', { text: 'x' }, d);
    expect(draft.device?.match).toBeNull();
    expect(draft.device?.alternatives).toEqual([{ id: 'd2', name: 'Classic' }]);
  });

  it('tenant isolation: every lookup uses the companyId it was given', async () => {
    const d = deps({}, answer);
    await runOrderAssist('tenant-A', { text: 'x' }, d);
    for (const fn of [d.getSettings, d.reserve, d.loadCatalog, d.findCustomers, d.findDeviceBySerial, d.findDevices]) {
      for (const call of (fn as jest.Mock).mock.calls) expect(call[0]).toBe('tenant-A');
    }
  });

  it('model failure → AI_UNAVAILABLE and the request is given back', async () => {
    const d = deps();
    d.llm.generateJson.mockRejectedValue(new LlmUnavailableError('HTTP 500'));
    await expect(runOrderAssist('c1', { text: 'x' }, d)).rejects.toMatchObject({ code: 'AI_UNAVAILABLE' });
    expect(d.release).toHaveBeenCalledWith('c1', '2026-10');
  });

  it('model answering non-JSON → AI_UNAVAILABLE and released', async () => {
    const d = deps();
    d.llm.generateJson.mockResolvedValue('desculpe');
    await expect(runOrderAssist('c1', { text: 'x' }, d)).rejects.toMatchObject({ code: 'AI_UNAVAILABLE' });
    expect(d.release).toHaveBeenCalled();
  });
});
