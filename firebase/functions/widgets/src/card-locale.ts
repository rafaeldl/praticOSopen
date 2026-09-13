import type { OrderData } from './card-state';

const pt = {
  order: 'OS', total: 'Total da OS', services: 'Serviços', products: 'Produtos',
  share: 'Compartilhar', copy: 'Abrir no PraticOS', complete: 'Concluir OS',
  copyLink: 'Copiar link', openFailed: 'Não foi possível abrir o PraticOS. Use o link abaixo.',
  approve: 'Aprovar', confirm: 'Confirmar', cancel: 'Cancelar', saving: 'Salvando…',
  confirmDone: 'Concluir esta OS?', confirmApproved: 'Aprovar esta OS?',
  photo: 'Foto da OS', copied: 'Link copiado', failed: 'Não foi possível atualizar',
  shareFailed: 'Não foi possível compartilhar. Tente novamente.',
  opening: 'Compartilhando…', manualCopy: 'Copie o link e compartilhe onde preferir:',
  quote: 'Orçamento', approved: 'Aprovada', progress: 'Em andamento',
  done: 'Concluída', canceled: 'Cancelada', unknown: 'Status não informado',
  follow: 'Acompanhe sua ordem de serviço:',
};
export type CardLabels = { readonly [Key in keyof typeof pt]: string };
const en: CardLabels = {
  order: 'Order', total: 'Order total', services: 'Services', products: 'Products',
  share: 'Share', copy: 'Open in PraticOS', complete: 'Complete order',
  copyLink: 'Copy link', openFailed: 'Unable to open PraticOS. Use the link below.',
  approve: 'Approve', confirm: 'Confirm', cancel: 'Cancel', saving: 'Saving…',
  confirmDone: 'Complete this order?', confirmApproved: 'Approve this order?',
  photo: 'Order photo', copied: 'Link copied', failed: 'Unable to update',
  shareFailed: 'Unable to share. Try again.',
  opening: 'Sharing…', manualCopy: 'Copy the link and share it wherever you prefer:',
  quote: 'Quote', approved: 'Approved', progress: 'In progress',
  done: 'Completed', canceled: 'Canceled', unknown: 'Status unavailable',
  follow: 'Track your service order:',
};
const es: CardLabels = {
  order: 'OS', total: 'Total de la OS', services: 'Servicios', products: 'Productos',
  share: 'Compartir', copy: 'Abrir en PraticOS', complete: 'Completar OS',
  copyLink: 'Copiar enlace', openFailed: 'No se pudo abrir PraticOS. Usa el enlace de abajo.',
  approve: 'Aprobar', confirm: 'Confirmar', cancel: 'Cancelar', saving: 'Guardando…',
  confirmDone: '¿Completar esta OS?', confirmApproved: '¿Aprobar esta OS?',
  photo: 'Foto de la OS', copied: 'Enlace copiado', failed: 'No se pudo actualizar',
  shareFailed: 'No se pudo compartir. Inténtalo de nuevo.',
  opening: 'Compartiendo…', manualCopy: 'Copia el enlace y compártelo donde prefieras:',
  quote: 'Presupuesto', approved: 'Aprobada', progress: 'En curso',
  done: 'Completada', canceled: 'Cancelada', unknown: 'Estado no disponible',
  follow: 'Sigue tu orden de servicio:',
};
export function cardLocale(locale?: string) {
  const language = locale?.toLowerCase().split(/[-_]/)[0];
  if (language === 'en') return { labels: en, locale: 'en-US' };
  if (language === 'es') return { labels: es, locale: 'es-ES' };
  return { labels: pt, locale: 'pt-BR' };
}
export function formatMoney(value: number | undefined, locale: string): string {
  return new Intl.NumberFormat(locale, { style: 'currency', currency: 'BRL' }).format(value ?? 0);
}
export function statusLabel(status: string | undefined, labels: CardLabels): string {
  switch (status) {
    case 'quote': case 'approved': case 'progress': case 'done': case 'canceled': return labels[status];
    default: return status || labels.unknown;
  }
}
export function shareData(order: OrderData, locale: string): { readonly title: string; readonly text: string; readonly url: string } | null {
  if (!order.shareUrl) return null;
  const { labels } = cardLocale(locale);
  const devices = (order.devices ?? []).map(d => [d.name, d.serial].filter(Boolean).join(' · '));
  const text = [
    `PraticOS · ${labels.order} #${order.number ?? '—'}`,
    ...devices,
    `${labels.total}: ${formatMoney(order.total, locale)}`,
    labels.follow,
  ].join('\n');
  return { title: `PraticOS · ${labels.order} #${order.number ?? '—'}`, text, url: order.shareUrl };
}
