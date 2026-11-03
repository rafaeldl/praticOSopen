// Contract generator logic. No file access here, so vitest can feed fixtures.

export const LOCALES = ['pt', 'en', 'es']

/** Parses an ICU message (the subset Flutter gen-l10n accepts) into parts. */
export function compileIcu(source, key = '?') {
  let at = 0
  const fail = (why) => {
    throw new Error(`ICU inválido em "${key}" (posição ${at}): ${why}`)
  }

  function readName() {
    const match = /^\s*([A-Za-z_]\w*)\s*/.exec(source.slice(at))
    if (!match) fail('nome de parâmetro esperado')
    at += match[0].length
    return match[1]
  }

  function readBranches(kind) {
    const branches = {}
    for (;;) {
      while (/\s/.test(source[at] ?? '')) at++
      if (source[at] === '}') break
      const match = /^(=\d+|[A-Za-z_]\w*)\s*\{/.exec(source.slice(at))
      if (!match) fail('opção esperada')
      at += match[0].length
      branches[match[1]] = readParts(kind === 'plural')
      if (source[at] !== '}') fail('} esperado')
      at++
    }
    if (!branches.other) fail(`${kind} sem "other"`)
    return branches
  }

  function readArgument() {
    at++ // {
    const name = readName()
    if (source[at] === '}') {
      at++
      return ['a', name]
    }
    if (source[at] !== ',') fail(', ou } esperado')
    at++
    const kind = readName()
    if (kind !== 'plural' && kind !== 'select') fail(`tipo não suportado: ${kind}`)
    if (source[at] !== ',') fail(', esperado')
    at++
    const branches = readBranches(kind)
    at++ // }
    return [kind === 'plural' ? 'p' : 's', name, branches]
  }

  function readParts(inPlural) {
    const parts = []
    let text = ''
    const flush = () => {
      if (text) parts.push(text)
      text = ''
    }
    while (at < source.length) {
      const char = source[at]
      if (char === '}') break
      if (char === '{') {
        flush()
        parts.push(readArgument())
      } else if (char === '#' && inPlural) {
        flush()
        parts.push(['#'])
        at++
      } else {
        text += char
        at++
      }
    }
    flush()
    return parts
  }

  const parts = readParts(false)
  if (at !== source.length) fail('} sobrando')
  if (parts.length === 0) return ''
  return parts.length === 1 && typeof parts[0] === 'string' ? parts[0] : parts
}

/** Placeholder names a compiled message expects, sorted. */
export function placeholdersOf(compiled) {
  const names = new Set()
  const walk = (parts) => {
    if (typeof parts === 'string') return
    for (const part of parts) {
      if (typeof part === 'string' || part[0] === '#') continue
      names.add(part[1])
      if (part[2]) Object.values(part[2]).forEach(walk)
    }
  }
  walk(compiled)
  return [...names].sort()
}

/** Only message keys: drops ARB metadata (@key, @@locale) and comments (_x). */
export function messagesOf(file) {
  return Object.fromEntries(Object.entries(file).filter(([key]) => !key.startsWith('@') && !key.startsWith('_')))
}

/** Every problem with a set of { locale: { key: text } }. Empty means they match. */
export function parityProblems(byLocale, label) {
  const problems = []
  const all = new Set(Object.values(byLocale).flatMap((messages) => Object.keys(messages)))
  for (const locale of Object.keys(byLocale)) {
    const missing = [...all].filter((key) => !(key in byLocale[locale])).sort()
    if (missing.length) problems.push(`${label}: faltam em ${locale}: ${missing.join(', ')}`)
  }
  return problems
}

/** Compiles every locale and reports messages whose placeholders differ. */
export function compileAll(byLocale, label) {
  const problems = parityProblems(byLocale, label)
  const compiled = Object.fromEntries(
    Object.entries(byLocale).map(([locale, messages]) => [
      locale,
      Object.fromEntries(Object.entries(messages).map(([key, text]) => [key, compileIcu(text, `${locale}.${key}`)])),
    ]),
  )
  const [base, ...rest] = Object.keys(compiled)
  for (const key of Object.keys(compiled[base] ?? {})) {
    const want = placeholdersOf(compiled[base][key]).join(',')
    for (const locale of rest) {
      if (key in compiled[locale] && placeholdersOf(compiled[locale][key]).join(',') !== want) {
        problems.push(`${label}: parâmetros diferentes em ${key} (${base} × ${locale})`)
      }
    }
  }
  return { compiled, problems }
}

/** Merges app and web messages. Web keys must be namespaced, so they never shadow the app's. */
export function mergeWeb(app, web) {
  const problems = []
  for (const key of Object.keys(web)) {
    if (!key.startsWith('web.')) problems.push(`chave web sem prefixo "web.": ${key}`)
    if (key in app) problems.push(`chave web repete chave do app: ${key}`)
  }
  return { merged: { ...app, ...web }, problems }
}

/** Every quoted word in the sources: a superset of the message keys they use. */
export function usedKeys(sources) {
  const keys = new Set()
  for (const source of sources) {
    for (const match of source.matchAll(/['"`]([\w.]+)['"`]/g)) keys.add(match[1])
  }
  return keys
}

export function permissionsModule(contract) {
  const roles = contract.roles
  const all = [...new Set(Object.values(roles).flat())].sort()
  const unknown = contract.financialPermissions.filter((permission) => !all.includes(permission))
  if (unknown.length) throw new Error(`Permissões financeiras desconhecidas: ${unknown.join(', ')}`)
  const lines = (values) => JSON.stringify(values, null, 2)
  return `// Generated by scripts/gen.mjs from firebase/functions/src/__tests__/rbac/app-permissions.json.
export const ROLE_PERMISSIONS = ${lines(roles)} as const

export const FINANCIAL_PERMISSIONS = ${lines(contract.financialPermissions)} as const

export type AppRole = keyof typeof ROLE_PERMISSIONS
export type Permission = ${all.map((permission) => `'${permission}'`).join(' | ')}
`
}

export function keysModule(keys) {
  return `// Generated by scripts/gen.mjs. Keys of lib/l10n/*.arb and src/i18n/web_*.json.
export type MessageKey =
${[...keys].sort().map((key) => `  | '${key}'`).join('\n')}
`
}
