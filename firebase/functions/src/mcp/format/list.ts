import type { PendingItems } from '../../models/types';
import { money, statusLabel, truncate } from './order';

export function formatSummary(summary: any): string {
  return [
    '**Resumo de hoje**',
    `- OS novas: ${summary.ordersCreatedToday ?? 0}`,
    `- Para aprovar: ${summary.toApprove ?? 0}`,
    `- Faturamento: ${money(summary.revenue)}`,
  ].join('\n');
}

export function formatRevenue(revenue: any): string {
  return [
    '**Faturamento**',
    `- Total: ${money(revenue.total)}`,
    `- Recebido: ${money(revenue.paid)}`,
    `- A receber: ${money(revenue.unpaid)}`,
  ].join('\n');
}

export function formatSearchResult(result: any, limit = 20): string {
  const maxLimit = Math.min(Math.max(1, limit || 20), 50);
  const blocks: string[] = [];

  for (const key of ['customer', 'device', 'service', 'product']) {
    const entry = result?.[key];
    if (!entry) continue;

    const found: any[] = entry.exact
      ? [entry.exact]
      : entry.suggestions ?? entry.results ?? [];

    const isAlternative = found.length === 0 && entry.available?.length > 0;
    const itemsToShow: any[] = isAlternative ? entry.available : found;

    if (!itemsToShow?.length) continue;

    const { items, omitted } = truncate(itemsToShow, maxLimit);
    const label = isAlternative ? `${key} (alternativas)` : key;
    blocks.push(`**${label}**`);
    for (const item of items) {
      const extra = item.serial ? ` (${item.serial})` : '';
      blocks.push(`- \`${item.id}\` ${item.name}${extra}`);
    }
    if (omitted) blocks.push(`_(+${omitted})_`);
  }

  if (!blocks.length) return 'Nada encontrado.';
  return blocks.join('\n');
}

export function formatEntityList(type: string, items: any[], omitted = 0): string {
  if (!items.length) return `Nenhum registro de ${type}.`;

  const lines = items.map((item) => {
    const extra = item.serial
      ? ` (${item.serial})`
      : item.value !== undefined
        ? ` — ${money(item.value)}`
        : '';
    return `- \`${item.id}\` ${item.name}${extra}`;
  });

  if (omitted > 0) lines.push(`_(+${omitted} não exibidos)_`);

  return lines.join('\n');
}

export function formatPendingItems(pending: PendingItems): string {
  const blocks: string[] = [];

  const sections: Array<[string, any[]]> = [
    ['Aguardando aprovação', pending.toApprove || []],
    ['Vence hoje', pending.dueToday || []],
    ['Não pago', pending.unpaid || []],
    ['Vencido', pending.overdue || []],
  ];

  for (const [heading, items] of sections) {
    if (!items.length) continue;

    const { items: truncated, omitted } = truncate(items, 20);
    blocks.push(`**${heading}**`);
    for (const order of truncated) {
      const device = order.device?.name || 'N/A';
      const customer = order.customer?.name || 'N/A';
      blocks.push(`- **#${order.number}** ${customer} — ${device} — ${money(order.total)}`);
    }
    if (omitted) blocks.push(`_(+${omitted})_`);
    blocks.push('');
  }

  if (!blocks.length) return 'Nenhum item pendente.';
  return blocks.slice(0, -1).join('\n');
}

export { statusLabel };
