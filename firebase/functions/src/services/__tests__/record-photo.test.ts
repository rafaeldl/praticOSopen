/**
 * Photo of a record (catalog item, device) sent by the web app: only a file of
 * the record's own folder, by a download URL of the project bucket. The http
 * URL of the Storage emulator passes only inside the Functions emulator.
 */
jest.mock('../firestore.service', () => ({ storage: { bucket: () => ({ file: () => ({ delete: async () => undefined }) }) } }));

import { storagePathOfUrl, validPhotoIn } from '../record-photo';

const BUCKET = 'praticos.appspot.com';
const FOLDER = 'tenants/c1/devices/uno/';
const PATH = 'tenants/c1/devices/uno/photo.jpg';
const ENV = ['FUNCTIONS_EMULATOR', 'FIREBASE_STORAGE_EMULATOR_HOST', 'FIREBASE_CONFIG', 'STORAGE_BUCKET'] as const;
let saved: Record<string, string | undefined>;

beforeEach(() => {
  saved = Object.fromEntries(ENV.map((key) => [key, process.env[key]]));
  for (const key of ENV) delete process.env[key];
});
afterEach(() => {
  for (const key of ENV) {
    if (saved[key] === undefined) delete process.env[key];
    else process.env[key] = saved[key];
  }
});

describe('validPhotoIn', () => {
  test('aceita a URL firebasestorage e a forma storage.googleapis.com/{bucket}/… do mesmo arquivo', () => {
    expect(validPhotoIn(FOLDER, { storagePath: PATH, url: `https://firebasestorage.googleapis.com/v0/b/${BUCKET}/o/${encodeURIComponent(PATH)}?alt=media&token=t` })).toBe(true);
    expect(storagePathOfUrl(`https://storage.googleapis.com/${BUCKET}/${PATH}`)).toBe(PATH);
    expect(validPhotoIn(FOLDER, { storagePath: PATH, url: `https://storage.googleapis.com/${BUCKET}/${PATH}` })).toBe(true);
  });

  test('storage.googleapis.com de outro bucket ou de outro arquivo: recusada', () => {
    expect(validPhotoIn(FOLDER, { storagePath: PATH, url: `https://storage.googleapis.com/outro.appspot.com/${PATH}` })).toBe(false);
    expect(validPhotoIn(FOLDER, { storagePath: PATH, url: `https://storage.googleapis.com/${BUCKET}/tenants/c1/devices/gol/photo.jpg` })).toBe(false);
  });

  test('%2E%2E codificado na URL, com storagePath igual ao decodificado: recusada', () => {
    const escaped = 'tenants/c1/devices/uno/../../../c2/devices/x/photo.jpg';
    const url = `https://firebasestorage.googleapis.com/v0/b/${BUCKET}/o/${escaped.split('/').map((part) => (part === '..' ? '%2E%2E' : part)).join('%2F')}?alt=media`;
    expect(storagePathOfUrl(url)).toBe(escaped);
    expect(validPhotoIn(FOLDER, { storagePath: escaped, url })).toBe(false);
  });

  test('http do emulador do Storage: aceita só com o emulador de Functions ligado', () => {
    const url = `http://127.0.0.1:9199/v0/b/${BUCKET}/o/${encodeURIComponent(PATH)}?alt=media`;
    process.env.FIREBASE_STORAGE_EMULATOR_HOST = '127.0.0.1:9199';
    expect(validPhotoIn(FOLDER, { storagePath: PATH, url })).toBe(false);
    process.env.FUNCTIONS_EMULATOR = 'true';
    expect(validPhotoIn(FOLDER, { storagePath: PATH, url })).toBe(true);
    // Another host, even with the emulator on.
    expect(validPhotoIn(FOLDER, { storagePath: PATH, url: url.replace('127.0.0.1:9199', 'evil.test:9199') })).toBe(false);
    // Without the Storage emulator host, http never passes.
    delete process.env.FIREBASE_STORAGE_EMULATOR_HOST;
    expect(validPhotoIn(FOLDER, { storagePath: PATH, url })).toBe(false);
  });
});
