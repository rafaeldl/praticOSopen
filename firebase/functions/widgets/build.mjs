import { build } from 'esbuild';
import { readFileSync, writeFileSync, mkdirSync } from 'fs';
import { dirname } from 'path';

const OUT = '../src/mcp/widgets/bundle.ts';

await build({
  entryPoints: ['src/order-card.tsx'],
  bundle: true,
  minify: true,
  format: 'iife',
  target: 'es2020',
  outfile: 'dist/order-card.js',
  define: { 'process.env.NODE_ENV': '"production"' },
});

const js = readFileSync('dist/order-card.js', 'utf8');

// The bundle is inlined into a TS constant so the function needs no extra asset.
const contents = `// GENERATED FILE - run \`npm run build\` in widgets/. Do not edit.
export const ORDER_CARD_BUNDLE = ${JSON.stringify(js)};
`;

mkdirSync(dirname(OUT), { recursive: true });
writeFileSync(OUT, contents);
console.log(`wrote ${OUT} (${js.length} bytes)`);
