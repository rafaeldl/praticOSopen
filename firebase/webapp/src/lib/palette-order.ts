// Groups of the ⌘K palette and their order. Pure (no router, no texts).
// When the text names an action ("cli" → "Novo cliente", "desc" → "Dar desconto"),
// the actions come before the records; the offer to register what was typed comes last.
import type { Command } from './commands'

export type Group = 'orders' | 'customers' | 'devices' | 'catalog' | 'actions' | 'create'
export const GROUPS: Group[] = ['orders', 'customers', 'devices', 'catalog', 'actions']
const PER_GROUP = 6

/** The group of a result, by its id ("order:…", "customer:…", "plate:…", "device:…", "catalog:…", "create:…"). */
export function groupOf(command: Pick<Command, 'id'>): Group {
  const kind = command.id.split(':')[0]
  if (kind === 'order') return 'orders'
  if (kind === 'customer') return 'customers'
  if (kind === 'plate' || kind === 'device') return 'devices'
  if (kind === 'catalog') return 'catalog'
  if (kind === 'create') return 'create'
  return 'actions'
}

export function paletteGroups(query: string, commands: Command[]): { group: Group; items: Command[] }[] {
  const actionsFirst = !!query.trim() && commands.some((command) => groupOf(command) === 'actions')
  const order: Group[] = actionsFirst ? ['actions', ...GROUPS.filter((group) => group !== 'actions'), 'create'] : [...GROUPS, 'create']
  return order
    .map((group) => ({ group, items: commands.filter((command) => groupOf(command) === group).slice(0, PER_GROUP) }))
    .filter((entry) => entry.items.length)
}
