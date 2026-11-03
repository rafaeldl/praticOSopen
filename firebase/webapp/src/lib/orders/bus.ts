// An order changed or left on one screen (panel, Nova OS, lote): the list
// updates that row in place, keeping its page and scroll (home.list.reload-on-return).
import type { Order } from './model'

type Listener = (event: { order?: Order; removedId?: string; created?: boolean; createdId?: string }) => void
const listeners = new Set<Listener>()

export function onOrderEvent(listener: Listener): () => void {
  listeners.add(listener)
  return () => listeners.delete(listener)
}

export function orderChanged(order: Order, created = false): void {
  listeners.forEach((listener) => listener({ order, created }))
}

/** A new order: who reads the API list asks for the first page again. */
export function orderCreated(id: string): void {
  listeners.forEach((listener) => listener({ createdId: id }))
}

export function orderRemoved(id: string): void {
  listeners.forEach((listener) => listener({ removedId: id }))
}
