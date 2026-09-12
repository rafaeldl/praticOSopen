const STATUS_LABELS: Record<string, string> = {
  budget: 'Orçamento',
  approved: 'Aprovada',
  progress: 'Em andamento',
  done: 'Concluída',
  canceled: 'Cancelada',
};

export function statusLabel(status?: string): string {
  return (status && STATUS_LABELS[status]) || status || '—';
}

export function money(value?: number): string {
  if (value === undefined || value === null) return 'R$ 0,00';
  return new Intl.NumberFormat('pt-BR', {
    style: 'currency',
    currency: 'BRL',
  }).format(value);
}

export function truncate<T>(items: T[], limit: number): { items: T[]; omitted: number } {
  if (items.length <= limit) return { items, omitted: 0 };
  return { items: items.slice(0, limit), omitted: items.length - limit };
}

export function formatOrder(order: any): string {
  const lines: string[] = [];

  lines.push(`**OS #${order.number}** — ${statusLabel(order.status)}`);

  if (order.customer?.name) lines.push(`Cliente: ${order.customer.name}`);

  const devices: any[] = order.devices ?? [];
  if (devices.length) {
    const names = devices
      .map((d) => (d.serial ? `${d.name} (${d.serial})` : d.name))
      .join(', ');
    lines.push(`Dispositivo: ${names}`);
  }

  const services: any[] = order.services ?? [];
  if (services.length) {
    lines.push('');
    lines.push('Serviços:');
    for (const s of services) {
      lines.push(`- ${s.name}${s.description ? ` — ${s.description}` : ''}: ${money(s.value)}`);
    }
  }

  const products: any[] = order.products ?? [];
  if (products.length) {
    lines.push('');
    lines.push('Produtos:');
    for (const p of products) {
      const qty = p.quantity && p.quantity > 1 ? ` x${p.quantity}` : '';
      lines.push(`- ${p.name}${qty}: ${money(p.value)}`);
    }
  }

  lines.push('');
  lines.push(`Total: ${money(order.total)}`);

  if (order.shareUrl) lines.push(`Link para o cliente: ${order.shareUrl}`);

  return lines.join('\n');
}

export function formatOrderList(orders: any[], omitted = 0): string {
  if (!orders.length) return 'Nenhuma OS encontrada.';

  const lines = orders.map((o) => {
    const customer = o.customer?.name ? ` — ${o.customer.name}` : '';
    return `- **#${o.number}** ${statusLabel(o.status)}${customer} — ${money(o.total)}`;
  });

  if (omitted > 0) lines.push(`_(+${omitted} não exibidas)_`);

  return lines.join('\n');
}
