/**
 * Proof file of a payment: only a download URL of the project bucket. The
 * Storage emulator serves plain http on its own host; that URL is accepted only
 * inside the Functions emulator, and only for the emulator's host.
 */
import { validateReceiptFile } from '../payment-input';

const PREFIX = 'tenants/c1/orders/o1/';
const PATH = 'tenants/c1/orders/o1/payments/t1/receipt.jpg';
const encoded = encodeURIComponent(PATH);
const file = (url: string) => ({ url, storagePath: PATH, contentType: 'image/jpeg' });
const emulatorUrl = `http://127.0.0.1:9199/v0/b/praticos.appspot.com/o/${encoded}?alt=media&token=x`;

const saved = { ...process.env };
afterEach(() => {
  process.env = { ...saved };
});
beforeEach(() => {
  delete process.env.FIREBASE_CONFIG;
  delete process.env.STORAGE_BUCKET;
  delete process.env.FUNCTIONS_EMULATOR;
  delete process.env.FIREBASE_STORAGE_EMULATOR_HOST;
});

describe('validateReceiptFile', () => {
  it('accepts the https download URL of the same file in the project bucket', () => {
    expect(() => validateReceiptFile(PREFIX, file(`https://firebasestorage.googleapis.com/v0/b/praticos.appspot.com/o/${encoded}?alt=media`))).not.toThrow();
  });

  it('refuses the emulator URL in production, even with the emulator host set', () => {
    process.env.FIREBASE_STORAGE_EMULATOR_HOST = '127.0.0.1:9199';
    expect(() => validateReceiptFile(PREFIX, file(emulatorUrl))).toThrow('Invalid receipt file');
  });

  it('accepts the emulator URL inside the Functions emulator, for the emulator host only', () => {
    process.env.FUNCTIONS_EMULATOR = 'true';
    process.env.FIREBASE_STORAGE_EMULATOR_HOST = '127.0.0.1:9199';
    expect(() => validateReceiptFile(PREFIX, file(emulatorUrl))).not.toThrow();
    // Another host, another bucket or another path stay refused.
    expect(() => validateReceiptFile(PREFIX, file(emulatorUrl.replace('9199', '9200')))).toThrow('Invalid receipt file');
    expect(() => validateReceiptFile(PREFIX, file(emulatorUrl.replace('praticos.appspot.com', 'other.appspot.com')))).toThrow('Invalid receipt file');
    expect(() => validateReceiptFile(PREFIX, { ...file(emulatorUrl), storagePath: 'tenants/c1/orders/o2/payments/t1/receipt.jpg' })).toThrow('Invalid receipt file');
  });

  it('refuses plain http inside the emulator when no Storage emulator runs', () => {
    process.env.FUNCTIONS_EMULATOR = 'true';
    expect(() => validateReceiptFile(PREFIX, file(emulatorUrl))).toThrow('Invalid receipt file');
  });
});
