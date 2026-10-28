/**
 * Customer data the city needs on a nota: e-mail and address with CEP.
 * Without them Asaas creates the nota but refuses to issue it ("E-mail do
 * cliente incompleto.; Endereço do cliente incompleto.; CEP do cliente é
 * inválido."). See docs/NFSE_ASAAS.md.
 *
 * The PraticOS customer has only a free-text `address`, so the address lives
 * on the Asaas customer: the issue sheet asks for what is missing there and
 * the server sends it (PUT /customers/{id}) before creating the nota.
 */

import { db } from '../firestore.service';
import { Customer } from '../../models/types';
import { AsaasCustomerContact } from '../../models/asaas.types';
import { AsaasApiError, AsaasClient } from './asaas-client';
import { AsaasServiceError } from './errors';
import { EMAIL_PATTERN, findAsaasCustomerId } from './charge.service';

/** Fields a nota cannot go without (complement is optional). */
export const INVOICE_CUSTOMER_FIELDS = ['email', 'postalCode', 'address', 'addressNumber', 'province'] as const;
export type InvoiceCustomerField = (typeof INVOICE_CUSTOMER_FIELDS)[number];

const MAX_LENGTH: Record<keyof AsaasCustomerContact, number> = {
  email: 254,
  postalCode: 8,
  address: 200,
  addressNumber: 20,
  complement: 100,
  province: 100,
};
const CONTACT_FIELDS = Object.keys(MAX_LENGTH) as Array<keyof AsaasCustomerContact>;

/** Trimmed valid fields only (CEP as 8 digits, e-mail checked); the rest is dropped. */
export function cleanCustomerContact(input?: AsaasCustomerContact | null): AsaasCustomerContact {
  const clean: AsaasCustomerContact = {};
  if (!input) return clean;
  for (const key of CONTACT_FIELDS) {
    const raw = input[key];
    if (typeof raw !== 'string') continue;
    const value = key === 'postalCode' ? raw.replace(/\D/g, '') : raw.trim();
    if (!value || value.length > MAX_LENGTH[key]) continue;
    if (key === 'email' && !EMAIL_PATTERN.test(value)) continue;
    if (key === 'postalCode' && value.length !== 8) continue;
    clean[key] = value;
  }
  return clean;
}

export function missingCustomerFields(contact: AsaasCustomerContact): InvoiceCustomerField[] {
  const clean = cleanCustomerContact(contact);
  return INVOICE_CUSTOMER_FIELDS.filter((field) => !clean[field]);
}

export interface InvoiceCustomerData {
  /** What is known: the Asaas customer, else the PraticOS e-mail. */
  contact: AsaasCustomerContact;
  missing: InvoiceCustomerField[];
}

/**
 * For the preview: the data the Asaas customer already has and what the sheet
 * must ask. Asaas unreachable: only the PraticOS data counts (the create
 * checks again).
 */
export async function invoiceCustomerData(
  client: AsaasClient,
  companyId: string,
  customerId: string,
  customer?: Pick<Customer, 'email'>,
): Promise<InvoiceCustomerData> {
  let onAsaas: AsaasCustomerContact = {};
  try {
    const asaasCustomerId = await findAsaasCustomerId(client, companyId, customerId);
    if (asaasCustomerId) onAsaas = cleanCustomerContact(await client.getCustomer(asaasCustomerId));
  } catch (error) {
    const status = error instanceof AsaasApiError ? error.status : 'unknown';
    console.warn(`[NFS-e] Could not read the Asaas customer of ${customerId} (company ${companyId}, status ${status})`);
  }
  const contact = { ...cleanCustomerContact({ email: customer?.email }), ...onAsaas };
  return { contact, missing: missingCustomerFields(contact) };
}

/**
 * Before creating a nota: the Asaas customer has e-mail and address with CEP.
 * Typed data wins, then what Asaas has, then the PraticOS e-mail; changed
 * fields go to Asaas. Still missing: CUSTOMER_DATA_REQUIRED, nothing created.
 */
export async function ensureInvoiceCustomer(
  client: AsaasClient,
  asaasCustomerId: string,
  customer: Pick<Customer, 'email'>,
  typed?: AsaasCustomerContact,
): Promise<AsaasCustomerContact> {
  const current = cleanCustomerContact(await client.getCustomer(asaasCustomerId));
  const merged: AsaasCustomerContact = {
    ...cleanCustomerContact({ email: customer.email }),
    ...current,
    ...cleanCustomerContact(typed),
  };
  const missing = missingCustomerFields(merged);
  if (missing.length > 0) {
    throw new AsaasServiceError('CUSTOMER_DATA_REQUIRED', `Customer data required: ${missing.join(', ')}`);
  }
  const changes: AsaasCustomerContact = {};
  for (const key of CONTACT_FIELDS) {
    if (merged[key] && merged[key] !== current[key]) changes[key] = merged[key];
  }
  if (Object.keys(changes).length > 0) await client.updateCustomer(asaasCustomerId, changes);
  return merged;
}

/** "Rua das Flores, 120, apto 2 - Centro - CEP 01310-000" */
export function formatCustomerAddress(contact: AsaasCustomerContact): string {
  const street = [contact.address, contact.addressNumber, contact.complement].filter((p) => !!p).join(', ');
  const cep = contact.postalCode ? `CEP ${contact.postalCode.slice(0, 5)}-${contact.postalCode.slice(5)}` : '';
  return [street, contact.province, cep].filter((p) => !!p).join(' - ');
}

/**
 * Keeps the typed data on the PraticOS customer where it has nothing yet
 * (e-mail, and the address as text): never overwrites what the user wrote.
 * A failure here does not stop the nota.
 */
export async function saveContactOnCustomer(
  companyId: string,
  customer: Pick<Customer, 'id' | 'email' | 'address'>,
  typed?: AsaasCustomerContact,
): Promise<void> {
  const input = cleanCustomerContact(typed);
  const update: Record<string, string> = {};
  if (input.email && !(customer.email || '').trim()) update.email = input.email;
  if (input.address && input.addressNumber && !(customer.address || '').trim()) {
    update.address = formatCustomerAddress(input);
  }
  if (Object.keys(update).length === 0) return;
  try {
    await db.collection('companies').doc(companyId).collection('customers').doc(customer.id).update(update);
  } catch {
    console.warn(`[NFS-e] Could not save the nota data on customer ${customer.id} of company ${companyId}`);
  }
}
