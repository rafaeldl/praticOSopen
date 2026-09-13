import React from 'react';
import { createRoot } from 'react-dom/client';
import { callTool, connect, onHostContext, onToolResult } from './bridge';
import {
  applyStatusResult,
  availableActions,
  receiveOrder,
  writeFailed,
  CardMessage,
  OrderData,
  PendingWrite,
} from './card-state';
import { applyHostTheme, mergeHostContext, HostContext } from './host-theme';

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
  border: '1px solid var(--color-border-primary)',
  background: 'transparent',
  color: 'inherit',
  fontFamily: 'inherit',
  cursor: 'pointer',
};

export function OrderCard({ order: incomingOrder }: { order: OrderData }) {
  // The card owns its current order: a successful write replaces it (see
  // confirmStatus/applyStatusResult), so the badge and the button set reflect
  // the latest known state instead of going stale after an approve/done. The
  // App component below remounts this component (via `key={order.number}`)
  // whenever a genuinely different order arrives.
  const [order, setOrder] = React.useState<OrderData>(incomingOrder);
  const [pending, setPending] = React.useState<PendingWrite>(null);
  const [busy, setBusy] = React.useState(false);
  const [message, setMessage] = React.useState<CardMessage | null>(null);
  const [showLink, setShowLink] = React.useState(false);

  // A new tool result for the SAME order (e.g. the model changed the status
  // from the chat) keeps the key, so there is no remount: fold it into the
  // local state here, during render, so the stale order is never painted.
  // What survives the update is decided by receiveOrder.
  const [seenOrder, setSeenOrder] = React.useState<OrderData>(incomingOrder);
  if (incomingOrder !== seenOrder) {
    setSeenOrder(incomingOrder);
    const next = receiveOrder({ order, pending, message }, incomingOrder);
    setOrder(next.order);
    setPending(next.pending);
    setMessage(next.message);
  }

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
  // buttons stay available so the user can retry. The order is read through
  // the functional update: a tool result for this order may have arrived
  // while the call was in flight, and `order` in this closure predates it.
  const confirmStatus = async (requestedStatus: 'done' | 'approved') => {
    if (!order.number || busy) return;
    setBusy(true);
    try {
      const result = await callTool('update_order_status', {
        orderNumber: order.number,
        status: requestedStatus,
      });
      const outcome = applyStatusResult(order, result, requestedStatus);
      setOrder((current) => applyStatusResult(current, result, requestedStatus).order);
      setMessage({ text: outcome.message, error: Boolean(outcome.error) });
    } catch {
      // writeFailed leaves the order as it is, so only the message changes.
      setMessage({ text: writeFailed(order).message, error: true });
    } finally {
      setBusy(false);
      setPending(null);
    }
  };

  return (
    <div style={{
      border: '1px solid var(--color-border-secondary)',
      borderRadius: 12,
      padding: 16,
      maxWidth: 460,
    }}>
      {order.coverPhotoUrl && (
        <div style={{
          marginBottom: 12,
          borderRadius: 8,
          overflow: 'hidden',
          maxHeight: 180,
          border: '1px solid var(--color-border-tertiary)',
        }}>
          <img
            src={order.coverPhotoUrl}
            alt="Foto da OS"
            style={{
              width: '100%',
              maxHeight: 180,
              objectFit: 'cover',
              display: 'block',
            }}
          />
        </div>
      )}

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
        <div style={{ marginTop: 12, borderTop: '1px solid var(--color-border-tertiary)', paddingTop: 8 }}>
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
        borderTop: '1px solid var(--color-border-tertiary)',
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
          <span style={{ fontSize: 13, color: message.error ? 'var(--color-text-danger)' : 'inherit' }}>{message.text}</span>
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
    // Theme: the initial hostContext, then partial host-context-changed
    // updates merged into it. Fallbacks live in the resource HTML's :root.
    let hostContext: HostContext = {};
    let appliedVariables: string[] = [];
    onHostContext((update) => {
      hostContext = mergeHostContext(hostContext, update);
      appliedVariables = applyHostTheme(document.documentElement.style, hostContext, appliedVariables);
    });
    onToolResult((result) => setOrder(result?.structuredContent?.order ?? null));
    connect().catch(() => {
      // The host answered ui/initialize with a JSON-RPC error, so no tool
      // result will follow and the card stays empty; the chat still has the
      // tool's text. (A host without MCP Apps never runs this View at all,
      // and one that never answers leaves this promise pending, not rejected.)
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
