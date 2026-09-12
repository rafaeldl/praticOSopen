import { money, statusLabel, truncate } from './order';

export function formatSummary(summary: any): string {
  return [
    '**Resumo de hoje**',
    `- OS novas: ${summary.newOrders ?? 0}`,
    `- OS concluídas: ${summary.completedOrders ?? 0}`,
    `- Faturamento: ${money(summary.revenue)}`,
  ].join('\n');
}

export function formatRevenue(revenue: any): string {
  return [
    '**Faturamento**',
    `- Total: ${money(revenue.total)}`,
    `- Recebido: ${money(revenue.paid)}`,
    `- A receber: ${money(revenue.pending)}`,
  ].join('\n');
}

export function formatSearchResult(result: any): string {
  const blocks: string[] = [];

  for (const key of ['customer', 'device', 'service', 'product']) {
    const entry = result?.[key];
    if (!entry) continue;

    const found: any[] = entry.exact
      ? [entry.exact]
      : entry.suggestions ?? entry.results ?? [];

    if (!found.length) continue;

    const { items, omitted } = truncate(found, 10);
    blocks.push(`**${key}**`);
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

export { statusLabel };
