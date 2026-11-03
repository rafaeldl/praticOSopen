// Command palette registry. Starts empty: each screen adds what it offers.
import { shallowReactive, type Component } from 'vue'
import type { MessageKey } from '@/generated/message-keys'
import { matchesWords } from './text'

export interface Command {
  id: string
  label: MessageKey
  /** Data shown as is (a customer, an order), instead of the message of `label`. */
  text?: string
  sub?: string
  icon?: Component
  keys?: string
  run: () => void
}

export const commands = shallowReactive(new Map<string, Command>())

export function registerCommand(command: Command): () => void {
  commands.set(command.id, command)
  return () => {
    if (commands.get(command.id) === command) commands.delete(command.id)
  }
}

export function searchCommands(query: string, label: (key: MessageKey) => string): Command[] {
  const all = [...commands.values()]
  const text = query.trim()
  return text ? all.filter((command) => matchesWords(label(command.label), text)) : all
}

/** Screens that hold data answer the palette's search (orders, customers, devices). */
export const searchers = shallowReactive(new Map<string, (query: string) => Command[]>())

export function registerSearcher(id: string, search: (query: string) => Command[]): () => void {
  searchers.set(id, search)
  return () => searchers.delete(id)
}

export function searchAll(query: string, label: (key: MessageKey) => string): Command[] {
  const found = query.trim() ? [...searchers.values()].flatMap((search) => search(query.trim())) : []
  return [...searchCommands(query, label), ...found.slice(0, 12)]
}
