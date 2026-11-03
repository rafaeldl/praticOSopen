// Keyboard shortcuts, in one registry so the help dialog can never go stale.
import { shallowReactive } from 'vue'
import type { MessageKey } from '@/generated/message-keys'
import { prefs } from './prefs'
import { ui } from './ui'

export interface Shortcut {
  /** 'n', '?', or 'mod+k' (Ctrl on Windows/Linux, ⌘ on Mac). */
  keys: string
  label: MessageKey
  run: () => void
  /** Still works while a layer is open. */
  global?: boolean
}

export const shortcuts = shallowReactive(new Map<string, Shortcut>())

/** Returns the function that removes it. Screens call this in onMounted. */
export function registerShortcut(shortcut: Shortcut): () => void {
  shortcuts.set(shortcut.keys, shortcut)
  return () => {
    if (shortcuts.get(shortcut.keys) === shortcut) shortcuts.delete(shortcut.keys)
  }
}

const isField = (target: EventTarget | null) =>
  target instanceof Element && target.matches('input, textarea, select, [contenteditable], [contenteditable="true"]')

/** The registry key for an event, or null for what the browser keeps (Ctrl+F, Ctrl+P…). */
export function keyOf(event: KeyboardEvent): string | null {
  const key = event.key.toLowerCase()
  if (event.ctrlKey || event.metaKey) return event.altKey || event.shiftKey ? null : `mod+${key}`
  return event.altKey ? null : key
}

export function handleShortcut(event: KeyboardEvent): void {
  const combo = keyOf(event)
  if (!combo) return
  const shortcut = shortcuts.get(combo)
  if (!shortcut) return
  const single = !combo.startsWith('mod+')
  if (single && (!prefs.singleKeyShortcuts || isField(event.target))) return
  if (ui.layers > 0 && !shortcut.global) return
  event.preventDefault()
  shortcut.run()
}

export const isMac = typeof navigator !== 'undefined' && /Mac|iPhone|iPad/.test(navigator.platform)

export function shortcutLabel(keys: string): string {
  return keys.replace('mod+', isMac ? '⌘ ' : 'Ctrl ').replace('arrowleft', '←').replace('arrowright', '→').toUpperCase()
}
