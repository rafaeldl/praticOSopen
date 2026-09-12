import React from 'react';
import { createRoot } from 'react-dom/client';
import { callTool, connect, onToolResult } from './bridge';

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

const btnStyle: React.CSSProperties = {
  fontSize: 13,
  padding: '6px 12px',
  borderRadius: 8,
  border: '1px solid rgba(128,128,128,0.35)',
  background: 'transparent',
  color: 'inherit',
  cursor: 'pointer',
};

export function OrderCard({ order }: { order: OrderData }) {
  const status = STATUS[order.status ?? ''] ?? { label: order.status ?? '—', color: '#8E8E93' };
  const items = [...(order.services ?? []), ...(order.products ?? [])];

  const [pending, setPending] = React.useState<'done' | 'approved' | null>(null);
  const [busy, setBusy] = React.useState(false);
  const [done, setDone] = React.useState<string | null>(null);
  const [showLink, setShowLink] = React.useState(false);

  // The sandboxed frame may not grant clipboard access; feature-detect and
  // fall back to showing the link for manual copy (spec ext-apps 2026-01-26,
  // l.171: apps must not assume permissions).
  const copyLink = async () => {
    if (!order.shareUrl) return;
    try {
      await navigator.clipboard.writeText(order.shareUrl);
      setDone('Link copiado');
    } catch {
      setShowLink(true);
    }
  };

  // A click that writes skips the confirmation the chat normally gives, so
  // every write goes through an explicit confirm state first.
  const confirmStatus = async (status: 'done' | 'approved') => {
    if (!order.number) return;
    setBusy(true);
    try {
      const result = await callTool('update_order_status', {
        orderNumber: order.number,
        status,
      });
      setDone(result?.isError ? 'Não foi possível atualizar' : status === 'done' ? 'Concluída' : 'Aprovada');
    } catch {
      setDone('Não foi possível atualizar');
    } finally {
      setBusy(false);
      setPending(null);
    }
  };

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

      <div style={{ marginTop: 12, display: 'flex', gap: 8, flexWrap: 'wrap' }}>
        {done && <span style={{ fontSize: 13 }}>{done}</span>}

        {showLink && order.shareUrl && (
          <span style={{ fontSize: 12, userSelect: 'all', wordBreak: 'break-all' }}>{order.shareUrl}</span>
        )}

        {!done && pending === null && (
          <>
            {order.shareUrl && (
              <button onClick={copyLink} style={btnStyle}>Copiar link do cliente</button>
            )}
            {order.status !== 'done' && order.status !== 'canceled' && (
              <button onClick={() => setPending('done')} style={btnStyle}>Marcar como concluída</button>
            )}
            {order.status === 'quote' && (
              <button onClick={() => setPending('approved')} style={btnStyle}>Aprovar</button>
            )}
          </>
        )}

        {!done && pending !== null && (
          <>
            <span style={{ fontSize: 13, alignSelf: 'center' }}>
              {pending === 'done' ? 'Concluir esta OS?' : 'Aprovar esta OS?'}
            </span>
            <button disabled={busy} onClick={() => confirmStatus(pending)} style={btnStyle}>
              {busy ? '...' : 'Confirmar'}
            </button>
            <button disabled={busy} onClick={() => setPending(null)} style={btnStyle}>Cancelar</button>
          </>
        )}
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
