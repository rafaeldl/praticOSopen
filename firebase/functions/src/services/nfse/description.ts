/**
 * Description and complementary information of a direct nota (spec §4.4).
 *
 * - Each service becomes the catalog name + its detail, without words the
 *   name already has ("Conserto/Pintura de Capô" + "Capo" → the name alone).
 * - Services of one order are joined by the emitter's separator; several
 *   orders give one line per order ("OS 182: ...").
 * - The emitter's style (uppercase or not) was learned from its old notas.
 * - xInfComp is always "OS 182 · Emitida pelo PraticOS (praticos.app)".
 */

import type { FiscalDescriptionStyle } from '../../models/nfse-direct.types';
import type { Order, OrderService } from '../../models/types';

export const DEFAULT_DESCRIPTION_STYLE: FiscalDescriptionStyle = { uppercase: false, separator: ', ' };

const fold = (text: string) =>
  text
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .toLowerCase();

const words = (text: string) => fold(text).split(/[^a-z0-9]+/).filter((w) => w.length > 0);

/** "name - detail", dropping the detail's words the name already has. */
export function serviceText(service: Pick<OrderService, 'service' | 'description'>): string {
  const name = (service.service?.name ?? '').trim();
  const detail = (service.description ?? '').trim();
  if (!name) return detail;
  if (!detail) return name;
  const known = new Set(words(name));
  const extra = detail
    .split(/\s+/)
    .filter((word) => words(word).some((w) => !known.has(w)))
    .join(' ')
    .trim();
  return extra ? `${name} - ${extra}` : name;
}

function styled(text: string, style: FiscalDescriptionStyle): string {
  return style.uppercase ? text.toLocaleUpperCase('pt-BR') : text;
}

export function describeOrdersForNota(
  orders: Array<Pick<Order, 'number' | 'services'>>,
  style: FiscalDescriptionStyle | null | undefined = DEFAULT_DESCRIPTION_STYLE,
): string {
  const s = style ?? DEFAULT_DESCRIPTION_STYLE;
  const lineOf = (order: Pick<Order, 'services'>) =>
    (order.services ?? [])
      .filter((service) => (Number(service?.value) || 0) > 0 || service?.service?.name)
      .map(serviceText)
      .filter((text) => text.length > 0)
      .join(s.separator || ', ');
  if (orders.length === 1) return styled(lineOf(orders[0]), s);
  return orders
    .map((order) => {
      const line = styled(lineOf(order), s);
      return order.number !== undefined && order.number !== null ? `OS ${order.number}: ${line}` : line;
    })
    .join('\n');
}

/** "OS 182 · Emitida pelo PraticOS (praticos.app)" / "OS 182, 190 · ...". Never optional. */
export function complementaryInfo(orderNumbers: Array<number | null | undefined>): string {
  const known = orderNumbers.filter((n): n is number => typeof n === 'number');
  const prefix = known.length > 0 ? `OS ${known.join(', ')} · ` : '';
  const text = `${prefix}Emitida pelo PraticOS (praticos.app)`;
  return text.length <= 2000 ? text : `OS ${known[0]} e mais ${known.length - 1} · Emitida pelo PraticOS (praticos.app)`;
}
