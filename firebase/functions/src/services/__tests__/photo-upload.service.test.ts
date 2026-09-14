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

import { uploadPhotoFromUrl } from '../photo-upload.service';

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
