// CPF and CNPJ, numeric or alphanumeric (lib/utils/tax_id.dart, the server's
// utils/tax-id.utils.ts), checked by docs/web-app/contract-cases/tax-id.json.
// Saved normalized: digits and, for the alphanumeric CNPJ, uppercase letters.

const CNPJ_BODY = /^[0-9A-Z]{12}[0-9]{2}$/
const FIRST = [5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2]
const SECOND = [6, 5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2]

export function normalizeTaxId(value: string | null | undefined): string {
  return (value ?? '').toUpperCase().replace(/[^0-9A-Z]/g, '')
}

const same = (value: string) => new Set(value).size === 1
const values = (value: string) => [...value].map((char) => char.charCodeAt(0) - 48)

export function isValidCpf(value: string): boolean {
  const cpf = normalizeTaxId(value)
  if (cpf.length !== 11 || !/^\d+$/.test(cpf) || same(cpf)) return false
  const n = values(cpf)
  const digit = (size: number) => {
    const sum = n.slice(0, size).reduce((total, d, i) => total + d * (size + 1 - i), 0)
    const rest = (sum * 10) % 11
    return rest === 10 ? 0 : rest
  }
  return digit(9) === n[9] && digit(10) === n[10]
}

export function isValidCnpj(value: string): boolean {
  const cnpj = normalizeTaxId(value)
  if (!CNPJ_BODY.test(cnpj) || same(cnpj)) return false
  const n = values(cnpj)
  const digit = (weights: number[]) => {
    const rest = weights.reduce((total, w, i) => total + w * (n[i] as number), 0) % 11
    return rest < 2 ? 0 : 11 - rest
  }
  return digit(FIRST) === n[12] && digit(SECOND) === n[13]
}

export function isValidTaxId(value: string): boolean {
  const id = normalizeTaxId(value)
  return id.length === 11 ? isValidCpf(id) : id.length === 14 ? isValidCnpj(id) : false
}

/** "52998224725" → "529.982.247-25"; CNPJ with its dots, slash and dash. Other sizes as normalized. */
export function formatTaxId(value: string | null | undefined): string {
  const id = normalizeTaxId(value)
  if (id.length === 11) return `${id.slice(0, 3)}.${id.slice(3, 6)}.${id.slice(6, 9)}-${id.slice(9)}`
  if (id.length === 14) return `${id.slice(0, 2)}.${id.slice(2, 5)}.${id.slice(5, 8)}/${id.slice(8, 12)}-${id.slice(12)}`
  return id
}

/** CPF/CNPJ only for a Brazilian company, or one without a country (customer.form.tax-id). */
export const usesTaxId = (country: string | null | undefined) => !country || country.toUpperCase() === 'BR'
