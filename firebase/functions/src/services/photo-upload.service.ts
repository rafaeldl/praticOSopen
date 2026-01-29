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
