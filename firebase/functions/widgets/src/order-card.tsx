import React from 'react';
import { createRoot } from 'react-dom/client';
import { callTool, connect, onHostContext, onToolResult, openLink } from './bridge';
import { applyStatusResult, availableActions, receiveOrder } from './card-state';
import type { CardMessage, OrderData, PendingWrite } from './card-state';
import { applyHostTheme, mergeHostContext } from './host-theme';
import type { HostContext } from './host-theme';
import { cardLocale, formatMoney, statusLabel, shareData } from './card-locale';
import { CardIcon } from './card-icon';
import './card.css';

export type { OrderData };

export function OrderCard({ order: incomingOrder, locale = 'pt-BR' }: {
  readonly order: OrderData; readonly locale?: string;
}) {
  const { labels, locale: resolvedLocale } = cardLocale(locale);
  const [order, setOrder] = React.useState(incomingOrder);
  const [pending, setPending] = React.useState<PendingWrite>(null);
  const [busy, setBusy] = React.useState(false);
  const [sharing, setSharing] = React.useState(false);
  const [message, setMessage] = React.useState<CardMessage | null>(null);
  const [showLink, setShowLink] = React.useState(false);
  const [showDestinations, setShowDestinations] = React.useState(false);
  const [failedPhoto, setFailedPhoto] = React.useState<string | null>(null);
  const [seenOrder, setSeenOrder] = React.useState(incomingOrder);
  if (incomingOrder !== seenOrder) {
    setSeenOrder(incomingOrder);
    const next = receiveOrder({ order, pending, message }, incomingOrder);
    setOrder(next.order);
    setPending(next.pending);
    setMessage(next.message);
  }
  const [seenLocale, setSeenLocale] = React.useState(resolvedLocale);
  if (seenLocale !== resolvedLocale) {
    setSeenLocale(resolvedLocale);
    setMessage(null);
  }
  const actions = availableActions(order);
  const photo = order.coverPhotoUrl && order.coverPhotoUrl !== failedPhoto ? order.coverPhotoUrl : null;
  const sharePayload = shareData(order, resolvedLocale);

  const copyLink = async () => {
    if (!order.shareUrl) return;
    try {
      await navigator.clipboard.writeText(order.shareUrl);
      setMessage({ text: labels.copied, error: false });
      setShowLink(false);
    } catch {
      setShowLink(true);
    }
  };
  const openOrder = async () => {
    if (!order.shareUrl) return;
    try {
      await openLink(order.shareUrl);
    } catch {
      setMessage({ text: labels.openFailed, error: true });
      setShowLink(true);
    }
  };
  const share = async () => {
    if (!sharePayload || sharing) return;
    setSharing(true);
    setMessage(null);
    try {
      if (typeof navigator.share === 'function') {
        await navigator.share(sharePayload);
      } else {
        setShowDestinations(true);
      }
    } catch (error) {
      if (error instanceof DOMException && error.name === 'AbortError') return;
      setShowDestinations(true);
    } finally {
      setSharing(false);
    }
  };
  const shareTo = async (destination: 'whatsapp' | 'telegram') => {
    if (!sharePayload) return;
    const url = destination === 'whatsapp'
      ? `https://wa.me/?text=${encodeURIComponent(`${sharePayload.text}\n${sharePayload.url}`)}`
      : `https://t.me/share/url?url=${encodeURIComponent(sharePayload.url)}&text=${encodeURIComponent(sharePayload.text)}`;
    try {
      await openLink(url);
    } catch {
      setMessage({ text: labels.shareFailed, error: true });
    }
  };
  const confirmStatus = async (requestedStatus: 'done' | 'approved') => {
    if (!order.number || busy) return;
    setBusy(true);
    try {
      const result = await callTool('update_order_status', { orderNumber: order.number, status: requestedStatus });
      const outcome = applyStatusResult(order, result, requestedStatus);
      setOrder(current => applyStatusResult(current, result, requestedStatus).order);
      setMessage({ text: outcome.error ? labels.failed : statusLabel(outcome.order.status, labels), error: Boolean(outcome.error) });
    } catch {
      setMessage({ text: labels.failed, error: true });
    } finally {
      setBusy(false);
      setPending(null);
    }
  };
  return (
    <article className="order-card" lang={resolvedLocale} aria-label={`${labels.order} #${order.number ?? '—'}`}>
      <header className="card-header">
        <h2>{labels.order} #{order.number ?? '—'}</h2>
        <span className="card-status" data-status={order.status}>{statusLabel(order.status, labels)}</span>
      </header>
      {(photo || order.customer?.name || Boolean(order.devices?.length)) && <div className="card-identity">
        {photo && <img className="card-photo" src={photo} alt={labels.photo} width="140" height="140"
          onError={() => setFailedPhoto(photo)} />}
        <div className="card-details">
          {(order.devices ?? []).map((device, index) => <div className="card-device" key={index}>
            {device.name && <strong>{device.name}</strong>}
            {device.serial && <span className="card-serial">{device.serial}</span>}
          </div>)}
          {order.customer?.name && <p className="card-customer"><CardIcon name="person" /><span>{order.customer.name}</span></p>}
        </div>
      </div>}
      {[{ title: labels.services, items: order.services }, { title: labels.products, items: order.products }].map(group =>
        Boolean(group.items?.length) && <section className="card-items" key={group.title}>
          <h3>{group.title}</h3>
          {group.items?.map((item, index) => <div className="card-price-row" key={index}>
            <span>{item.name}{item.quantity && item.quantity > 1 ? ` ×${new Intl.NumberFormat(resolvedLocale).format(item.quantity)}` : ''}</span>
            <span className="card-price">{formatMoney(item.value, resolvedLocale)}</span>
          </div>)}
        </section>)}
      <div className="card-total"><span>{labels.total}</span><span className="card-price">{formatMoney(order.total, resolvedLocale)}</span></div>
      <div className="card-actions">
        {sharePayload && <button type="button" className="card-button card-button-primary" onClick={share} disabled={sharing}>
          <CardIcon name="share" />{sharing ? labels.opening : labels.share}
        </button>}
        {showDestinations && <section className="card-confirmation" aria-label={labels.chooseDestination}>
          <p>{labels.chooseDestination}</p>
          <div className="card-secondary">
            <button type="button" className="card-button" onClick={() => shareTo('whatsapp')}>WhatsApp</button>
            <button type="button" className="card-button" onClick={() => shareTo('telegram')}>Telegram</button>
            <button type="button" className="card-button" onClick={copyLink}>{labels.copyLink}</button>
            <button type="button" className="card-button" onClick={() => setShowDestinations(false)}>{labels.cancel}</button>
          </div>
        </section>}
        <div className="card-secondary">
          {actions.copyLink && <button type="button" className="card-button" onClick={openOrder}><CardIcon name="link" />{labels.copy}</button>}
          {pending === null && actions.markDone && <button type="button" className="card-button" onClick={() => setPending('done')}><CardIcon name="check" />{labels.complete}</button>}
          {pending === null && actions.approve && <button type="button" className="card-button" onClick={() => setPending('approved')}><CardIcon name="check" />{labels.approve}</button>}
        </div>
        {pending !== null && <div className="card-confirmation" aria-busy={busy}>
          <p>{pending === 'done' ? labels.confirmDone : labels.confirmApproved}</p>
          <div className="card-secondary">
            <button type="button" className="card-button" disabled={busy} onClick={() => confirmStatus(pending)}>{busy ? labels.saving : labels.confirm}</button>
            <button type="button" className="card-button" disabled={busy} onClick={() => setPending(null)}>{labels.cancel}</button>
          </div>
        </div>}
        <div role="status" aria-live="polite">
          {message && <p className="card-feedback" data-error={message.error}>{message.text}</p>}
          {showLink && order.shareUrl && <div className="card-confirmation"><p className="card-feedback">{labels.manualCopy}<span className="card-manual-link">{order.shareUrl}</span></p><button type="button" className="card-button" onClick={copyLink}>{labels.copyLink}</button></div>}
        </div>
      </div>
    </article>
  );
}

function App() {
  const [order, setOrder] = React.useState<OrderData | null>(null);
  const [locale, setLocale] = React.useState(navigator.language);
  React.useEffect(() => {
    let hostContext: HostContext = {};
    let appliedVariables: string[] = [];
    onHostContext(update => {
      hostContext = mergeHostContext(hostContext, update);
      appliedVariables = applyHostTheme(document.documentElement.style, hostContext, appliedVariables);
      if (typeof hostContext.locale === 'string') setLocale(hostContext.locale);
    });
    onToolResult(result => setOrder(result?.structuredContent?.order ?? null));
    connect().catch(() => {
      // Hosts without MCP Apps keep the tool's standalone text response.
    });
  }, []);
  return order ? <OrderCard key={order.number} order={order} locale={locale} /> : null;
}
const root = document.getElementById('root');
if (root) createRoot(root).render(<App />);
