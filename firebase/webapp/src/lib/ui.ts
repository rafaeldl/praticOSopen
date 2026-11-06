// Small shared screen state: open layers, announcements and the shell's overlays.
import { reactive } from 'vue'
import type { DraftActions, NfseMoment } from '@/lib/orders/ai-actions'

export const ui = reactive({
  /** Open modal layers. Single-key shortcuts stop while any is open. */
  layers: 0,
  /** Text for the polite aria-live region. */
  live: '',
  palette: false,
  /** Text the palette opens with (a digit typed on a screen). */
  paletteQuery: '',
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
    /** "Experimentar agora" of the assistant's presentation: the cursor starts in the assistant (order.ai.intro-try). */
    assist?: boolean
    /** A free hour clicked on the Agenda: the visit (or the delivery, without useScheduling), as a datetime-local value. */
    visit?: string
    due?: string
    /** The person of the Agenda's "De quem" filter. */
    assignee?: string
  },
  /** Money said to the assistant on a Nova OS: the "Confere?" card opens on that order once it exists (order.ai.money-card). */
  aiActionsFor: null as null | { orderId: string; actions: DraftActions; nfse: NfseMoment | null },
  /** Goes up when a notification arrives with the page on screen: the bell counts again. */
  noticesChanged: 0,
})

export function announce(text: string): void {
  // Same text twice must be read twice.
  ui.live = ''
  queueMicrotask(() => {
    ui.live = text
  })
}
