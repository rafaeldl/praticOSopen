const mockSave = jest.fn();
const mockMakePublic = jest.fn();
const mockFile = jest.fn(() => ({
  save: mockSave,
  makePublic: mockMakePublic,
}));
const mockBucket = jest.fn(() => ({
  name: 'test-bucket',
  file: mockFile,
}));

jest.mock('../firestore.service', () => ({
  storage: {
    bucket: mockBucket,
  },
}));

import {
  uploadPhotoFromBase64,
  uploadPhotoFromBuffer,
  uploadPhotoFromUrl,
} from '../photo-upload.service';

describe('photo-upload.service - uploadPhotoFromUrl', () => {
  const user = { id: 'u1', name: 'User Test' };
  const originalFetch = global.fetch;

  beforeEach(() => {
    jest.clearAllMocks();
  });

  afterEach(() => {
    global.fetch = originalFetch;
  });

  it('baixa imagem com sucesso e salva no Storage', async () => {
    // 1x1 GIF
    const gifBytes = new Uint8Array([0x47, 0x49, 0x46, 0x38, 0x39, 0x61, 0x01, 0x00, 0x01, 0x00]);
    global.fetch = jest.fn().mockResolvedValue({
      ok: true,
      headers: {
        get: (h: string) => (h === 'content-type' ? 'image/gif' : null),
      },
      arrayBuffer: async () => gifBytes.buffer,
    } as any);

    mockSave.mockResolvedValue(undefined);
    mockMakePublic.mockResolvedValue(undefined);

    const photo = await uploadPhotoFromUrl(
      'comp1',
      'ord1',
      {
        url: 'https://example.com/images/sample.gif',
        description: 'Foto do teste',
      },
      user,
    );

    expect(photo.url).toContain('https://storage.googleapis.com/test-bucket/tenants/comp1/orders/ord1/photos/');
    expect(photo.storagePath).toContain('tenants/comp1/orders/ord1/photos/');
    expect(photo.description).toBe('Foto do teste');
    expect(mockSave).toHaveBeenCalledWith(
      expect.any(Buffer),
      expect.objectContaining({
        metadata: expect.objectContaining({
          contentType: 'image/gif',
          metadata: expect.objectContaining({
            orderId: 'ord1',
            uploadedBy: 'u1',
          }),
        }),
      }),
    );
    expect(mockMakePublic).toHaveBeenCalled();
  });

  it('detecta tipo de imagem via magic bytes quando header for genérico', async () => {
    // JPEG header: FF D8 FF
    const jpegBytes = new Uint8Array([0xff, 0xd8, 0xff, 0xe0, 0x00, 0x10]);
    global.fetch = jest.fn().mockResolvedValue({
      ok: true,
      headers: {
        get: (h: string) => (h === 'content-type' ? 'application/octet-stream' : null),
      },
      arrayBuffer: async () => jpegBytes.buffer,
    } as any);

    mockSave.mockResolvedValue(undefined);
    mockMakePublic.mockResolvedValue(undefined);

    const photo = await uploadPhotoFromUrl(
      'comp1',
      'ord1',
      {
        url: 'https://example.com/download?id=123',
      },
      user,
    );

    expect(photo.url).toBeDefined();
    expect(mockSave).toHaveBeenCalledWith(
      expect.any(Buffer),
      expect.objectContaining({
        metadata: expect.objectContaining({
          contentType: 'image/jpeg',
        }),
      }),
    );
  });

  it('rejeita protocolo que não seja http ou https', async () => {
    await expect(
      uploadPhotoFromUrl('comp1', 'ord1', { url: 'ftp://example.com/img.jpg' }, user),
    ).rejects.toThrow('Invalid protocol: ftp:');
  });

  it('rejeita URL malformatada', async () => {
    await expect(
      uploadPhotoFromUrl('comp1', 'ord1', { url: 'not-a-url' }, user),
    ).rejects.toThrow('Invalid URL: not-a-url');
  });

  it('rejeita quando fetch retorna status de erro HTTP', async () => {
    global.fetch = jest.fn().mockResolvedValue({
      ok: false,
      status: 404,
      statusText: 'Not Found',
    } as any);

    await expect(
      uploadPhotoFromUrl('comp1', 'ord1', { url: 'https://example.com/404.jpg' }, user),
    ).rejects.toThrow('Failed to download image from URL: 404 Not Found');
  });

  it('rejeita tipo MIME não permitido (ex: PDF)', async () => {
    const pdfBytes = Buffer.from('%PDF-1.4');
    global.fetch = jest.fn().mockResolvedValue({
      ok: true,
      headers: {
        get: (h: string) => (h === 'content-type' ? 'application/pdf' : null),
      },
      arrayBuffer: async () => pdfBytes.buffer,
    } as any);

    await expect(
      uploadPhotoFromUrl('comp1', 'ord1', { url: 'https://example.com/doc.pdf' }, user),
    ).rejects.toThrow('Invalid or unsupported image type');
  });

  it('rejeita imagem maior que 10MB via Content-Length', async () => {
    global.fetch = jest.fn().mockResolvedValue({
      ok: true,
      headers: {
        get: (h: string) => (h === 'content-length' ? '15000000' : null),
      },
    } as any);

    await expect(
      uploadPhotoFromUrl('comp1', 'ord1', { url: 'https://example.com/huge.jpg' }, user),
    ).rejects.toThrow('Image too large. Maximum size: 10MB');
  });
});

