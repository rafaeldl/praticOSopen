import { build } from 'esbuild';
import { readFileSync, writeFileSync, mkdirSync } from 'fs';
import { dirname } from 'path';
import { createRequire } from 'module';

const OUT = '../src/mcp/widgets/bundle.ts';

const widgetsRequire = createRequire(new URL('./package.json', import.meta.url));

// firebase/.pnp.cjs (a leftover Yarn PnP manifest) makes esbuild use PnP
// resolution, which cannot see widgets/node_modules. Resolve bare imports
// with Node's algorithm instead.
const nodeResolve = {
  name: 'node-resolve-bare-imports',
  setup(build) {
    build.onResolve({ filter: /^[^./]/ }, (args) => ({ path: widgetsRequire.resolve(args.path) }));
  },
};

await build({
  entryPoints: ['src/order-card.tsx'],
  bundle: true,
  minify: true,
  format: 'iife',
  target: 'es2020',
  outfile: 'dist/order-card.js',
  define: { 'process.env.NODE_ENV': '"production"' },
  plugins: [nodeResolve],
});

const js = readFileSync('dist/order-card.js', 'utf8');

// The bundle is inlined into a TS constant so the function needs no extra asset.
const contents = `// GENERATED FILE - run \`npm run build\` in widgets/. Do not edit.
export const ORDER_CARD_BUNDLE = ${JSON.stringify(js)};
`;

mkdirSync(dirname(OUT), { recursive: true });
writeFileSync(OUT, contents);
console.log(`wrote ${OUT} (${js.length} bytes)`);
