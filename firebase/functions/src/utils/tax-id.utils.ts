/**
 * Brazilian CPF / CNPJ helpers (check digits). Mirrors lib/utils/tax_id.dart.
 * `Customer.taxId` is stored normalized: digits and, for the alphanumeric CNPJ
 * (Receita Federal, since July 2026), uppercase letters.
 */

const DIGITS_ONLY = /^[0-9]+$/;
const CNPJ_BODY = /^[0-9A-Z]{12}[0-9]{2}$/;
const CNPJ_FIRST_WEIGHTS = [5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2];
const CNPJ_SECOND_WEIGHTS = [6, 5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2];

/** Uppercases and keeps only [0-9A-Z] (drops '.', '-', '/', spaces, etc.). */
export function normalizeTaxId(value: string | null | undefined): string {
  return (value || '').toUpperCase().replace(/[^0-9A-Z]/g, '');
}

function allSameChar(value: string): boolean {
  return new Set(value.split('')).size === 1;
}

/** Character value used by the check digits: codeUnit - 48 (0-9 → 0-9, A=17 ... Z=42). */
function charValues(value: string): number[] {
  return value.split('').map((c) => c.charCodeAt(0) - 48);
}

/** Brazilian CPF (11 digits, two mod-11 check digits). Numeric only. */
export function isValidCpf(value: string): boolean {
  const cpf = normalizeTaxId(value);
  if (cpf.length !== 11 || !DIGITS_ONLY.test(cpf) || allSameChar(cpf)) return false;
  const numbers = charValues(cpf);
  for (let position = 9; position <= 10; position++) {
    let sum = 0;
    for (let i = 0; i < position; i++) sum += numbers[i] * (position + 1 - i);
    const check = ((sum * 10) % 11) % 10;
    if (check !== numbers[position]) return false;
  }
  return true;
}

/**
 * Brazilian CNPJ, numeric or alphanumeric: 12 [0-9A-Z] characters plus two
 * numeric check digits, same weights as the numeric CNPJ.
 */
export function isValidCnpj(value: string): boolean {
  const cnpj = normalizeTaxId(value);
  if (!CNPJ_BODY.test(cnpj) || allSameChar(cnpj)) return false;
  const values = charValues(cnpj);
  const checkDigit = (weights: number[]): number => {
    let sum = 0;
    for (let i = 0; i < weights.length; i++) sum += values[i] * weights[i];
    const rest = sum % 11;
    return rest < 2 ? 0 : 11 - rest;
  };
  return checkDigit(CNPJ_FIRST_WEIGHTS) === values[12] && checkDigit(CNPJ_SECOND_WEIGHTS) === values[13];
}

/** CPF when 11 characters, CNPJ when 14; anything else is invalid. */
export function isValidTaxId(value: string): boolean {
  const id = normalizeTaxId(value);
  if (id.length === 11) return isValidCpf(id);
  if (id.length === 14) return isValidCnpj(id);
  return false;
}
