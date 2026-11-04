/**
 * Photo of one record (catalog item, device) sent by the web app: a file the
 * browser uploaded to the folder the Storage rules give to that record
 * (tenants/{company}/{collection}/{id}/), never a URL of another company, of
 * another record or outside the project bucket.
 */
import { storage } from './firestore.service';
import { projectBucket, isInsideFolder } from './payment-input';

export interface PhotoInput {
  url: string;
  storagePath: string;
}

/** Folder the Storage rules give to one record (the app writes photo.jpg there). */
export const recordPhotoFolder = (companyId: string, collection: string, id: string) => `tenants/${companyId}/${collection}/${id}/`;

/**
 * Path of a download URL of the project bucket. The Storage emulator serves
 * http on its own host; that form is accepted only while the emulator is on.
 */
export function storagePathOfUrl(raw: string): string | null {
  let url: URL;
  try {
    url = new URL(raw);
  } catch {
    return null;
  }
  const bucket = projectBucket();
  const emulator = process.env.FIREBASE_STORAGE_EMULATOR_HOST;
  let prefix: string | null = null;
  if (url.protocol === 'https:' && url.hostname === 'firebasestorage.googleapis.com') prefix = `/v0/b/${bucket}/o/`;
  else if (url.protocol === 'https:' && url.hostname === 'storage.googleapis.com') prefix = `/${bucket}/`;
  else if (emulator && url.protocol === 'http:' && url.host === emulator.replace(/^https?:\/\//, '')) prefix = `/v0/b/${bucket}/o/`;
  if (!prefix || !url.pathname.startsWith(prefix)) return null;
  try {
    return decodeURIComponent(url.pathname.slice(prefix.length));
  } catch {
    return null;
  }
}

/** The photo must be a file in [folder], and its URL that same file. */
export function validPhotoIn(folder: string, photo: PhotoInput): boolean {
  return isInsideFolder(folder, photo.storagePath) && storagePathOfUrl(photo.url) === photo.storagePath;
}

/**
 * Deletes only the file [storedUrl] points to, and only inside [folder]. A
 * file elsewhere (an old URL, another record) is never touched.
 */
export async function deletePhotoFileIn(folder: string, storedUrl: unknown, tag: string): Promise<void> {
  const path = typeof storedUrl === 'string' ? storagePathOfUrl(storedUrl) : null;
  if (!path || !isInsideFolder(folder, path)) return;
  try {
    await storage.bucket().file(path).delete();
  } catch (error) {
    console.warn(`${tag}: photo file not deleted`, (error as Error)?.name);
  }
}
