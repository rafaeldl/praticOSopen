/**
 * Mask Utilities
 * Functions for masking sensitive personal data (LGPD compliance)
 */

/**
 * Masks a person's name, showing only first name and first letter of last name
 * Example: "Rafael Duarte Lima" -> "Rafael D****"
 * Example: "Maria" -> "Maria"
 */
export function maskName(name: string | null | undefined): string | null {
  if (!name || typeof name !== 'string') return null;

  const trimmed = name.trim();
  if (!trimmed) return null;

  const parts = trimmed.split(/\s+/);
  if (parts.length === 1) {
    return parts[0];
  }

  const firstName = parts[0];
  const lastNameInitial = parts[parts.length - 1][0];
  return `${firstName} ${lastNameInitial}****`;
}

/**
 * Masks a phone number, showing only area code (DDD) and last 4 digits
 * Handles Brazilian phones with or without country code (+55)
 *
 * Examples:
 * - "+5548988264694" (13 digits) -> "(48) *****-4694"
 * - "5548988264694" (13 digits)  -> "(48) *****-4694"
 * - "48988264694" (11 digits)    -> "(48) *****-4694"
 * - "4832214694" (10 digits)     -> "(48) ****-4694"
 */
export function maskPhone(phone: string | null | undefined): string | null {
  if (!phone || typeof phone !== 'string') return null;

  // Remove all non-digits
  const digits = phone.replace(/\D/g, '');
  if (digits.length < 10) return null;

  let areaCode: string;
  let lastFour: string;

  // Handle Brazilian country code (55)
  if (digits.length >= 12 && digits.startsWith('55')) {
    // Format: 55 + DDD (2) + number (8-9)
    areaCode = digits.substring(2, 4);
  } else {
    // Format: DDD (2) + number (8-9)
    areaCode = digits.substring(0, 2);
  }

  lastFour = digits.substring(digits.length - 4);

  return `(${areaCode}) *****-${lastFour}`;
}

/**
 * Masks a serial number, preserving original length.
 * - Serials ≤6 chars: mask all except last character
 * - Serials >6 chars: show ~30% of characters (min 2), split start/end
 *
 * Examples:
 * - "AB3" (3) -> "**3"
 * - "ABC123" (6) -> "*****3"
 * - "ABCDEFGH" (8) -> "A******H"
 * - "1234567890" (10) -> "12*******0"
 * - "SN123456789XYZ" (14) -> "SN**********34"  (note: 14 chars → visible=4)
 * - "IMEI359876543210987" (19) -> "IME*************987"
 */
export function maskSerial(serial: string | null | undefined): string | null {
  if (!serial || typeof serial !== 'string') return null;

  const trimmed = serial.trim();
  if (!trimmed) return null;

  const len = trimmed.length;

  if (len === 1) return trimmed;

  if (len <= 6) {
    return '*'.repeat(len - 1) + trimmed[len - 1];
  }

  const visible = Math.max(2, Math.round(len * 0.3));
  const start = Math.ceil(visible / 2);
  const end = visible - start;

  const firstPart = trimmed.substring(0, start);
  const lastPart = trimmed.substring(len - end);
  const masked = '*'.repeat(len - visible);

  return `${firstPart}${masked}${lastPart}`;
}
