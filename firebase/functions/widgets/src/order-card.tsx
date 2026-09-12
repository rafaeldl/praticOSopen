import React from 'react';
import { createRoot } from 'react-dom/client';
import { connect, onToolResult } from './bridge';

interface OrderItem {
  name?: string;
  value?: number;
  quantity?: number;
}

export interface OrderData {
  number?: number;
  status?: string;
  customer?: { name?: string } | null;
  devices?: { name?: string; serial?: string }[];
  services?: OrderItem[];
  products?: OrderItem[];
  total?: number;
  shareUrl?: string | null;
}

// OrderStatus is 'quote' | 'approved' | 'progress' | 'done' | 'canceled'.
const STATUS: Record<string, { label: string; color: string }> = {
  quote: { label: 'Orçamento', color: '#8E8E93' },
  approved: { label: 'Aprovada', color: '#007AFF' },
  progress: { label: 'Em andamento', color: '#FF9500' },
  done: { label: 'Concluída', color: '#34C759' },
  canceled: { label: 'Cancelada', color: '#FF3B30' },
};

const money = (value?: number) =>
  new Intl.NumberFormat('pt-BR', { style: 'currency', currency: 'BRL' }).format(value ?? 0);

export function OrderCard({ order }: { order: OrderData }) {
  const status = STATUS[order.status ?? ''] ?? { label: order.status ?? '—', color: '#8E8E93' };
  const items = [...(order.services ?? []), ...(order.products ?? [])];

  return (
    <div style={{
      fontFamily: 'system-ui, -apple-system, sans-serif',
      border: '1px solid rgba(128,128,128,0.25)',
      borderRadius: 12,
      padding: 16,
      maxWidth: 460,
    }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
        <strong style={{ fontSize: 17 }}>OS #{order.number}</strong>
        <span style={{
          fontSize: 12,
          color: status.color,
          border: `1px solid ${status.color}`,
          borderRadius: 6,
          padding: '2px 8px',
        }}>
          {status.label}
        </span>
      </div>

      {order.customer?.name && (
        <div style={{ marginTop: 8, fontSize: 14 }}>{order.customer.name}</div>
      )}

      {(order.devices ?? []).map((device, i) => (
        <div key={i} style={{ fontSize: 13, opacity: 0.7 }}>
          {device.name}{device.serial ? ` (${device.serial})` : ''}
        </div>
      ))}

      {items.length > 0 && (
        <div style={{ marginTop: 12, borderTop: '1px solid rgba(128,128,128,0.2)', paddingTop: 8 }}>
          {items.map((item, i) => (
            <div key={i} style={{ display: 'flex', justifyContent: 'space-between', fontSize: 13, padding: '2px 0' }}>
              <span>
                {item.name}
                {item.quantity && item.quantity > 1 ? ` x${item.quantity}` : ''}
              </span>
              <span>{money(item.value)}</span>
            </div>
          ))}
        </div>
      )}

      <div style={{
        marginTop: 12,
        borderTop: '1px solid rgba(128,128,128,0.2)',
        paddingTop: 8,
        display: 'flex',
        justifyContent: 'space-between',
        fontWeight: 600,
      }}>
        <span>Total</span>
        <span>{money(order.total)}</span>
      </div>
    </div>
  );
}

function App() {
  const [order, setOrder] = React.useState<OrderData | null>(null);

  React.useEffect(() => {
    onToolResult((result) => setOrder(result?.structuredContent?.order ?? null));
    connect().catch(() => {
      // Host without MCP Apps: the tool's text content is what the user sees.
    });
  }, []);

  if (!order) return null;
  return <OrderCard order={order} />;
}

const root = document.getElementById('root');
if (root) createRoot(root).render(<App />);
