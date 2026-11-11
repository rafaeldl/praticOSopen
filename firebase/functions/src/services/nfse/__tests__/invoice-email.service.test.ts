jest.mock('../../firestore.service', () => jest.requireActual('../../../__tests__/helpers/fake-firestore').firestoreServiceMock);

import { read, resetFakeDb, seed } from '../../../__tests__/helpers/fake-firestore';
import { NfseServiceError } from '../errors';
import {
  buildEmailContent,
  displayName,
  EmailSendError,
  notifyInvoiceEmail,
  resendInvoiceEmail,
  sendInvoiceEmail,
  sendWithResend,
  type EmailDeps,
  type OutgoingEmail,
} from '../invoice-email.service';

// Synthetic company and customer. The provider is never called: `send` is fake.
const KEY = `42000002200000000000191${'1'.padStart(27, '0')}`;
const NOW = new Date('2026-11-05T13:00:00Z');
let sent: OutgoingEmail[];
let deps: Partial<EmailDeps>;

function seedNota(invoice: Record<string, unknown> = {}) {
  seed('companies/c1', { name: 'Oficina "Exemplo"', email: 'contato@example.com' });
  seed('companies/c1/customers/cu1', { name: 'Revenda Exemplo', email: 'cadastro@example.com', invoiceEmail: 'nota@example.com' });
  seed('companies/c1/invoices/nf1', {
    provider: 'direct',
    status: 'authorized',
    number: '29',
    value: 1234.5,
    accessKey: KEY,
    xmlPath: 'tenants/c1/invoices/nf1/nfse.xml',
    customer: { id: 'cu1', name: 'Revenda Exemplo' },
    recipient: { customerId: 'cu1', legalName: 'REVENDA EXEMPLO LTDA', email: 'antigo@example.com' },
    ...invoice,
  });
}

beforeEach(() => {
  resetFakeDb();
  seedNota();
  sent = [];
  deps = {
    now: () => NOW,
    send: async (email) => {
      sent.push(email);
      return { id: 'em_1' };
    },
    readFile: async (path) => Buffer.from(`file:${path}`),
    ensurePdf: async (companyId, invoiceId) => `tenants/${companyId}/invoices/${invoiceId}/danfse.pdf`,
  };
  jest.spyOn(console, 'log').mockImplementation(() => undefined);
  jest.spyOn(console, 'error').mockImplementation(() => undefined);
});

afterEach(() => jest.restoreAllMocks());

