// Command palette registry. Starts empty: each screen adds what it offers.
import { shallowReactive, type Component } from 'vue'
import type { MessageKey } from '@/generated/message-keys'
import { matchesWords } from './text'

export interface Command {
  id: string
  label: MessageKey
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
