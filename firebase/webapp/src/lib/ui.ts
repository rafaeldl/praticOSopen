// Small shared screen state: open layers, announcements and the shell's overlays.
import { reactive } from 'vue'

export const ui = reactive({
  /** Open modal layers. Single-key shortcuts stop while any is open. */
  layers: 0,
  /** Text for the polite aria-live region. */
  live: '',
  palette: false,
  shortcuts: false,
  /** Nova OS drawer, over any screen (key N, the + of the shell). */
  newOrder: false,
  /** What Nova OS opens with, from a customer or a device screen. */
  newOrderSeed: null as null | {
    customer?: { id: string; name: string; phone?: string }
    device?: { id: string; name: string; serial?: string | null }
    /** Services of the device's last finished order, with its value ("Abrir OS" of a maintenance). */
    items?: { id: string; name: string; value: number | null }[]
    /** "Novo contrato" (contract.list.new): Nova OS with Repetir on. */
    repeat?: boolean
  },
})

export function announce(text: string): void {
  // Same text twice must be read twice.
  ui.live = ''
  queueMicrotask(() => {
    ui.live = text
  })
}
