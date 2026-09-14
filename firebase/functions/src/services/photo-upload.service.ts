/**
 * Photo Upload Service
 * Handles photo uploads from base64 for bot integration
 */

// No uuid needed - using timestamp-based IDs like the Flutter app
import { storage } from './firestore.service';
import { UserAggr, OrderPhoto } from '../models/types';

// ============================================================================
// Configuration
// ============================================================================

const ALLOWED_MIME_TYPES = ['image/jpeg', 'image/png', 'image/webp', 'image/gif'];
const MAX_FILE_SIZE = 10 * 1024 * 1024; // 10MB

// ============================================================================
// Photo Upload Functions
// ============================================================================

export interface UploadFromBase64Input {
  base64: string;
  filename: string;
  description?: string;
}

export interface UploadFromBufferInput {
  buffer: Buffer;
  filename: string;
  mimeType: string;
  description?: string;
}

export interface UploadFromUrlInput {
  url: string;
  filename?: string;
  mimeType?: string;
  description?: string;
}

/**
 * Upload photo from base64
 */
export async function uploadPhotoFromBase64(
  companyId: string,
  orderId: string,
  input: UploadFromBase64Input,
  createdBy: UserAggr
): Promise<OrderPhoto> {
  // Parse base64 data
  let base64Data = input.base64;
  let mimeType = 'image/jpeg';

  // Check if it's a data URI
  if (base64Data.startsWith('data:')) {
    const matches = base64Data.match(/^data:([^;]+);base64,(.+)$/);
    if (matches) {
      mimeType = matches[1];
      base64Data = matches[2];
    }
  }

  // Decode base64
  const buffer = Buffer.from(base64Data, 'base64');

  // Validate content type
  if (!ALLOWED_MIME_TYPES.includes(mimeType)) {
    throw new Error(`Invalid image type: ${mimeType}. Allowed: ${ALLOWED_MIME_TYPES.join(', ')}`);
  }

  // Validate file size
  if (buffer.length > MAX_FILE_SIZE) {
    throw new Error(`Image too large. Maximum size: ${MAX_FILE_SIZE / (1024 * 1024)}MB`);
  }

  // Generate unique filename using timestamp-based ID like Flutter app
  const extension = getExtensionFromMimeType(mimeType) || getExtensionFromFilename(input.filename);
  const photoId = generatePhotoId();
  const filename = `${photoId}.${extension}`;

  // Upload to Storage
  const storagePath = `tenants/${companyId}/orders/${orderId}/photos/${filename}`;
  const bucket = storage.bucket();
  const file = bucket.file(storagePath);

  await file.save(buffer, {
    metadata: {
      contentType: mimeType,
      metadata: {
        orderId,
        uploadedBy: createdBy.id,
        description: input.description || '',
      },
    },
  });

  // Make the file publicly accessible
  await file.makePublic();

  // Get public URL
  const publicUrl = `https://storage.googleapis.com/${bucket.name}/${storagePath}`;

  return {
    id: photoId,
    url: publicUrl,
    storagePath,
    description: input.description,
    createdAt: new Date().toISOString(),
    createdBy,
  };
}

/**
 * Upload photo from buffer (for multipart uploads)
 */
export async function uploadPhotoFromBuffer(
  companyId: string,
  orderId: string,
  input: UploadFromBufferInput,
  createdBy: UserAggr
): Promise<OrderPhoto> {
  // Validate content type
  if (!ALLOWED_MIME_TYPES.includes(input.mimeType)) {
    throw new Error(`Invalid image type: ${input.mimeType}. Allowed: ${ALLOWED_MIME_TYPES.join(', ')}`);
  }

  // Validate file size
  if (input.buffer.length > MAX_FILE_SIZE) {
    throw new Error(`Image too large. Maximum size: ${MAX_FILE_SIZE / (1024 * 1024)}MB`);
  }

  // Generate unique filename
  const extension = getExtensionFromMimeType(input.mimeType) || getExtensionFromFilename(input.filename);
  const photoId = generatePhotoId();
  const filename = `${photoId}.${extension}`;

  // Upload to Storage
  const storagePath = `tenants/${companyId}/orders/${orderId}/photos/${filename}`;
  const bucket = storage.bucket();
  const file = bucket.file(storagePath);

  await file.save(input.buffer, {
    metadata: {
      contentType: input.mimeType,
      metadata: {
        orderId,
        uploadedBy: createdBy.id,
        description: input.description || '',
      },
    },
  });

  // Make the file publicly accessible
  await file.makePublic();

  // Get public URL
  const publicUrl = `https://storage.googleapis.com/${bucket.name}/${storagePath}`;

  return {
    id: photoId,
    url: publicUrl,
    storagePath,
    description: input.description,
    createdAt: new Date().toISOString(),
    createdBy,
  };
}

/**
 * Upload photo from an HTTP/HTTPS URL
 */
