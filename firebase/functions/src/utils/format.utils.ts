/**
 * Format Utilities
 * Helper functions for formatting messages and data
 */

import { Order, Customer, PendingItems, toDate } from '../models/types';

/**
 * Format currency value for display
 */
export function formatCurrency(value: number, locale = 'pt-BR', currency = 'BRL'): string {
  return new Intl.NumberFormat(locale, {
    style: 'currency',
    currency,
  }).format(value);
}

/**
 * Format date for display
 */
export function formatDate(date: Date, locale = 'pt-BR'): string {
  return new Intl.DateTimeFormat(locale, {
    day: '2-digit',
    month: '2-digit',
    year: 'numeric',
  }).format(date);
}

/**
 * Format phone number for display (Brazilian format)
 */
export function formatPhone(phone: string): string {
  const cleaned = phone.replace(/\D/g, '');

  if (cleaned.length === 11) {
    return `(${cleaned.slice(0, 2)}) ${cleaned.slice(2, 7)}-${cleaned.slice(7)}`;
  }
  if (cleaned.length === 10) {
    return `(${cleaned.slice(0, 2)}) ${cleaned.slice(2, 6)}-${cleaned.slice(6)}`;
  }

  return phone;
}

/**
 * Normalize phone number (remove formatting, add country code if needed)
 */
export function normalizePhone(phone: string, defaultCountryCode = '55'): string {
  let cleaned = phone.replace(/\D/g, '');

  // Add country code if not present
  if (!cleaned.startsWith(defaultCountryCode) && cleaned.length <= 11) {
    cleaned = defaultCountryCode + cleaned;
  }

  return '+' + cleaned;
}

/**
 * Generate vCard format for a customer
 */
export function generateVCard(customer: Customer): string {
  const lines = [
    'BEGIN:VCARD',
    'VERSION:3.0',
    `FN:${customer.name}`,
    `N:;${customer.name};;;`,
  ];

  if (customer.phone) {
    lines.push(`TEL;TYPE=CELL:${customer.phone}`);
  }

  if (customer.email) {
    lines.push(`EMAIL:${customer.email}`);
  }

  if (customer.address) {
    lines.push(`ADR;TYPE=HOME:;;${customer.address};;;;`);
  }

  lines.push('END:VCARD');

  return lines.join('\r\n');
}

/**
 * Format today summary for WhatsApp message
 */
export function formatTodaySummary(data: {
  totalOrders: number;
  toApprove: number;
  dueToday: number;
  unpaidAmount: number;
}): string {
  const lines = [
    '*Resumo de hoje:*',
    '',
    `• ${data.totalOrders} OS no total`,
  ];

  if (data.toApprove > 0) {
    lines.push(`• ${data.toApprove} aguardando aprovação`);
  }

  if (data.dueToday > 0) {
    lines.push(`• ${data.dueToday} para entregar hoje`);
  }

  if (data.unpaidAmount > 0) {
    lines.push(`• ${formatCurrency(data.unpaidAmount)} a receber`);
  }

  return lines.join('\n');
}

/**
 * Format pending items for WhatsApp message
 */
