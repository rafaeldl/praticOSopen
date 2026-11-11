import { onBeforeUnmount, onMounted, watch, type WatchSource } from 'vue'

/**
 * Keeps the focus on an item that a redraw replaces. On a live list (the board)
 * an update can take an item out and put a new one in its place (a card going
 * back to its old column for a moment): the focus would fall to the page and
 * the keyboard would go nowhere. After each redraw the new element of the held
 * item gets it back. Leaving the item by hand (Tab, a click elsewhere) lets it go.
 *
 * Items are elements with `itemClass` whose id is `${idPrefix}${id}`.
 */
export function useHeldFocus(idPrefix: string, itemClass: string, redraws: WatchSource) {
  let held: string | null = null
  const idOf = (target: EventTarget | null) =>
    target instanceof HTMLElement && target.classList.contains(itemClass) && target.id.startsWith(idPrefix) ? target.id.slice(idPrefix.length) : null
  const onFocusIn = (event: FocusEvent) => (held = idOf(event.target))
  // Still on the page: left by hand. Removed with the redraw: kept. Chrome blurs
  // a card while it is being removed, still connected: decide after the redraw.
  const onFocusOut = (event: FocusEvent) => {
    const target = event.target
    if (event.relatedTarget || !(target instanceof Node)) return
    queueMicrotask(() => {
      if (target.isConnected && held === idOf(target)) held = null
    })
  }
  watch(
    redraws,
    () => {
      const active = document.activeElement
      if (!held || (active && active !== document.body)) return
      document.getElementById(`${idPrefix}${held}`)?.focus()
    },
    { flush: 'post' },
  )
  onMounted(() => {
    document.addEventListener('focusin', onFocusIn)
    document.addEventListener('focusout', onFocusOut)
  })
  onBeforeUnmount(() => {
    document.removeEventListener('focusin', onFocusIn)
    document.removeEventListener('focusout', onFocusOut)
  })
  return {
    /** Holds `id` from now on (the board focuses a card after a move). */
    hold: (id: string) => (held = id),
  }
}