const JPEG_BYTES = Buffer.from([0xff, 0xd8, 0xff, 0xe0, 0x00, 0x10]);
const PNG_BYTES = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0x00]);
const WEBP_BYTES = Buffer.concat([Buffer.from('RIFF'), Buffer.alloc(4), Buffer.from('WEBP')]);
// Content that an attacker would try to exfiltrate as a "photo".
const SECRET_BYTES = Buffer.from('{"type":"service_account","private_key":"-----BEGIN PRIVATE KEY-----"}');
const ENVIRON_BYTES = Buffer.from('PATH=/usr/bin\0GOOGLE_APPLICATION_CREDENTIALS=/secrets/sa.json\0');

describe('photo-upload.service - uploadPhotoFromBase64', () => {
  const user = { id: 'u1', name: 'User Test' };

  beforeEach(() => {
    jest.clearAllMocks();
    mockSave.mockResolvedValue(undefined);
    mockMakePublic.mockResolvedValue(undefined);
  });

  it('aceita JPEG em base64 puro e salva como image/jpeg', async () => {
    const photo = await uploadPhotoFromBase64(
      'comp1',
      'ord1',
      { base64: JPEG_BYTES.toString('base64'), filename: 'foto.jpg' },
      user,
    );

    expect(photo.storagePath).toMatch(/^tenants\/comp1\/orders\/ord1\/photos\/.+\.jpg$/);
    expect(mockSave).toHaveBeenCalledWith(
      expect.any(Buffer),
      expect.objectContaining({ metadata: expect.objectContaining({ contentType: 'image/jpeg' }) }),
    );
    expect(mockMakePublic).toHaveBeenCalled();
  });

  it('usa o tipo detectado nos bytes, não o declarado no data URI', async () => {
    await uploadPhotoFromBase64(
      'comp1',
      'ord1',
      { base64: `data:image/jpeg;base64,${PNG_BYTES.toString('base64')}`, filename: 'foto.jpg' },
      user,
    );

    expect(mockSave).toHaveBeenCalledWith(
      expect.any(Buffer),
      expect.objectContaining({ metadata: expect.objectContaining({ contentType: 'image/png' }) }),
    );
    expect(mockFile).toHaveBeenCalledWith(expect.stringMatching(/\.png$/));
  });

  it.each([
    ['credenciais de service account', SECRET_BYTES],
    ['/proc/self/environ', ENVIRON_BYTES],
    ['PDF', Buffer.from('%PDF-1.4')],
  ])('rejeita conteúdo não-imagem em base64 puro (%s)', async (_label, bytes) => {
    await expect(
      uploadPhotoFromBase64('comp1', 'ord1', { base64: bytes.toString('base64'), filename: 'foto.jpg' }, user),
    ).rejects.toThrow('Invalid or unsupported image type: image/jpeg');

    expect(mockSave).not.toHaveBeenCalled();
    expect(mockMakePublic).not.toHaveBeenCalled();
  });

  it('rejeita data URI que declara image/png mas contém texto', async () => {
    await expect(
      uploadPhotoFromBase64(
        'comp1',
        'ord1',
        { base64: `data:image/png;base64,${SECRET_BYTES.toString('base64')}`, filename: 'x.png' },
        user,
      ),
    ).rejects.toThrow('Invalid or unsupported image type: image/png');
    expect(mockSave).not.toHaveBeenCalled();
  });

  it('rejeita base64 vazio', async () => {
    await expect(
      uploadPhotoFromBase64('comp1', 'ord1', { base64: '', filename: 'foto.jpg' }, user),
    ).rejects.toThrow('Invalid or unsupported image type');
    expect(mockSave).not.toHaveBeenCalled();
  });

  it('rejeita imagem maior que 10MB', async () => {
    const huge = Buffer.concat([JPEG_BYTES, Buffer.alloc(10 * 1024 * 1024)]);
    await expect(
      uploadPhotoFromBase64('comp1', 'ord1', { base64: huge.toString('base64'), filename: 'foto.jpg' }, user),
    ).rejects.toThrow('Image too large. Maximum size: 10MB');
    expect(mockSave).not.toHaveBeenCalled();
  });
});

