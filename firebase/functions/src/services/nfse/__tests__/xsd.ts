/** Validates XML against the official XSDs copied in fixtures/xsd (xmllint compiled to WebAssembly). */

import { readFileSync, readdirSync } from 'node:fs';
import { join } from 'node:path';
import { validateXML } from 'xmllint-wasm';

const ROOT = join(__dirname, 'fixtures', 'xsd');

/** The package (XSD folder) of a layout: v2027_20261020 → v20261020. */
export function packageOf(layoutId: string): 'v20260209' | 'v20261020' {
  return layoutId.includes('20260209') ? 'v20260209' : 'v20261020';
}

export async function validateAgainstXsd(
  xml: string,
  layoutId: string,
  schema: 'DPS_v1.01.xsd' | 'pedRegEvento_v1.01.xsd',
): Promise<{ valid: boolean; errors: string[] }> {
  const dir = join(ROOT, packageOf(layoutId));
  const files = readdirSync(dir).filter((f) => f.endsWith('.xsd'));
  const result = await validateXML({
    xml: [{ fileName: 'doc.xml', contents: xml }],
    schema: [{ fileName: schema, contents: readFileSync(join(dir, schema), 'utf8') }],
    preload: files.filter((f) => f !== schema).map((f) => ({ fileName: f, contents: readFileSync(join(dir, f), 'utf8') })),
  });
  return { valid: result.valid, errors: result.errors.map((e) => e.rawMessage) };
}
