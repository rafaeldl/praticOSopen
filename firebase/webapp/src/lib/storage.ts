// localStorage can throw (private window, blocked site data). Preferences then
// just last for the visit.
export function readStorage(key: string): string | null {
  try {
    return localStorage.getItem(key)
  } catch {
    return null
  }
}

export function writeStorage(key: string, value: string): void {
  try {
    localStorage.setItem(key, value)
  } catch {
    // Nothing to do: the value stays in memory.
  }
}
