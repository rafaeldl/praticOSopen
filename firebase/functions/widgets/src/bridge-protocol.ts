// Pure message-classification logic for the MCP Apps bridge (bridge.ts).
//
// No DOM, no postMessage: this module only decides what kind of JSON-RPC
// message an incoming `window` message event carries, so it can be
// unit-tested with plain Jest from firebase/functions (see
// src/mcp/__tests__/bridge-protocol.test.ts) the same way card-state.ts is.
// bridge.ts imports these functions and keeps only the postMessage/DOM
// wiring.

export interface JsonRpcMessage {
  jsonrpc?: string;
  id?: number;
  method?: string;
  params?: unknown;
  result?: unknown;
  error?: unknown;
}

export type ClassifiedMessage =
  | { kind: 'response'; id: number }
  | { kind: 'hostRequest'; id: number; method: string; params?: unknown }
  | { kind: 'notification'; method: string; params?: unknown }
  | { kind: 'ignore' };

/**
 * Classifies an incoming window `message` event's JSON-RPC payload.
 *
 * A message is a **response** to one of our own pending requests only when
 * its `id` matches a pending id AND it carries no `method`. A *request*
 * FROM the host (e.g. `ping`, `ui/resource-teardown`) also carries a
 * numeric `id`, and that id can collide with one of ours — both sides mint
 * ids from their own independent counters starting at 1. Treating "id
 * matches a pending request" alone as "this is a response" resolves
 * whichever `callTool()` is waiting on that id with `undefined` on such a
 * collision: the order card then reports a write as failed even though it
 * succeeded, inviting the user to retry and write twice. Requiring the
 * absence of `method` is exactly how JSON-RPC 2.0 itself distinguishes a
 * Response from a Request — a Response object never has a `method` member.
 */
export function classifyMessage(
  message: JsonRpcMessage | null | undefined,
  isPending: (id: number) => boolean,
): ClassifiedMessage {
  if (!message || message.jsonrpc !== '2.0') return { kind: 'ignore' };

  const hasMethod = typeof message.method === 'string';

  if (typeof message.id === 'number' && !hasMethod && isPending(message.id)) {
    return { kind: 'response', id: message.id };
  }

  if (hasMethod) {
    return typeof message.id === 'number'
      ? { kind: 'hostRequest', id: message.id, method: message.method as string, params: message.params }
      : { kind: 'notification', method: message.method as string, params: message.params };
  }

  return { kind: 'ignore' };
}

/**
 * Host request methods the View must acknowledge (spec ext-apps 2026-01-26):
 * `ping` is the standard MCP connection health check, and the spec says the
 * host SHOULD wait for a `ui/resource-teardown` response before tearing the
 * iframe down. Neither carries data the View needs to act on — an empty
 * result is the correct reply to both.
 */
const ACKNOWLEDGED_HOST_METHODS = new Set(['ping', 'ui/resource-teardown']);

export function isAcknowledgedHostRequest(method: string): boolean {
  return ACKNOWLEDGED_HOST_METHODS.has(method);
}

/** Builds the empty-result reply the spec requires for `ping` / `ui/resource-teardown`. */
export function buildHostRequestReply(id: number): {
  jsonrpc: '2.0';
  id: number;
  result: Record<string, never>;
} {
  return { jsonrpc: '2.0', id, result: {} };
}
