// Phone as people read it. The app saves the WhatsApp number in E.164
// (+5511990000001); lists show it in the local way. Only Brazil for now:
// any other number is shown as saved, never guessed.

/** "+5511990000001" → "(11) 99000-0001"; "+551133334444" → "(11) 3333-4444". */
export function formatPhone(phone: string | null | undefined): string {
  if (!phone) return ''
  const digits = phone.replace(/\D/g, '')
  const local = digits.startsWith('55') && (digits.length === 12 || digits.length === 13) ? digits.slice(2) : null
  if (!local) return phone
  const area = local.slice(0, 2)
  const rest = local.slice(2)
  const cut = rest.length - 4
  return `(${area}) ${rest.slice(0, cut)}-${rest.slice(cut)}`
}