export async function uploadPhotoFromUrl(
  companyId: string,
  orderId: string,
  input: UploadFromUrlInput,
  createdBy: UserAggr
): Promise<OrderPhoto> {
  let parsedUrl: URL;
  try {
    parsedUrl = new URL(input.url);
  } catch {
    throw new Error(`Invalid URL: ${input.url}`);
  }

  if (parsedUrl.protocol !== 'http:' && parsedUrl.protocol !== 'https:') {
    throw new Error(`Invalid protocol: ${parsedUrl.protocol}. Only http: and https: are supported.`);
  }

  const response = await fetch(input.url, {
    signal: AbortSignal.timeout(15000),
  });

  if (!response.ok) {
    throw new Error(`Failed to download image from URL: ${response.status} ${response.statusText}`);
  }

  const contentLengthHeader = response.headers.get('content-length');
  if (contentLengthHeader) {
    const size = parseInt(contentLengthHeader, 10);
    if (!isNaN(size) && size > MAX_FILE_SIZE) {
      throw new Error(`Image too large. Maximum size: ${MAX_FILE_SIZE / (1024 * 1024)}MB`);
    }
  }

  const arrayBuffer = await response.arrayBuffer();
  const buffer = Buffer.from(arrayBuffer);

  if (buffer.length > MAX_FILE_SIZE) {
    throw new Error(`Image too large. Maximum size: ${MAX_FILE_SIZE / (1024 * 1024)}MB`);
  }
  if (buffer.length === 0) {
    throw new Error('Downloaded image is empty');
  }

  // Resolve MIME type
  let mimeType = input.mimeType?.split(';')[0]?.trim();
  if (!mimeType || !ALLOWED_MIME_TYPES.includes(mimeType)) {
    const headerContentType = response.headers.get('content-type')?.split(';')[0]?.trim();
    if (headerContentType && ALLOWED_MIME_TYPES.includes(headerContentType)) {
      mimeType = headerContentType;
    } else {
      const detected = detectMimeTypeFromBuffer(buffer);
      if (detected) {
        mimeType = detected;
      }
    }
  }

  if (!mimeType || !ALLOWED_MIME_TYPES.includes(mimeType)) {
    throw new Error(
      `Invalid or unsupported image type: ${mimeType || 'unknown'}. Allowed: ${ALLOWED_MIME_TYPES.join(', ')}`
    );
  }

  // Resolve filename
  let filename = input.filename;
  if (!filename) {
    const pathname = parsedUrl.pathname;
    const urlFilename = pathname.split('/').pop();
    if (urlFilename && urlFilename.includes('.')) {
      filename = urlFilename;
    } else {
      const ext = getExtensionFromMimeType(mimeType) || 'jpg';
      filename = `photo.${ext}`;
    }
  }

  return uploadPhotoFromBuffer(
    companyId,
    orderId,
    {
      buffer,
      filename,
      mimeType,
      description: input.description,
    },
    createdBy
  );
}

/**
 * Delete photo from storage
 */
export async function deletePhoto(storagePath: string): Promise<void> {
  const bucket = storage.bucket();
  const file = bucket.file(storagePath);

  try {
    await file.delete();
  } catch (error) {
    // Ignore if file doesn't exist
    console.warn(`Failed to delete photo at ${storagePath}:`, error);
  }
}

import { Readable } from 'stream';

export interface PhotoStreamResult {
  stream: Readable;
  contentType: string;
}

/**
 * Get photo stream for direct download
 * Works with both production and emulator (no signed URL needed)
 */
export async function getPhotoStream(storagePath: string): Promise<PhotoStreamResult> {
  const bucket = storage.bucket();
  const file = bucket.file(storagePath);

  const [metadata] = await file.getMetadata();
  const stream = file.createReadStream();

  return {
    stream,
    contentType: (metadata.contentType as string) || 'image/jpeg',
  };
}

// ============================================================================
// Helper Functions
// ============================================================================

/**
 * Generate photo ID using timestamp-based format like Flutter app
 * Format: {millisecondsSinceEpoch}-{microseconds % 1000000}
 */
function generatePhotoId(): string {
  const now = Date.now();
  const hrTime = process.hrtime();
  const micro = (hrTime[0] * 1000000 + Math.floor(hrTime[1] / 1000)) % 1000000;
  return `${now}-${micro}`;
}

function getExtensionFromMimeType(mimeType: string): string {
  const mimeToExt: Record<string, string> = {
    'image/jpeg': 'jpg',
    'image/png': 'png',
    'image/webp': 'webp',
    'image/gif': 'gif',
  };
  return mimeToExt[mimeType.split(';')[0]] || 'jpg';
}

function getExtensionFromFilename(filename: string): string {
  const parts = filename.split('.');
  if (parts.length > 1) {
    return parts.pop()?.toLowerCase() || 'jpg';
  }
  return 'jpg';
}

function detectMimeTypeFromBuffer(buffer: Buffer): string | null {
  if (buffer.length >= 3 && buffer[0] === 0xff && buffer[1] === 0xd8 && buffer[2] === 0xff) {
    return 'image/jpeg';
  }
  if (
    buffer.length >= 8 &&
    buffer[0] === 0x89 &&
    buffer[1] === 0x50 &&
    buffer[2] === 0x4e &&
    buffer[3] === 0x47 &&
    buffer[4] === 0x0d &&
    buffer[5] === 0x0a &&
    buffer[6] === 0x1a &&
    buffer[7] === 0x0a
  ) {
    return 'image/png';
  }
  if (
    buffer.length >= 6 &&
    buffer[0] === 0x47 &&
    buffer[1] === 0x49 &&
    buffer[2] === 0x46 &&
    buffer[3] === 0x38 &&
    (buffer[4] === 0x37 || buffer[4] === 0x39) &&
    buffer[5] === 0x61
  ) {
    return 'image/gif';
  }
  if (
    buffer.length >= 12 &&
    buffer.subarray(0, 4).toString() === 'RIFF' &&
    buffer.subarray(8, 12).toString() === 'WEBP'
  ) {
    return 'image/webp';
  }
  return null;
}