describe('photo-upload.service - uploadPhotoFromBuffer', () => {
  const user = { id: 'u1', name: 'User Test' };

  beforeEach(() => {
    jest.clearAllMocks();
    mockSave.mockResolvedValue(undefined);
    mockMakePublic.mockResolvedValue(undefined);
  });

  it('aceita WebP e salva com o tipo detectado', async () => {
    await uploadPhotoFromBuffer(
      'comp1',
      'ord1',
      { buffer: WEBP_BYTES, filename: 'foto.webp', mimeType: 'image/webp' },
      user,
    );

    expect(mockSave).toHaveBeenCalledWith(
      WEBP_BYTES,
      expect.objectContaining({ metadata: expect.objectContaining({ contentType: 'image/webp' }) }),
    );
    expect(mockMakePublic).toHaveBeenCalled();
  });

  it('rejeita buffer não-imagem mesmo com mimeType de imagem declarado', async () => {
    await expect(
      uploadPhotoFromBuffer(
        'comp1',
        'ord1',
        { buffer: SECRET_BYTES, filename: 'foto.jpg', mimeType: 'image/jpeg' },
        user,
      ),
    ).rejects.toThrow('Invalid or unsupported image type: image/jpeg');

    expect(mockSave).not.toHaveBeenCalled();
    expect(mockMakePublic).not.toHaveBeenCalled();
  });

  it('rejeita buffer vazio', async () => {
    await expect(
      uploadPhotoFromBuffer(
        'comp1',
        'ord1',
        { buffer: Buffer.alloc(0), filename: 'foto.jpg', mimeType: 'image/jpeg' },
        user,
      ),
    ).rejects.toThrow('Invalid or unsupported image type');
    expect(mockSave).not.toHaveBeenCalled();
  });
});

describe('photo-upload.service - uploadPhotoFromUrl (magic bytes)', () => {
  const user = { id: 'u1', name: 'User Test' };
  const originalFetch = global.fetch;

  afterEach(() => {
    global.fetch = originalFetch;
  });

  it('rejeita resposta com Content-Type de imagem mas corpo não-imagem', async () => {
    jest.clearAllMocks();
    global.fetch = jest.fn().mockResolvedValue({
      ok: true,
      headers: { get: (h: string) => (h === 'content-type' ? 'image/jpeg' : null) },
      arrayBuffer: async () => new Uint8Array(SECRET_BYTES).buffer,
    } as any);

    await expect(
      uploadPhotoFromUrl('comp1', 'ord1', { url: 'https://example.com/foto.jpg' }, user),
    ).rejects.toThrow('Invalid or unsupported image type');
    expect(mockSave).not.toHaveBeenCalled();
  });
});
