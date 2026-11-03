// One toast at a time. A toast with Undo stays until the next one or until
// closed: a timer would take the way back from someone who is still reading
// (REVISAO-UX P1 13).
import { shallowRef } from 'vue'

export interface Toast {
  id: number
  message: string
  undo?: () => void
}

const AUTO_DISMISS_MS = 6000

export const currentToast = shallowRef<Toast | null>(null)
let nextId = 1
let timer: ReturnType<typeof setTimeout> | undefined

export function dismissToast(): void {
  clearTimeout(timer)
  currentToast.value = null
}

export function showToast(message: string, options: { undo?: () => void } = {}): void {
  clearTimeout(timer)
  currentToast.value = { id: nextId++, message, undo: options.undo }
  if (!options.undo) timer = setTimeout(dismissToast, AUTO_DISMISS_MS)
}

export function undoToast(): void {
  const undo = currentToast.value?.undo
  dismissToast()
  undo?.()
}
