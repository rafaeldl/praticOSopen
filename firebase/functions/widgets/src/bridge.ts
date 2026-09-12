// Minimal MCP Apps bridge (spec ext-apps 2026-01-26).
// The View talks to the host over JSON-RPC via postMessage. The host sends
// nothing until the View completes ui/initialize + notifications/initialized.

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
  if (!message || message.jsonrpc !== '2.0') return;

  if (typeof message.id === 'number' && pending.has(message.id)) {
    const { resolve, reject } = pending.get(message.id)!;
    pending.delete(message.id);
    if (message.error) reject(message.error);
    else resolve(message.result);
    return;
  }

  if (message.method === 'ui/notifications/tool-result') {
    for (const listener of toolResultListeners) listener(message.params);
  }
});

/** Register before connect(): the result can arrive right after the handshake. */
export function onToolResult(listener: (result: any) => void): void {
  toolResultListeners.push(listener);
}

export async function connect(): Promise<void> {
  await request('ui/initialize', {
    protocolVersion: PROTOCOL_VERSION,
    clientInfo: { name: 'praticos-order-card', version: '1.0.0' },
    appCapabilities: { availableDisplayModes: ['inline'] },
  });
  send({ method: 'ui/notifications/initialized' });
}

/** Resolves with the tool's CallToolResult; rejects on a JSON-RPC error. */
export function callTool(name: string, args: Record<string, unknown>): Promise<any> {
  return request('tools/call', { name, arguments: args });
}
