/**
 * Bot Response Utilities
 * Shared helper to build full order detail responses for bot endpoints
 */

import * as shareTokenService from '../services/share-token.service';
import { getFormatContext } from './format.utils';

export interface OrderDetailService {
  name: string;
  value: number;
  deviceId: string | null;
}

export interface OrderDetailProduct {
  name: string;
  quantity: number;
  value: number;
  deviceId: string | null;
}

export interface OrderDetailDevice {
  name: string;
  serial?: string;
}

export interface OrderDetailCustomer {
  name: string;
  phone?: string;
}

export interface OrderDetail {
  number: number;
  status: string;
  customer: OrderDetailCustomer | null;
  device: OrderDetailDevice | null;
  devices: OrderDetailDevice[];
  deviceCount: number;
  services?: OrderDetailService[];
  products?: OrderDetailProduct[];
  total: number;
  discount?: number;
  paidAmount?: number;
  dueDate?: string;
  scheduledDate?: string;
  createdAt: string;
  rating?: number;
  photosCount: number;
  mainPhotoUrl: string | null;
  coverPhotoUrl?: string | null;
  shareUrl: string | null;
}

export interface OrderDetailResponse {
  order: OrderDetail;
  formatContext: {
    country: string;
    locale: string;
    currency: string;
  };
}

/**
 * Build a full order detail payload (same format as GET /details).
 * Used by all mutation endpoints so the bot LLM can render the card
 * without a follow-up GET /details call.
 */
export async function buildOrderDetail(
  order: any,
  companyId: string,
  companyCountry?: string,
  createdBy?: any
): Promise<OrderDetailResponse> {
  const photosCount = order.photos?.length || 0;
  const mainPhotoUrl = photosCount > 0
    ? `/bot/orders/${order.number}/photos/${order.photos![0].id}`
    : null;
  const coverPhotoUrl = photosCount > 0
    ? (order.photos![0]?.url || null)
    : null;

  // Fetch active share token; auto-create if customer exists and no active token
  const baseUrl = process.env.SHARE_BASE_URL || 'https://praticos.web.app';
  let shareUrl: string | null = null;
  const tokens = await shareTokenService.getTokensForOrder(order.id, companyId);
  const activeToken = tokens.find((t: any) => new Date(t.expiresAt) > new Date());
  if (activeToken) {
    shareUrl = `${baseUrl}/q/${activeToken.token}`;
  } else if (order.customer && createdBy) {
    try {
      const newToken = await shareTokenService.generateShareToken(
        order.id, companyId, order.customer,
        ['view', 'approve', 'comment'], createdBy, 30
      );
      shareUrl = `${baseUrl}/q/${newToken.token}`;
    } catch (e) {
      // Non-critical: share link creation failed, continue without it
      console.warn('[BOT] Auto-create share link failed:', e);
    }
  }

  return {
    order: {
      number: order.number,
      status: order.status,
      customer: order.customer ? { name: order.customer.name, phone: order.customer.phone } : null,
      device: order.device ? { name: order.device.name, serial: order.device.serial } : null,
      devices: order.devices?.map((d: any) => ({ name: d.name, serial: d.serial })) || (order.device ? [{ name: order.device.name, serial: order.device.serial }] : []),
      deviceCount: order.devices?.length || (order.device ? 1 : 0),
      services: order.services?.map((s: any) => ({
        name: s.service?.name || s.description,
        value: s.value,
        deviceId: s.deviceId || null,
      })),
      products: order.products?.map((p: any) => ({
        name: p.product?.name || p.description,
        quantity: p.quantity,
        value: p.value,
        deviceId: p.deviceId || null,
      })),
      total: order.total,
      discount: order.discount,
      paidAmount: order.paidAmount,
      dueDate: order.dueDate,
      scheduledDate: order.scheduledDate,
      createdAt: order.createdAt,
      rating: order.rating,
      photosCount,
      mainPhotoUrl,
      coverPhotoUrl,
      shareUrl,
    },
    formatContext: getFormatContext(companyCountry),
  };
}
