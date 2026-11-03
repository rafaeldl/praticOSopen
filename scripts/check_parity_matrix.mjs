#!/usr/bin/env node
// Confere a matriz de paridade do app web (docs/web-app/parity-matrix.yaml).
//
// Falha quando:
//   - um arquivo de lib/screens/**/*.dart não aparece em `screen`;
//   - uma linha aponta para um arquivo que não existe mais;
//   - uma chave de `appRoutes` em lib/routes.dart não aparece em `route`;
//   - há `id` repetido;
//   - `web_status` falta ou está fora de todo|in_progress|done|excepted;
//   - `web_status: done` vem sem `e2e`;
//   - `web_exception.status` é diferente de proposed ou approved.
//
// Uso: node scripts/check_parity_matrix.mjs [--root <pasta>] [--matrix <arquivo>]
// Sem dependências: lê o YAML por regex, então a matriz precisa manter o
// formato de uma chave por linha.

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const WEB_STATUSES = ['todo', 'in_progress', 'done', 'excepted'];
const EXCEPTION_STATUSES = ['proposed', 'approved'];

function argument(name) {
  const at = process.argv.indexOf(name);
  return at >= 0 ? process.argv[at + 1] : undefined;
}

/** Tira comentário no fim da linha e aspas em volta do valor. */
function scalar(raw) {
  const value = raw.trim();
  const quoted = value.match(/^(["'])(.*?)\1/);
  if (quoted) return quoted[2];
  return value.replace(/\s+#.*$/, '').trim();
}

/** Valor de `key` na linha de dois espaços da linha da matriz, ou undefined. */
function field(block, key) {
  const match = block.match(new RegExp(`^  ${key}:(.*)$`, 'm'));
  return match ? scalar(match[1]) : undefined;
}

function isEmpty(value) {
  return value === undefined || value === '' || value === 'null' || value === '~';
}

function parseRows(text) {
  const [header, ...blocks] = text.split(/^(?=- id:)/m);
  let next = header.split('\n').length;
  return blocks.map((block) => {
    const line = next;
    next += block.split('\n').length - 1;
    return {
      line,
      id: scalar(block.match(/^- id:(.*)$/m)[1]),
      screen: field(block, 'screen'),
      route: field(block, 'route'),
      webStatus: field(block, 'web_status'),
      e2e: field(block, 'e2e'),
      exception: exceptionOf(block),
    };
  });
}

/** Aceita `{status: x, reason: y}` e a forma em bloco. Null quando não há. */
function exceptionOf(block) {
  const inline = block.match(/^  web_exception:[ \t]*(\S.*)$/m);
  if (inline) {
    const value = inline[1].trim();
    if (value === 'null' || value === '~') return null;
    const status = value.match(/\bstatus:\s*["']?([^,}"'\s]+)/);
    return { status: status ? status[1] : undefined };
  }
  const nested = block.match(/^  web_exception:[ \t]*\n((?: {4}.*\n?)*)/m);
  if (nested) {
    const status = nested[1].match(/^ {4}status:(.*)$/m);
    return { status: status ? scalar(status[1]) : undefined };
  }
  return null;
}

function listScreens(root) {
  const base = path.join(root, 'lib', 'screens');
  const found = [];
  for (const entry of fs.readdirSync(base, { recursive: true, withFileTypes: true })) {
    if (!entry.isFile() || !entry.name.endsWith('.dart')) continue;
    const absolute = path.join(entry.parentPath ?? entry.path, entry.name);
    found.push(path.relative(root, absolute).split(path.sep).join('/'));
  }
  return found.sort();
}

function parseAppRoutes(text) {
  const start = text.search(/\bappRoutes\s*=\s*\{/);
  if (start < 0) return [];
  const routes = [];
  for (const line of text.slice(start).split('\n').slice(1)) {
    if (/^\s*\};/.test(line)) break;
    const key = line.match(/^\s*['"](\/[^'"]*)['"]\s*:/);
    if (key) routes.push(key[1]);
  }
  return routes;
}

function check({ root, matrixPath }) {
  const text = fs.readFileSync(matrixPath, 'utf8');
  const rows = parseRows(text);
  const problems = new Map();
  const report = (title, detail) => {
    if (!problems.has(title)) problems.set(title, []);
    problems.get(title).push(detail);
  };

  if (rows.length === 0) report('Matriz sem linhas', matrixPath);

  const firstLine = new Map();
  for (const row of rows) {
    const where = `${row.id} (linha ${row.line})`;
    if (firstLine.has(row.id)) {
      report('id repetido', `${where}, já usado na linha ${firstLine.get(row.id)}`);
    } else {
      firstLine.set(row.id, row.line);
    }
    if (isEmpty(row.webStatus)) {
      report('web_status ausente', where);
    } else if (!WEB_STATUSES.includes(row.webStatus)) {
      report('web_status inválido', `${where}: "${row.webStatus}" (use ${WEB_STATUSES.join(', ')})`);
    }
    if (row.webStatus === 'done' && (isEmpty(row.e2e) || row.e2e === '[]')) {
      report('web_status: done sem e2e', where);
    }
    if (row.webStatus === 'excepted' && row.exception?.status !== 'approved') {
      report('web_status: excepted sem exceção aprovada', where);
    }
    if (row.exception && !EXCEPTION_STATUSES.includes(row.exception.status)) {
      report(
        'web_exception.status inválido',
        `${where}: "${row.exception.status ?? ''}" (use ${EXCEPTION_STATUSES.join(' ou ')})`,
      );
    }
    if (isEmpty(row.screen)) {
      report('Linha sem screen', where);
    } else if (!fs.statSync(path.join(root, row.screen), { throwIfNoEntry: false })?.isFile()) {
      report('screen aponta para arquivo que não existe', `${where}: ${row.screen}`);
    }
  }

  const screensInMatrix = new Set(rows.map((row) => row.screen));
  const screens = listScreens(root);
  for (const screen of screens) {
    if (!screensInMatrix.has(screen)) report('Tela sem linha na matriz', screen);
  }

  const routesInMatrix = new Set(rows.map((row) => row.route));
  const routes = parseAppRoutes(fs.readFileSync(path.join(root, 'lib', 'routes.dart'), 'utf8'));
  if (routes.length === 0) report('appRoutes não encontrado', 'lib/routes.dart');
  for (const route of routes) {
    if (!routesInMatrix.has(route)) report('Rota de appRoutes sem linha na matriz', route);
  }

  return { rows, screens, routes, problems };
}

function main() {
  const here = path.dirname(fileURLToPath(import.meta.url));
  const root = path.resolve(argument('--root') ?? path.join(here, '..'));
  const matrixPath = path.resolve(
    argument('--matrix') ?? path.join(root, 'docs', 'web-app', 'parity-matrix.yaml'),
  );
  const { rows, screens, routes, problems } = check({ root, matrixPath });

  if (problems.size === 0) {
    console.log(
      `Matriz em dia: ${rows.length} linhas, ${screens.length} telas, ${routes.length} rotas.`,
    );
    return;
  }

  const total = [...problems.values()].reduce((sum, list) => sum + list.length, 0);
  console.error(`Matriz de paridade com ${total} problema(s):\n`);
  for (const [title, details] of problems) {
    console.error(`${title} (${details.length}):`);
    for (const detail of details) console.error(`  - ${detail}`);
    console.error('');
  }
  console.error('Corrija docs/web-app/parity-matrix.yaml. O formato está no cabeçalho do arquivo.');
  process.exitCode = 1;
}

main();
