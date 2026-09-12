import React from 'react';
import { createRoot } from 'react-dom/client';
import { callTool, connect, onToolResult } from './bridge';
import { applyStatusResult, availableActions, writeFailed, OrderData } from './card-state';

export type { OrderData };

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

export function OrderCard({ order: initialOrder }: { order: OrderData }) {
  // The card owns its current order from here on: a successful write
  // replaces it (see confirmStatus/applyStatusResult), so the badge and the
  // button set reflect the latest known state instead of going stale after
  // an approve/done. The App component below remounts this component (via
  // `key={order.number}`) whenever a genuinely different order arrives.
  const [order, setOrder] = React.useState<OrderData>(initialOrder);
  const [pending, setPending] = React.useState<'done' | 'approved' | null>(null);
  const [busy, setBusy] = React.useState(false);
  const [message, setMessage] = React.useState<{ text: string; error: boolean } | null>(null);
  const [showLink, setShowLink] = React.useState(false);

  const status = STATUS[order.status ?? ''] ?? { label: order.status ?? '—', color: '#8E8E93' };
  const items = [...(order.services ?? []), ...(order.products ?? [])];

  // Which buttons show is derived from the current order alone, never from
  // `message` or from whether a previous write succeeded or failed — a
  // failed write must leave every button available to retry, and a
  // successful one must not hide copy-link.
  const actions = availableActions(order);

  // The sandboxed frame may not grant clipboard access; feature-detect and
  // fall back to showing the link for manual copy (spec ext-apps 2026-01-26,
  // l.171: apps must not assume permissions). Read-only, so it never touches
  // the write buttons or the write message.
  const copyLink = async () => {
    if (!order.shareUrl) return;
    try {
      await navigator.clipboard.writeText(order.shareUrl);
      setMessage({ text: 'Link copiado', error: false });
    } catch {
      setShowLink(true);
    }
  };

  // A click that writes skips the confirmation the chat normally gives, so
  // every write goes through an explicit confirm state first. On success the
  // order (and therefore the button set) is refreshed from the tool result;
  // on failure — rejection or `isError` — the order is left untouched and the
  // buttons stay available so the user can retry.
  const confirmStatus = async (requestedStatus: 'done' | 'approved') => {
    if (!order.number || busy) return;
    setBusy(true);
    try {
      const result = await callTool('update_order_status', {
        orderNumber: order.number,
        status: requestedStatus,
      });
      const outcome = applyStatusResult(order, result, requestedStatus);
      setOrder(outcome.order);
      setMessage({ text: outcome.message, error: Boolean(outcome.error) });
    } catch {
      const outcome = writeFailed(order);
      setOrder(outcome.order);
      setMessage({ text: outcome.message, error: true });
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
        {message && (
          <span style={{ fontSize: 13, color: message.error ? '#FF3B30' : 'inherit' }}>{message.text}</span>
        )}

        {showLink && order.shareUrl && (
          <span style={{ fontSize: 12, userSelect: 'all', wordBreak: 'break-all' }}>{order.shareUrl}</span>
        )}

        {pending === null && (
          <>
            {actions.copyLink && (
              <button onClick={copyLink} style={btnStyle}>Copiar link do cliente</button>
            )}
            {actions.markDone && (
              <button onClick={() => setPending('done')} style={btnStyle}>Marcar como concluída</button>
            )}
            {actions.approve && (
              <button onClick={() => setPending('approved')} style={btnStyle}>Aprovar</button>
            )}
          </>
        )}

        {pending !== null && (
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
  // Keyed by order number so a genuinely different order (a later tool call
  // about a different OS) remounts the card instead of reusing the previous
  // order's internal write state.
  return <OrderCard key={order.number} order={order} />;
}

const root = document.getElementById('root');
if (root) createRoot(root).render(<App />);
