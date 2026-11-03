// Small shared screen state: open layers, announcements and the shell's overlays.
import { reactive } from 'vue'

export const ui = reactive({
  /** Open modal layers. Single-key shortcuts stop while any is open. */
  layers: 0,
  /** Text for the polite aria-live region. */
  live: '',
  palette: false,
  shortcuts: false,
})

export function announce(text: string): void {
  // Same text twice must be read twice.
  ui.live = ''
  queueMicrotask(() => {
    ui.live = text
  })
}
