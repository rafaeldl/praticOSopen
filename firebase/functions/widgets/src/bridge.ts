// Minimal MCP Apps bridge (spec ext-apps 2026-01-26).
// The View talks to the host over JSON-RPC via postMessage. The host sends
// nothing until the View completes ui/initialize + notifications/initialized.

import {
  classifyMessage,
  isAcknowledgedHostRequest,
  buildHostRequestReply,
} from './bridge-protocol';

type Pending = { resolve: (value: any) => void; reject: (error: any) => void };

const PROTOCOL_VERSION = '2026-01-26';
const pending = new Map<number, Pending>();
const toolResultListeners: Array<(result: any) => void> = [];
let nextId = 1;

function send(message: Record<string, unknown>): void {
  window.parent.postMessage({ jsonrpc: '2.0', ...message }, '*');
}

function request(method: string, params?: Record<string, unknown>): Promise<any> {
  const id = nextId++;
  send({ id, method, params });
  return new Promise((resolve, reject) => pending.set(id, { resolve, reject }));
}

window.addEventListener('message', (event: MessageEvent) => {
  if (event.source !== window.parent) return;
  const message = event.data;
  const classified = classifyMessage(message, (id) => pending.has(id));

  switch (classified.kind) {
    case 'response': {
      const { resolve, reject } = pending.get(classified.id)!;
      pending.delete(classified.id);
      if (message.error) reject(message.error);
      else resolve(message.result);
      return;
    }
    case 'hostRequest':
      // The host expects a reply to `ping` and `ui/resource-teardown` (the
      // spec says it SHOULD wait for the teardown response before tearing
      // the iframe down); neither carries anything the View needs to act
      // on, so an empty result is the correct acknowledgment.
      if (isAcknowledgedHostRequest(classified.method)) {
        window.parent.postMessage(buildHostRequestReply(classified.id), '*');
      }
      return;
    case 'notification':
      if (classified.method === 'ui/notifications/tool-result') {
        for (const listener of toolResultListeners) listener(classified.params);
      }
      return;
    case 'ignore':
      return;
  }
});

/** Register before connect(): the result can arrive right after the handshake. */
export function onToolResult(listener: (result: any) => void): void {
  toolResultListeners.push(listener);
}

let lastSize: { width: number; height: number } | undefined;

/**
 * Reports the rendered size to the host (spec ext-apps 2026-01-26, l.718 —
 * hosts with flexible dimensions MUST resize the iframe from this
 * notification; l.1204-1217 — the View SHOULD send it when content size
 * changes, via ResizeObserver). Only sent once `initialized` has gone out,
 * and only when width or height actually changed, so a layout pass that
 * doesn't move the box doesn't spam the host with no-op notifications.
 */
function observeSize(): void {
  if (typeof ResizeObserver === 'undefined') return;

  const observer = new ResizeObserver((entries) => {
    const entry = entries[0];
    if (!entry) return;

    const width = Math.round(entry.contentRect.width);
    const height = Math.round(entry.contentRect.height);
    if (lastSize && lastSize.width === width && lastSize.height === height) return;

    lastSize = { width, height };
    send({ method: 'ui/notifications/size-changed', params: { width, height } });
  });

  observer.observe(document.documentElement);
}

export async function connect(): Promise<void> {
  await request('ui/initialize', {
    protocolVersion: PROTOCOL_VERSION,
    clientInfo: { name: 'praticos-order-card', version: '1.0.0' },
    appCapabilities: { availableDisplayModes: ['inline'] },
  });
  send({ method: 'ui/notifications/initialized' });
  observeSize();
}

/** Resolves with the tool's CallToolResult; rejects on a JSON-RPC error. */
export function callTool(name: string, args: Record<string, unknown>): Promise<any> {
  return request('tools/call', { name, arguments: args });
}