describe('sendInvoiceEmail', () => {
  it('issued: PDF and XML to the invoiceEmail, from notas@ with the company name, reply-to the company', async () => {
    const delivery = await sendInvoiceEmail('c1', 'nf1', 'issued', {}, deps);

    expect(delivery).toEqual({ status: 'sent', kind: 'issued', to: 'nota@example.com', at: NOW.toISOString(), manual: false, providerId: 'em_1' });
    expect(read('companies/c1/invoices/nf1')!.emailDelivery).toEqual(delivery);
    const [email] = sent;
    expect(email.from).toBe('"Oficina Exemplo" <notas@praticos.app>');
    expect(email.to).toBe('nota@example.com');
    expect(email.replyTo).toBe('contato@example.com');
    expect(email.subject).toBe('Nota fiscal nº 29 de Oficina Exemplo');
    expect(email.text).toContain('R$');
    expect(email.text).toContain(`https://www.nfse.gov.br/ConsultaPublica/?tpc=1&chave=${KEY}`);
    expect(email.attachments.map((a) => [a.filename, a.contentType])).toEqual([
      ['nota-29.pdf', 'application/pdf'],
      ['nota-29.xml', 'application/xml'],
    ]);
    expect(email.attachments[1].content.toString()).toBe('file:tenants/c1/invoices/nf1/nfse.xml');
    expect(email.idempotencyKey).toBe('nfse-c1-nf1-issued');
  });

  it('reply-to falls back to the owner e-mail when the company has none, and is left out when neither is valid', async () => {
    seed('companies/c1', { name: 'Oficina Exemplo', email: '', owner: { id: 'u1', name: 'Dono', email: 'dono@example.com' } });
    await sendInvoiceEmail('c1', 'nf1', 'issued', {}, deps);
    expect(sent[0].replyTo).toBe('dono@example.com');

    seed('companies/c1', { name: 'Oficina Exemplo', email: 'sem-arroba', owner: { id: 'u1', email: 'tambem-invalido' } });
    await sendInvoiceEmail('c1', 'nf1', 'issued', { manual: true }, deps);
    expect(sent[1].replyTo).toBeNull();
  });

  it('canceled: the notice with the PDF only (the watermarked one)', async () => {
    seedNota({ status: 'canceled' });
    await sendInvoiceEmail('c1', 'nf1', 'canceled', {}, deps);
    expect(sent[0].subject).toBe('Nota fiscal nº 29 de Oficina Exemplo foi cancelada');
    expect(sent[0].text).toContain('CANCELADA');
    expect(sent[0].attachments.map((a) => a.filename)).toEqual(['nota-29.pdf']);
  });

  it('falls back to the customer e-mail, then to the one the nota went with, then sends nothing', async () => {
    seed('companies/c1/customers/cu1', { name: 'Revenda Exemplo', email: 'cadastro@example.com' });
    expect((await sendInvoiceEmail('c1', 'nf1', 'issued', {}, deps))!.to).toBe('cadastro@example.com');
    seed('companies/c1/customers/cu1', { name: 'Revenda Exemplo' });
    expect((await sendInvoiceEmail('c1', 'nf1', 'issued', {}, deps))!.to).toBe('antigo@example.com');
    seedNota({ recipient: { customerId: 'cu1', legalName: 'REVENDA' } });
    seed('companies/c1/customers/cu1', { name: 'Revenda Exemplo' });
    const delivery = await sendInvoiceEmail('c1', 'nf1', 'issued', {}, deps);
    expect(delivery).toMatchObject({ status: 'skipped', reason: 'noEmail', to: null });
    expect(sent).toHaveLength(2);
  });

  it('turned off by the company: the automatic one is skipped, "Enviar de novo" still goes', async () => {
    seed('companies/c1/settings/nfse', { emailToCustomer: false });
    expect(await sendInvoiceEmail('c1', 'nf1', 'issued', {}, deps)).toMatchObject({ status: 'skipped', reason: 'turnedOff' });
    expect(sent).toHaveLength(0);
    expect(await sendInvoiceEmail('c1', 'nf1', 'issued', { manual: true }, deps)).toMatchObject({ status: 'sent', manual: true });
    expect(sent[0].idempotencyKey).toBe(`nfse-c1-nf1-issued-${NOW.toISOString()}`);
  });

  it('a provider failure is saved on the nota, never thrown', async () => {
    deps.send = async () => {
      throw new EmailSendError('EMAIL_REJECTED_422_VALIDATION_ERROR', 'no');
    };
    const delivery = await sendInvoiceEmail('c1', 'nf1', 'issued', {}, deps);
    expect(delivery).toMatchObject({ status: 'failed', to: 'nota@example.com', errorCode: 'EMAIL_REJECTED_422_VALIDATION_ERROR' });
    expect(read('companies/c1/invoices/nf1')!.emailDelivery).toMatchObject({ status: 'failed' });
  });

  it('the PDF could not be made: failed, nothing sent', async () => {
    deps.ensurePdf = async () => {
      throw new NfseServiceError('PDF_NOT_AVAILABLE', 'no');
    };
    expect(await sendInvoiceEmail('c1', 'nf1', 'issued', {}, deps)).toMatchObject({ status: 'failed', errorCode: 'PDF_NOT_AVAILABLE' });
    expect(sent).toHaveLength(0);
  });

  it('an address that is not an e-mail is not sent', async () => {
    seed('companies/c1/customers/cu1', { invoiceEmail: 'sem arroba' });
    expect(await sendInvoiceEmail('c1', 'nf1', 'issued', {}, deps)).toMatchObject({ status: 'failed', errorCode: 'INVALID_EMAIL' });
    expect(sent).toHaveLength(0);
  });

  it('only direct notas issued or canceled; the manual send says so', async () => {
    seedNota({ status: 'error' });
    expect(await sendInvoiceEmail('c1', 'nf1', 'issued', {}, deps)).toBeNull();
    await expect(sendInvoiceEmail('c1', 'nf1', 'issued', { manual: true }, deps)).rejects.toMatchObject({ code: 'EMAIL_NOT_AVAILABLE' });
    seedNota({ provider: 'asaas' });
    expect(await sendInvoiceEmail('c1', 'nf1', 'issued', {}, deps)).toBeNull();
    expect(sent).toHaveLength(0);
  });
});

