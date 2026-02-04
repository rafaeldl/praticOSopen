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
 * Masks a phone number, showing only area code and last 4 digits
 * Example: "(11) 98765-7766" -> "(11) *****-7766"
 * Example: "11987657766" -> "(11) *****-7766"
 */
export function maskPhone(phone: string | null | undefined): string | null {
  if (!phone || typeof phone !== 'string') return null;

  // Remove all non-digits
  const digits = phone.replace(/\D/g, '');
  if (digits.length < 10) return null;

  // Extract area code and last 4 digits
  const areaCode = digits.substring(0, 2);
  const lastFour = digits.substring(digits.length - 4);

  return `(${areaCode}) *****-${lastFour}`;
}

/**
 * Masks a serial number, showing only first 3 and last 3 characters
 * Example: "SN123456789XYZ" -> "SN1******XYZ"
 */
export function maskSerial(serial: string | null | undefined): string | null {
  if (!serial || typeof serial !== 'string') return null;

  const trimmed = serial.trim();
  if (trimmed.length <= 6) return trimmed;

  const first3 = trimmed.substring(0, 3);
  const last3 = trimmed.substring(trimmed.length - 3);
  return `${first3}******${last3}`;
}