export function formatPendingSummary(data: PendingItems): string {
  const lines = ['*Pendências:*', ''];

  if (data.toApprove.length > 0) {
    lines.push(`*Aguardando aprovação (${data.toApprove.length}):*`);
    data.toApprove.slice(0, 5).forEach((order) => {
      lines.push(`• OS #${order.number} - ${order.customer?.name || 'Cliente'}`);
    });
    if (data.toApprove.length > 5) {
      lines.push(`  ...e mais ${data.toApprove.length - 5}`);
    }
    lines.push('');
  }

  if (data.dueToday.length > 0) {
    lines.push(`*Para entregar hoje (${data.dueToday.length}):*`);
    data.dueToday.slice(0, 5).forEach((order) => {
      lines.push(`• OS #${order.number} - ${order.customer?.name || 'Cliente'}`);
    });
    if (data.dueToday.length > 5) {
      lines.push(`  ...e mais ${data.dueToday.length - 5}`);
    }
    lines.push('');
  }

  if (data.unpaid.length > 0) {
    lines.push(`*A receber (${data.unpaid.length}):*`);
    data.unpaid.slice(0, 5).forEach((order) => {
      lines.push(
        `• OS #${order.number} - ${formatCurrency(order.remainingBalance || 0)}`
      );
    });
    if (data.unpaid.length > 5) {
      lines.push(`  ...e mais ${data.unpaid.length - 5}`);
    }
    lines.push('');
  }

  if (data.overdue.length > 0) {
    lines.push(`*Atrasadas (${data.overdue.length}):*`);
    data.overdue.slice(0, 5).forEach((order) => {
      lines.push(
        `• OS #${order.number} - ${order.daysOverdue} dias de atraso`
      );
    });
    if (data.overdue.length > 5) {
      lines.push(`  ...e mais ${data.overdue.length - 5}`);
    }
  }

  if (
    data.toApprove.length === 0 &&
    data.dueToday.length === 0 &&
    data.unpaid.length === 0 &&
    data.overdue.length === 0
  ) {
    lines.push('Nenhuma pendência no momento!');
  }

  return lines.join('\n');
}

/**
 * Format order details for WhatsApp message
 */
export function formatOrderDetails(order: Order): string {
  const lines = [
    `*OS #${order.number}*`,
    '',
    `*Cliente:* ${order.customer?.name || 'Não informado'}`,
  ];

  if (order.device?.name) {
    lines.push(`*Dispositivo:* ${order.device.name}`);
  }

  lines.push(`*Status:* ${formatStatus(order.status)}`);
  lines.push(`*Total:* ${formatCurrency(order.total)}`);

  if (order.paidAmount > 0) {
    lines.push(`*Pago:* ${formatCurrency(order.paidAmount)}`);
    const remaining = order.total - order.discount - order.paidAmount;
    if (remaining > 0) {
      lines.push(`*Restante:* ${formatCurrency(remaining)}`);
    }
  }

  if (order.dueDate) {
    const dueDate = toDate(order.dueDate);
    if (dueDate) {
      lines.push(`*Previsão:* ${formatDate(dueDate)}`);
    }
  }

  return lines.join('\n');
}

/**
 * Format order status for display
 */
export function formatStatus(status: string): string {
  const statusMap: Record<string, string> = {
    quote: 'Orçamento',
    approved: 'Aprovado',
    progress: 'Em andamento',
    done: 'Concluído',
    canceled: 'Cancelado',
  };
  return statusMap[status] || status;
}

/**
 * Truncate string with ellipsis
 */
export function truncate(str: string, maxLength: number): string {
  if (str.length <= maxLength) return str;
  return str.slice(0, maxLength - 3) + '...';
}

/**
 * Format status update message for WhatsApp
 */
export function formatStatusUpdate(
  orderNumber: number,
  oldStatus: string,
  newStatus: string
): string {
  return [
    `*OS #${orderNumber}* atualizada!`,
    '',
    `${formatStatus(oldStatus)} ➜ ${formatStatus(newStatus)}`,
  ].join('\n');
}

/**
 * Format financial summary for WhatsApp message
 */
export function formatFinancialSummary(data: {
  period: string;
  total: number;
  paid: number;
  unpaid: number;
  discount: number;
  ordersCount: number;
}): string {
  const lines = [
    `*Faturamento - ${data.period}*`,
    '',
    `📊 ${data.ordersCount} OS no período`,
    '',
    `💰 *Total:* ${formatCurrency(data.total)}`,
    `✅ *Recebido:* ${formatCurrency(data.paid)}`,
  ];

  if (data.discount > 0) {
    lines.push(`🏷️ *Descontos:* ${formatCurrency(data.discount)}`);
  }

  if (data.unpaid > 0) {
    lines.push(`⏳ *A Receber:* ${formatCurrency(data.unpaid)}`);
  }

  return lines.join('\n');
}

/**
 * Format catalog search results for WhatsApp message
 */
