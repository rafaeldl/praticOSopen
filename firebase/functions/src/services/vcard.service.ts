/**
 * vCard Service
 * Generates vCard format for customer contacts
 */

import { Customer, CustomerAggr } from '../models/types';

/**
 * Generate vCard string from customer data
 */
export function generateVCard(customer: Customer | CustomerAggr & { address?: string }): string {
  const lines = [
    'BEGIN:VCARD',
    'VERSION:3.0',
  ];

  // Full name
  if (customer.name) {
    lines.push(`FN:${escapeVCardValue(customer.name)}`);
    lines.push(`N:;${escapeVCardValue(customer.name)};;;`);
  }

  // Phone
  if (customer.phone) {
    const normalizedPhone = normalizePhone(customer.phone);
    lines.push(`TEL;TYPE=CELL:${normalizedPhone}`);
  }

  // Email
  if (customer.email) {
    lines.push(`EMAIL:${escapeVCardValue(customer.email)}`);
  }

  // Address (only available on full Customer)
  if ('address' in customer && customer.address) {
    lines.push(`ADR;TYPE=HOME:;;${escapeVCardValue(customer.address)};;;;`);
  }

  lines.push('END:VCARD');

  return lines.join('\r\n');
}

/**
 * Generate vCard for display name only
 */
export function generateSimpleVCard(name: string, phone: string): string {
  const lines = [
    'BEGIN:VCARD',
    'VERSION:3.0',
    `FN:${escapeVCardValue(name)}`,
    `N:;${escapeVCardValue(name)};;;`,
    `TEL;TYPE=CELL:${normalizePhone(phone)}`,
    'END:VCARD',
  ];

  return lines.join('\r\n');
}

/**
 * Escape special characters in vCard values
 */
function escapeVCardValue(value: string): string {
  return value
    .replace(/\\/g, '\\\\')
    .replace(/;/g, '\\;')
    .replace(/,/g, '\\,')
    .replace(/\n/g, '\\n');
}

/**
 * Normalize phone number for vCard
 */
function normalizePhone(phone: string): string {
  // Remove all non-digit characters except leading +
  let normalized = phone.replace(/[^\d+]/g, '');

  // Ensure it starts with +
  if (!normalized.startsWith('+')) {
    // Assume Brazilian number if no country code
    if (normalized.length === 11 || normalized.length === 10) {
      normalized = '+55' + normalized;
    } else {
      normalized = '+' + normalized;
    }
  }

  return normalized;
}