describe('resendInvoiceEmail', () => {
  it('sends what fits the nota now', async () => {
    seedNota({ status: 'canceled' });
    expect(await resendInvoiceEmail('c1', 'nf1', deps)).toMatchObject({ status: 'sent', kind: 'canceled', manual: true });
    await expect(resendInvoiceEmail('c1', 'missing', deps)).rejects.toMatchObject({ code: 'INVOICE_NOT_FOUND' });
  });
});

describe('notifyInvoiceEmail', () => {
  it('never throws (no key in tests: the real sender refuses before any network call)', async () => {
    const fetchSpy = jest.spyOn(global, 'fetch');
    const delivery = await notifyInvoiceEmail('c1', 'nf1', 'issued');
    // The real PDF maker runs here and finds no XML in the fake Storage: failed, saved, not thrown.
    expect(delivery?.status).toBe('failed');
    expect(fetchSpy).not.toHaveBeenCalled();
  });
});

describe('sendWithResend', () => {
  it('refuses without a key, before calling the provider', async () => {
    const fetchSpy = jest.spyOn(global, 'fetch');
    await expect(sendWithResend({} as OutgoingEmail, '')).rejects.toMatchObject({ code: 'EMAIL_NOT_CONFIGURED' });
    expect(fetchSpy).not.toHaveBeenCalled();
  });

  it('posts the message with the idempotency key and maps a refusal to a code', async () => {
    const fetchSpy = jest
      .spyOn(global, 'fetch')
      .mockResolvedValueOnce(new Response(JSON.stringify({ id: 'em_9' }), { status: 200 }))
      .mockResolvedValueOnce(new Response(JSON.stringify({ name: 'validation_error', message: 'x' }), { status: 422 }));
    const email: OutgoingEmail = {
      from: '"Oficina" <notas@praticos.app>',
      to: 'nota@example.com',
      replyTo: null,
      subject: 's',
      text: 't',
      html: '<p>t</p>',
      attachments: [{ filename: 'nota-1.pdf', content: Buffer.from('pdf'), contentType: 'application/pdf' }],
      idempotencyKey: 'k1',
    };
    expect(await sendWithResend(email, 'test-key')).toEqual({ id: 'em_9' });
    const [url, init] = fetchSpy.mock.calls[0] as [string, RequestInit];
    expect(url).toBe('https://api.resend.com/emails');
    expect((init.headers as Record<string, string>)['Idempotency-Key']).toBe('k1');
    const body = JSON.parse(init.body as string);
    expect(body).toMatchObject({ to: ['nota@example.com'], attachments: [{ filename: 'nota-1.pdf', content: Buffer.from('pdf').toString('base64') }] });
    expect(body.reply_to).toBeUndefined();
    await expect(sendWithResend(email, 'test-key')).rejects.toMatchObject({ code: 'EMAIL_REJECTED_422_VALIDATION_ERROR' });
  });
});

describe('content', () => {
  it('escapes the company name in the HTML and in the From header', () => {
    expect(displayName('Ana <x@y>\r\nBcc: z')).toBe('Ana x@y Bcc: z');
    const content = buildEmailContent({ kind: 'issued', companyName: 'A&B <script>', number: null, value: 10, accessKey: null, customerName: null });
    expect(content.html).toContain('A&amp;B &lt;script&gt;');
    expect(content.subject).toBe('Nota fiscal de A&B <script>');
    expect(content.text).not.toContain('nfse.gov.br');
  });
});
