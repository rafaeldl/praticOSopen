/**
 * Parse a Firestore field into a JavaScript Date.
 * Handles: Firestore Timestamp, ISO string, epoch ms/seconds, Date object, or null.
 */
export function parseFirestoreDate(value: any): Date | null {
  if (!value) return null

  // Firestore Timestamp (has toDate method)
  if (typeof value.toDate === 'function') {
    return value.toDate()
  }

  // Firestore Timestamp-like object with _seconds (admin SDK serialization)
  if (typeof value._seconds === 'number') {
    return new Date(value._seconds * 1000)
  }

  // Firestore Timestamp-like object with seconds (REST API format)
  if (typeof value.seconds === 'number') {
    return new Date(value.seconds * 1000)
  }

  // ISO string
  if (typeof value === 'string') {
    const d = new Date(value)
    return isNaN(d.getTime()) ? null : d
  }

  // Epoch milliseconds
  if (typeof value === 'number') {
    return new Date(value)
  }

  // Already a Date
  if (value instanceof Date) {
    return isNaN(value.getTime()) ? null : value
  }

  return null
}