export function formatCatalogResults(
  query: string,
  services: Array<{ name: string; value: number }>,
  products: Array<{ name: string; value: number }>
): string {
  const lines = [`*Resultados para "${query}":*`, ''];

  if (services.length > 0) {
    lines.push('*Serviços:*');
    services.slice(0, 5).forEach((s) => {
      lines.push(`• ${s.name}: ${formatCurrency(s.value)}`);
    });
    if (services.length > 5) {
      lines.push(`  ...e mais ${services.length - 5}`);
    }
    lines.push('');
  }

  if (products.length > 0) {
    lines.push('*Produtos:*');
    products.slice(0, 5).forEach((p) => {
      lines.push(`• ${p.name}: ${formatCurrency(p.value)}`);
    });
    if (products.length > 5) {
      lines.push(`  ...e mais ${products.length - 5}`);
    }
  }

  if (services.length === 0 && products.length === 0) {
    lines.push('Nenhum resultado encontrado.');
  }

  return lines.join('\n');
}

/**
 * Format catalog list for WhatsApp message (when listing without search query)
 */
export function formatCatalogList(
  type: string,
  services: Array<{ name: string; value: number }>,
  products: Array<{ name: string; value: number }>
): string {
  const lines: string[] = [];

  if (type === 'service' || type === 'all') {
    if (services.length > 0) {
      lines.push(`*Serviços (${services.length}):*`);
      services.forEach((s) => {
        lines.push(`• ${s.name}: ${formatCurrency(s.value)}`);
      });
    } else {
      lines.push('Nenhum serviço cadastrado.');
    }
  }

  if (type === 'product' || type === 'all') {
    if (lines.length > 0 && (type === 'all')) {
      lines.push('');
    }
    if (products.length > 0) {
      lines.push(`*Produtos (${products.length}):*`);
      products.forEach((p) => {
        lines.push(`• ${p.name}: ${formatCurrency(p.value)}`);
      });
    } else {
      lines.push('Nenhum produto cadastrado.');
    }
  }

  return lines.join('\n');
}

/**
 * Get period label in Portuguese
 */
export function getPeriodLabel(period: string): string {
  const now = new Date();
  const monthNames = [
    'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
    'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'
  ];

  switch (period) {
    case 'today':
      return 'Hoje';
    case 'week':
      return 'Esta Semana';
    case 'month':
      return monthNames[now.getMonth()];
    case 'year':
      return String(now.getFullYear());
    default:
      return period;
  }
}

/**
 * Get current month label in Portuguese
 */
export function formatCurrentMonthLabel(): string {
  const now = new Date();
  const monthNames = [
    'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
    'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'
  ];
  return `${monthNames[now.getMonth()]} ${now.getFullYear()}`;
}

/**
 * Format date range label in Portuguese
 * Adapts the label based on whether it's a single day, same month, or cross-month range
 */
export function formatDateRangeLabel(start: Date, end: Date): string {
  const monthNames = [
    'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
    'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'
  ];

  const sameDay = start.toDateString() === end.toDateString();
  const sameMonth = start.getMonth() === end.getMonth() &&
                    start.getFullYear() === end.getFullYear();

  // Check if it's a full month (first to last day)
  const isFullMonth = sameMonth &&
                      start.getDate() === 1 &&
                      end.getDate() === new Date(end.getFullYear(), end.getMonth() + 1, 0).getDate();

  if (sameDay) {
    return formatDate(start);
  }

  if (isFullMonth) {
    return `${monthNames[start.getMonth()]} ${start.getFullYear()}`;
  }

  if (sameMonth) {
    return `${start.getDate()} a ${end.getDate()} de ${monthNames[start.getMonth()]} ${start.getFullYear()}`;
  }

  return `${formatDate(start)} - ${formatDate(end)}`;
}

// ============================================================================
// Bot Order Management Formatting
// ============================================================================

export interface CreatedEntities {
  customer?: boolean;
  device?: boolean;
  services?: string[];
  products?: string[];
}

/**
 * Format order creation message for WhatsApp
 */
