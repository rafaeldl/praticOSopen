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

const mockLookup = jest.fn();
jest.mock('dns', () => ({
  promises: {
    lookup: (...args: unknown[]) => mockLookup(...args),
  },
}));

import { uploadPhotoFromUrl } from '../photo-upload.service';

const GIF_BYTES = new Uint8Array([0x47, 0x49, 0x46, 0x38, 0x39, 0x61, 0x01, 0x00, 0x01, 0x00]);

function imageResponse(bytes: Uint8Array, contentType: string | null) {
  return {
    ok: true,
    status: 200,
    headers: {
      get: (h: string) => (h === 'content-type' ? contentType : null),
    },
    arrayBuffer: async () => bytes.buffer,
  } as any;
}

function redirectResponse(location: string | null, status = 302) {
  return {
    ok: false,
    status,
    statusText: 'Found',
    headers: {
      get: (h: string) => (h === 'location' ? location : null),
    },
  } as any;
}

describe('photo-upload.service - uploadPhotoFromUrl', () => {
  const user = { id: 'u1', name: 'User Test' };
  const originalFetch = global.fetch;

  beforeEach(() => {
    jest.clearAllMocks();
    mockLookup.mockReset();
    mockLookup.mockResolvedValue([{ address: '93.184.216.34', family: 4 }]);
    mockSave.mockResolvedValue(undefined);
    mockMakePublic.mockResolvedValue(undefined);
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

  it('usa redirect manual ao chamar fetch', async () => {
    global.fetch = jest.fn().mockResolvedValue(imageResponse(GIF_BYTES, 'image/gif'));

    await uploadPhotoFromUrl('comp1', 'ord1', { url: 'https://example.com/a.gif' }, user);

    expect(global.fetch).toHaveBeenCalledWith(
      'https://example.com/a.gif',
      expect.objectContaining({ redirect: 'manual' }),
    );
  });

  describe('proteção contra SSRF', () => {
    it.each([
      'http://169.254.169.254/computeMetadata/v1/instance/service-accounts/default/token',
      'http://metadata.google.internal/computeMetadata/v1/',
      'http://127.0.0.1:8080/admin',
      'http://10.0.0.1/',
      'http://[::1]/',
      'http://localhost/',
    ])('rejeita destino interno %s sem fazer fetch', async (url) => {
      global.fetch = jest.fn();

      await expect(uploadPhotoFromUrl('comp1', 'ord1', { url }, user)).rejects.toThrow();
      expect(global.fetch).not.toHaveBeenCalled();
      expect(mockSave).not.toHaveBeenCalled();
    });

    it('rejeita hostname público que resolve para IP privado', async () => {
      mockLookup.mockResolvedValue([{ address: '192.168.0.10', family: 4 }]);
      global.fetch = jest.fn();

      await expect(
        uploadPhotoFromUrl('comp1', 'ord1', { url: 'https://rebind.example.com/x.jpg' }, user),
      ).rejects.toThrow('non-public address');
      expect(global.fetch).not.toHaveBeenCalled();
    });

    it('segue redirect para host público revalidando o destino', async () => {
      global.fetch = jest
        .fn()
        .mockResolvedValueOnce(redirectResponse('https://cdn.example.com/final.gif'))
        .mockResolvedValueOnce(imageResponse(GIF_BYTES, 'image/gif'));

      const photo = await uploadPhotoFromUrl('comp1', 'ord1', { url: 'https://example.com/start' }, user);

      expect(photo.url).toBeDefined();
      expect(global.fetch).toHaveBeenCalledTimes(2);
      expect(mockLookup).toHaveBeenCalledWith('cdn.example.com', expect.anything());
    });

    it('rejeita redirect para endereço de metadata', async () => {
      global.fetch = jest
        .fn()
        .mockResolvedValueOnce(redirectResponse('http://169.254.169.254/latest/meta-data/'));

      await expect(
        uploadPhotoFromUrl('comp1', 'ord1', { url: 'https://example.com/start' }, user),
      ).rejects.toThrow('non-public address');
      expect(global.fetch).toHaveBeenCalledTimes(1);
      expect(mockSave).not.toHaveBeenCalled();
    });

    it('rejeita redirect relativo para host que resolve para IP privado', async () => {
      mockLookup
        .mockResolvedValueOnce([{ address: '93.184.216.34', family: 4 }])
        .mockResolvedValueOnce([{ address: '10.0.0.8', family: 4 }]);
      global.fetch = jest
        .fn()
        .mockResolvedValueOnce(redirectResponse('//internal.example.com/secret'));

      await expect(
        uploadPhotoFromUrl('comp1', 'ord1', { url: 'https://example.com/start' }, user),
      ).rejects.toThrow('non-public address');
      expect(global.fetch).toHaveBeenCalledTimes(1);
    });

    it('rejeita excesso de redirects', async () => {
      global.fetch = jest.fn().mockResolvedValue(redirectResponse('https://example.com/loop'));

      await expect(
        uploadPhotoFromUrl('comp1', 'ord1', { url: 'https://example.com/loop' }, user),
      ).rejects.toThrow('Too many redirects');
      expect(global.fetch).toHaveBeenCalledTimes(4);
    });

    it('rejeita redirect sem Location', async () => {
      global.fetch = jest.fn().mockResolvedValue(redirectResponse(null));

      await expect(
        uploadPhotoFromUrl('comp1', 'ord1', { url: 'https://example.com/start' }, user),
      ).rejects.toThrow('Redirect without Location header');
    });
  });

  describe('validação de magic bytes', () => {
    it('rejeita conteúdo que não é imagem mesmo com content-type image/jpeg', async () => {
      const html = new TextEncoder().encode('<html><body>not an image</body></html>');
      global.fetch = jest.fn().mockResolvedValue(imageResponse(html, 'image/jpeg'));

      await expect(
        uploadPhotoFromUrl('comp1', 'ord1', { url: 'https://example.com/fake.jpg', mimeType: 'image/jpeg' }, user),
      ).rejects.toThrow('Invalid or unsupported image type');
      expect(mockSave).not.toHaveBeenCalled();
    });

    it('usa o tipo detectado nos bytes em vez do mime declarado', async () => {
      const pngBytes = new Uint8Array([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0x00]);
      global.fetch = jest.fn().mockResolvedValue(imageResponse(pngBytes, 'image/jpeg'));

      await uploadPhotoFromUrl('comp1', 'ord1', { url: 'https://example.com/x', mimeType: 'image/gif' }, user);

      expect(mockSave).toHaveBeenCalledWith(
        expect.any(Buffer),
        expect.objectContaining({
          metadata: expect.objectContaining({ contentType: 'image/png' }),
        }),
      );
    });

    it('aceita WebP pelos magic bytes', async () => {
      const webp = Buffer.concat([
        Buffer.from('RIFF'),
        Buffer.from([0x00, 0x00, 0x00, 0x00]),
        Buffer.from('WEBPVP8 '),
      ]);
      global.fetch = jest.fn().mockResolvedValue(imageResponse(new Uint8Array(webp), null));

      await uploadPhotoFromUrl('comp1', 'ord1', { url: 'https://example.com/x.webp' }, user);

      expect(mockSave).toHaveBeenCalledWith(
        expect.any(Buffer),
        expect.objectContaining({
          metadata: expect.objectContaining({ contentType: 'image/webp' }),
        }),
      );
    });
  });

  it('rejeita corpo maior que 10MB sem Content-Length (streaming)', async () => {
    const chunk = new Uint8Array(4 * 1024 * 1024);
    let reads = 0;
    const cancel = jest.fn().mockResolvedValue(undefined);
    global.fetch = jest.fn().mockResolvedValue({
      ok: true,
      status: 200,
      headers: { get: () => null },
      body: {
        getReader: () => ({
          read: async () => (reads++ < 5 ? { done: false, value: chunk } : { done: true }),
          cancel,
        }),
      },
    } as any);

    await expect(
      uploadPhotoFromUrl('comp1', 'ord1', { url: 'https://example.com/stream' }, user),
    ).rejects.toThrow('Image too large');
    expect(cancel).toHaveBeenCalled();
    expect(reads).toBe(3);
  });
});
