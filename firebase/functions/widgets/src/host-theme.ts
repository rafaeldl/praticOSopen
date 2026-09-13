// Pure theming logic for the order card (spec ext-apps 2026-01-26, Theming).
//
// No DOM globals: the host context arrives in the `ui/initialize` result
// (`hostContext`) and in `ui/notifications/host-context-changed` (a partial
// update the View SHOULD merge into its current context). This module merges
// those updates and writes the host's theme and CSS variables onto a
// style-declaration-like target, so it can be unit-tested with plain Jest
// from firebase/functions (see src/mcp/__tests__/host-theme.test.ts).
//
// The fallback values for every variable the card uses live in the resource
// HTML (src/mcp/widgets/order-card.ts), on `:root`. Host variables are set
// inline on <html>, which wins over that stylesheet; a variable the host
// stops sending is removed so the fallback applies again.

export interface HostContext {
  theme?: 'light' | 'dark';
  styles?: {
    variables?: Record<string, string | undefined>;
  };
  [key: string]: unknown;
}

/** The subset of CSSStyleDeclaration this module writes to. */
export interface StyleTarget {
  setProperty(name: string, value: string): void;
  removeProperty(name: string): string;
}

/** `host-context-changed` carries only the fields that changed: shallow-merge them. */
export function mergeHostContext(
  current: HostContext | null | undefined,
  update: HostContext | null | undefined,
): HostContext {
  return { ...(current ?? {}), ...(update ?? {}) };
}

/** Only CSS custom properties with a string value are ever applied. */
function hostVariables(context: HostContext): Record<string, string> {
  const variables: Record<string, string> = {};
  const source = context.styles?.variables;
  if (!source || typeof source !== 'object') return variables;

  for (const [name, value] of Object.entries(source)) {
    if (name.startsWith('--') && typeof value === 'string' && value.trim() !== '') {
      variables[name] = value;
    }
  }
  return variables;
}

/**
 * Applies `context` to `target` (the <html> element's style) and returns the
 * variable names now set, to pass back as `previous` on the next call.
 *
 * `color-scheme` follows the host's `theme` when it sends one, so `light-dark()`
 * values (the spec's recommended form for host variables) and system colors
 * like `CanvasText` resolve to the host's theme rather than the OS setting.
 * Without a theme it is removed and the stylesheet's `light dark` applies.
 */
export function applyHostTheme(
  target: StyleTarget,
  context: HostContext,
  previous: readonly string[] = [],
): string[] {
  if (context.theme === 'light' || context.theme === 'dark') {
    target.setProperty('color-scheme', context.theme);
  } else {
    target.removeProperty('color-scheme');
  }

  const variables = hostVariables(context);
  for (const name of previous) {
    if (!(name in variables)) target.removeProperty(name);
  }
  for (const [name, value] of Object.entries(variables)) {
    target.setProperty(name, value);
  }
  return Object.keys(variables);
}