export function formatOrderCreated(order: Order, created: CreatedEntities): string {
  const lines = [
    `*OS #${order.number} criada!*`,
    '',
  ];

  lines.push(`*Cliente:* ${order.customer?.name || 'Não informado'}`);

  if (order.device?.name) {
    lines.push(`*Dispositivo:* ${order.device.name}`);
  }

  lines.push(`*Status:* ${formatStatus(order.status)}`);

  // Services
  if (order.services && order.services.length > 0) {
    lines.push('');
    lines.push(`*Serviços (${order.services.length}):*`);
    order.services.forEach((s) => {
      lines.push(`• ${s.service?.name || s.description}: ${formatCurrency(s.value)}`);
    });
  }

  // Products
  if (order.products && order.products.length > 0) {
    lines.push('');
    lines.push(`*Produtos (${order.products.length}):*`);
    order.products.forEach((p) => {
      const qty = p.quantity > 1 ? ` (x${p.quantity})` : '';
      lines.push(`• ${p.product?.name || p.description}: ${formatCurrency(p.value)}${qty}`);
    });
  }

  lines.push('');
  lines.push(`*Total:* ${formatCurrency(order.total)}`);

  // Created entities info
  const createdItems: string[] = [];
  if (created.customer) createdItems.push('cliente');
  if (created.device) createdItems.push('dispositivo');
  if (created.services && created.services.length > 0) {
    createdItems.push(`${created.services.length} serviço(s)`);
  }
  if (created.products && created.products.length > 0) {
    createdItems.push(`${created.products.length} produto(s)`);
  }

  if (createdItems.length > 0) {
    lines.push('');
    lines.push(`_Criados: ${createdItems.join(', ')}_`);
  }

  return lines.join('\n');
}

/**
 * Format service added message for WhatsApp
 */
export function formatServiceAdded(
  orderNumber: number,
  serviceName: string,
  value: number,
  newTotal: number
): string {
  return [
    `*Serviço adicionado à OS #${orderNumber}!*`,
    '',
    `• ${serviceName}: ${formatCurrency(value)}`,
    '',
    `*Novo total:* ${formatCurrency(newTotal)}`,
  ].join('\n');
}

/**
 * Format product added message for WhatsApp
 */
export function formatProductAdded(
  orderNumber: number,
  productName: string,
  value: number,
  quantity: number,
  newTotal: number
): string {
  const qty = quantity > 1 ? ` (x${quantity})` : '';
  return [
    `*Produto adicionado à OS #${orderNumber}!*`,
    '',
    `• ${productName}: ${formatCurrency(value)}${qty}`,
    '',
    `*Novo total:* ${formatCurrency(newTotal)}`,
  ].join('\n');
}

/**
 * Format service removed message for WhatsApp
 */
export function formatServiceRemoved(
  orderNumber: number,
  serviceName: string,
  newTotal: number
): string {
  return [
    `*Serviço removido da OS #${orderNumber}!*`,
    '',
    `Removido: ${serviceName}`,
    '',
    `*Novo total:* ${formatCurrency(newTotal)}`,
  ].join('\n');
}

/**
 * Format product removed message for WhatsApp
 */
export function formatProductRemoved(
  orderNumber: number,
  productName: string,
  newTotal: number
): string {
  return [
    `*Produto removido da OS #${orderNumber}!*`,
    '',
    `Removido: ${productName}`,
    '',
    `*Novo total:* ${formatCurrency(newTotal)}`,
  ].join('\n');
}

/**
 * Format full order details for WhatsApp
 */
