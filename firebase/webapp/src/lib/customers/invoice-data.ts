// "Dados para nota" of a customer (docs/NFSE_DIRECT.md, etapa #568), same rules
// as the app (lib/screens/customers/customer_invoice_fields.dart): shown only
// with settings/payments.nfseDirectEnabled; a CNPJ fills from the Receita
// (BrasilAPI), a CEP from ViaCEP; a CPF/CNPJ lives in one customer only.
import { firestoreLite } from '@/lib/firebase'
import { session } from '@/lib/session'
import { normalizeTaxId } from '@/lib/tax-id'

export interface FiscalAddress {
  postalCode: string | null
  street: string | null
  number: string | null
  complement: string | null
  district: string | null
  /** IBGE code of the city (7 digits), from a lookup. */
  cityCode: string | null
  cityName: string | null
  state: string | null
}

export type AutoIssue = 'never' | 'selectedCustomers' | 'allOrders'

export interface InvoiceConfig {
  enabled: boolean
  autoIssue: AutoIssue
}

export const INVOICE_OFF: InvoiceConfig = { enabled: false, autoIssue: 'never' }

/** settings/payments and settings/nfse. Anything that fails reads as off ("Nunca" for the switch). */
export async function invoiceConfig(): Promise<InvoiceConfig> {
  if (!session.companyId) return INVOICE_OFF
  try {
    const [db, { doc, getDoc }] = await Promise.all([firestoreLite(), import('firebase/firestore/lite')])
    const payments = await getDoc(doc(db, 'companies', session.companyId, 'settings', 'payments'))
    if (payments.data()?.nfseDirectEnabled !== true) return INVOICE_OFF
    let autoIssue: AutoIssue = 'never'
    try {
      // Only people with access to charges read it (firestore.rules): the others never see the switch.
      const nfse = await getDoc(doc(db, 'companies', session.companyId, 'settings', 'nfse'))
      autoIssue = parseAutoIssue(nfse.data()?.autoIssue)
    } catch {
      // keeps "never"
    }
    return { enabled: true, autoIssue }
  } catch {
    return INVOICE_OFF
  }
}

/** The Asaas values of the same key read as "never". */
export const parseAutoIssue = (value: unknown): AutoIssue => (value === 'selectedCustomers' || value === 'allOrders' ? value : 'never')

/** The switch shows only when the nota goes out by itself; untouched, it follows the mode. */
export const showAutoIssue = (config: InvoiceConfig) => config.enabled && config.autoIssue !== 'never'
export const autoIssueOf = (config: InvoiceConfig, saved: boolean | null | undefined) => saved ?? config.autoIssue === 'allOrders'

/** The other customer that already has this CPF/CNPJ (any format), or null. */
export function findByTaxId<T extends { id: string; taxId: string | null }>(customers: T[], taxId: string, except?: string | null): T | null {
  const id = normalizeTaxId(taxId)
  if (!id) return null
  return customers.find((customer) => customer.id !== except && normalizeTaxId(customer.taxId) === id) ?? null
}

export const postalCodeDigits = (value: string | null | undefined) => (value ?? '').replace(/\D/g, '').slice(0, 8)
export function formatPostalCode(value: string | null | undefined): string {
  const digits = postalCodeDigits(value)
  return digits.length > 5 ? `${digits.slice(0, 5)}-${digits.slice(5)}` : digits
}

const str = (value: unknown): string | null => {
  const text = value === null || value === undefined ? '' : String(value).trim()
  return text ? text : null
}
const onlyDigits = (value: unknown): string | null => str(value)?.replace(/\D/g, '') || null
/** The Receita writes in capitals ("RUA DAS FLORES"); the form shows it as people write it. */
const titleCase = (value: string | null) => (value ? value.toLowerCase().replace(/(^|\s)(\S)/g, (_, space, letter: string) => space + letter.toUpperCase()) : null)

type Fetch = (url: string) => Promise<{ ok: boolean; json: () => Promise<unknown> }>

async function getJson(url: string, fetcher: Fetch): Promise<Record<string, unknown> | null> {
  try {
    const response = await fetcher(url)
    if (!response.ok) return null
    const body = await response.json()
    return body && typeof body === 'object' ? (body as Record<string, unknown>) : null
  } catch {
    return null
  }
}

export interface CnpjInfo {
  legalName: string
  email: string | null
  address: FiscalAddress
}

/** CNPJ with 14 digits (the alphanumeric one has no public lookup yet). Null when not found or offline. */
export async function lookupCnpj(cnpj: string, fetcher: Fetch = fetch): Promise<CnpjInfo | null> {
  if (!/^\d{14}$/.test(cnpj)) return null
  const json = await getJson(`https://brasilapi.com.br/api/cnpj/v1/${cnpj}`, fetcher)
  const legalName = str(json?.razao_social)
  if (!json || !legalName) return null
  const street = [str(json.descricao_tipo_de_logradouro), str(json.logradouro)].filter(Boolean).join(' ')
  return {
    legalName,
    email: str(json.email)?.toLowerCase() ?? null,
    address: {
      postalCode: onlyDigits(json.cep),
      street: titleCase(street || null),
      number: str(json.numero),
      complement: titleCase(str(json.complemento)),
      district: titleCase(str(json.bairro)),
      cityCode: onlyDigits(json.codigo_municipio_ibge),
      cityName: titleCase(str(json.municipio)),
      state: str(json.uf)?.toUpperCase() ?? null,
    },
  }
}

/** CEP with 8 digits: street, district, city (with the IBGE code) and UF. */
export async function lookupPostalCode(postalCode: string, fetcher: Fetch = fetch): Promise<FiscalAddress | null> {
  if (!/^\d{8}$/.test(postalCode)) return null
  const json = await getJson(`https://viacep.com.br/ws/${postalCode}/json/`, fetcher)
  if (!json || json.erro !== undefined || !str(json.localidade)) return null
  return {
    postalCode,
    street: str(json.logradouro),
    number: null,
    complement: null,
    district: str(json.bairro),
    cityCode: onlyDigits(json.ibge),
    cityName: str(json.localidade),
    state: str(json.uf)?.toUpperCase() ?? null,
  }
}
