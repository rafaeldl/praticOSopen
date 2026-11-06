/**
 * Offline check of the "Software e TI" segment (docs/SEGMENT_SOFTWARE_IT.md):
 * the seed scripts in firebase/scripts and the site page agree, the labels
 * exist in the three languages and none of them talks about machines.
 */
import { existsSync } from 'fs';
import { resolve } from 'path';

type Labels = Record<string, string>;
interface Field { key: string; type: string; labels: Labels }
interface Segment { id: string; name: string; nameI18n: Labels; fieldService?: boolean; useContracts?: boolean; subspecialties?: unknown[]; customFields: Field[] }
interface Sample { name: Labels | string; value?: number }

const scripts = resolve(__dirname, '../../../scripts');
const hosting = resolve(__dirname, '../../../hosting/src');
/* eslint-disable @typescript-eslint/no-require-imports */
const { SEGMENTS, selectSegments } = require(`${scripts}/seed_segments`) as {
  SEGMENTS: Segment[];
  selectSegments: (segments: Segment[], argv: string[]) => Segment[];
};
const BOOTSTRAP = require(`${scripts}/bootstrap`) as Record<string, Record<string, { services?: Sample[]; products?: Sample[]; devices?: Sample[] }>>;
const { DEFAULT_TERMS } = require(`${scripts}/terms_data`) as { DEFAULT_TERMS: Record<string, Labels> };
/* eslint-enable @typescript-eslint/no-require-imports */

const LOCALES = ['pt-BR', 'en-US', 'es-ES'];
const HARDWARE = /aparelho|defeito|ve[ií]culo|computador|equipamento|device|vehicle|computer|equipment|aparato|computadora|equipo\b/i;
const segment = SEGMENTS.find((s) => s.id === 'software_it') as Segment;
const ptName = (sample: Sample) => (typeof sample.name === 'string' ? sample.name : sample.name['pt-BR']);

describe('segment software_it', () => {
  it('is an active segment named in three languages, remote by default', () => {
    expect(segment).toBeDefined();
    expect(segment.nameI18n).toEqual({ 'pt-BR': 'Software e TI', 'en-US': 'Software & IT', 'es-ES': 'Software y TI' });
    expect(segment.fieldService).toBe(false);
    expect(segment.subspecialties).toBeUndefined();
    // Monthly contracts stay a suggestion: nothing is switched on by the segment
    expect(segment.useContracts).toBeUndefined();
  });

  it('names the device a system and the product a license, without machine words', () => {
    const labels = Object.fromEntries(segment.customFields.map((f) => [f.key, f.labels]));
    expect(labels['device._entity']['pt-BR']).toBe('Sistema');
    expect(labels['device._entity_plural']['pt-BR']).toBe('Sistemas');
    expect(labels['product._entity']['pt-BR']).toBe('Licença');
    for (const field of segment.customFields) {
      expect(field.type).toBe('label');
      expect(Object.keys(field.labels).sort()).toEqual([...LOCALES].sort());
      for (const text of Object.values(field.labels)) expect(text).not.toMatch(HARDWARE);
    }
  });

  it('brings the six sample services and its own terms', () => {
    const samples = BOOTSTRAP.software_it._default;
    expect(samples.services?.map(ptName)).toEqual([
      'Suporte técnico mensal',
      'Desenvolvimento de sistema (hora)',
      'Manutenção de sistema mensal',
      'Hospedagem mensal',
      'Consultoria em TI (hora)',
      'Treinamento de usuários',
    ]);
    for (const list of [samples.services, samples.products, samples.devices]) {
      for (const sample of list ?? []) {
        expect(typeof sample.name === 'string' || Object.keys(sample.name).length === 3).toBe(true);
      }
    }
    expect(Object.keys(DEFAULT_TERMS.software_it).sort()).toEqual([...LOCALES].sort());
    expect(DEFAULT_TERMS.software_it['pt-BR']).toContain('MENSALIDADES');
  });

  it('has a site page in the three languages', () => {
    expect(existsSync(`${hosting}/_data/segments/software-ti.json`)).toBe(true);
    for (const page of ['software-ti', 'software-ti-en', 'software-ti-es']) {
      expect(existsSync(`${hosting}/segmentos/${page}.njk`)).toBe(true);
    }
  });

  it('--only picks the segments the production run writes', () => {
    expect(selectSegments(SEGMENTS, ['node', 'seed', '--only=software_it']).map((s) => s.id)).toEqual(['software_it']);
    expect(selectSegments(SEGMENTS, ['node', 'seed'])).toHaveLength(SEGMENTS.length);
    expect(() => selectSegments(SEGMENTS, ['--only=nope'])).toThrow('nope');
  });
});