export function formatOrderFullDetails(order: Order): string {
  const lines = [
    `*OS #${order.number}*`,
    '',
    `*Cliente:* ${order.customer?.name || 'Não informado'}`,
  ];

  if (order.customer?.phone) {
    lines.push(`*Telefone:* ${formatPhone(order.customer.phone)}`);
  }

  if (order.device?.name) {
    lines.push(`*Dispositivo:* ${order.device.name}`);
    if (order.device.serial) {
      lines.push(`*Serial:* ${order.device.serial}`);
    }
  }

  lines.push(`*Status:* ${formatStatus(order.status)}`);

  // Services
  if (order.services && order.services.length > 0) {
    lines.push('');
    lines.push(`*Serviços (${order.services.length}):*`);
    order.services.forEach((s, i) => {
      lines.push(`${i + 1}. ${s.service?.name || s.description}: ${formatCurrency(s.value)}`);
    });
  } else {
    lines.push('');
    lines.push('*Serviços:* Nenhum');
  }

  // Products
  if (order.products && order.products.length > 0) {
    lines.push('');
    lines.push(`*Produtos (${order.products.length}):*`);
    order.products.forEach((p, i) => {
      const qty = p.quantity > 1 ? ` (x${p.quantity})` : '';
      const subtotal = p.value * (p.quantity || 1);
      lines.push(`${i + 1}. ${p.product?.name || p.description}: ${formatCurrency(p.value)}${qty} = ${formatCurrency(subtotal)}`);
    });
  } else {
    lines.push('');
    lines.push('*Produtos:* Nenhum');
  }

  // Totals
  lines.push('');
  lines.push(`*Total:* ${formatCurrency(order.total)}`);

  if (order.discount > 0) {
    lines.push(`*Desconto:* ${formatCurrency(order.discount)}`);
  }

  if (order.paidAmount > 0) {
    lines.push(`*Pago:* ${formatCurrency(order.paidAmount)}`);
    const remaining = order.total - order.discount - order.paidAmount;
    if (remaining > 0) {
      lines.push(`*A receber:* ${formatCurrency(remaining)}`);
    }
  }

  if (order.dueDate) {
    const dueDate = toDate(order.dueDate);
    if (dueDate) {
      lines.push(`*Previsão:* ${formatDate(dueDate)}`);
    }
  }

  return lines.join('\n');
}

/**
 * Format device updated message for WhatsApp
 */
export function formatDeviceUpdated(
  orderNumber: number,
  deviceName: string
): string {
  return [
    `*Dispositivo atualizado na OS #${orderNumber}!*`,
    '',
    `*Novo dispositivo:* ${deviceName}`,
  ].join('\n');
}

/**
 * Format customer updated message for WhatsApp
 */
export function formatCustomerUpdated(
  orderNumber: number,
  customerName: string
): string {
  return [
    `*Cliente atualizado na OS #${orderNumber}!*`,
    '',
    `*Novo cliente:* ${customerName}`,
  ].join('\n');
}

// ============================================================================
// Photo Management Formatting
// ============================================================================

/**
 * Format photo added message for WhatsApp
 */
export function formatPhotoAdded(orderNumber: number, totalPhotos: number): string {
  return `Foto adicionada à OS #${orderNumber}! (${totalPhotos} foto${totalPhotos > 1 ? 's' : ''} no total)`;
}

/**
 * Format photos list message for WhatsApp
 */
export function formatPhotosList(
  orderNumber: number,
  photos: Array<{ id: string; url: string; createdAt?: unknown; createdBy?: { name?: string } }>
): string {
  if (photos.length === 0) {
    return `*OS #${orderNumber}*\n\nNenhuma foto anexada.`;
  }

  const lines = [
    `*OS #${orderNumber} - Fotos (${photos.length}):*`,
    '',
  ];

  photos.forEach((photo, index) => {
    lines.push(`${index + 1}. ${photo.url}`);
    if (photo.createdBy?.name) {
      lines.push(`   _Por: ${photo.createdBy.name}_`);
    }
  });

  return lines.join('\n');
}

/**
 * Format photo deleted message for WhatsApp
 */
export function formatPhotoDeleted(orderNumber: number, remainingPhotos: number): string {
  if (remainingPhotos === 0) {
    return `Foto removida da OS #${orderNumber}!\n\nNenhuma foto restante.`;
  }
  return `Foto removida da OS #${orderNumber}!\n\n${remainingPhotos} foto${remainingPhotos > 1 ? 's' : ''} restante${remainingPhotos > 1 ? 's' : ''}.`;
}
