// Whether the company has the nota on (NFS-e direct or Asaas), for the menu:
// "Notas fiscais" only shows when there is something to list. Filled by
// nfseSettings() (lib/nfse/data.ts), so the screen and the menu agree.
// Kept apart from data.ts so the shell does not load Firestore to draw the menu.
import { reactive } from 'vue'

export const nfseAvailability = reactive<{ companyId: string | null; available: boolean }>({ companyId: null, available: false })

export function recordNfseAvailability(companyId: string | null, available: boolean): void {
  nfseAvailability.companyId = companyId
  nfseAvailability.available = available
}

/** On only once read for this company: unknown or a failed read hides the entry. */
export function nfseOnFor(companyId: string | null): boolean {
  return companyId !== null && nfseAvailability.companyId === companyId && nfseAvailability.available
}
