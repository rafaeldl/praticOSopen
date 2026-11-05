/**
 * Synthetic NFS-e XML (as the government returns it) for the DANFSe tests:
 * our own DPS, signed with the synthetic certificate, wrapped in infNFSe.
 * No real data.
 */

import { openCertificate } from '../certificate';
import { buildDps, LAYOUTS } from '../dps';
import type { DpsInput } from '../layouts/types';
import { leafOf, signXml } from '../signature';
import { testPki } from './test-certificates';

export const FIXTURE_KEY = '42000002200000000000191000000000000002926110000000';

export function dpsInput(overrides: Partial<DpsInput> = {}): DpsInput {
  return {
    environment: 'test',
    issuedAt: '2026-11-05T09:59:55-03:00',
    competenceDate: '2026-11-05',
    appVersion: 'PraticOS-1.104.0',
    series: '10',
    number: 7,
    emitter: { taxId: '00000000000191', cityCode: '4200000', municipalRegistration: '12345', regime: 'simples', simplesOption: 1 },
    recipient: {
      taxId: '00000000000272',
      legalName: 'REVENDA EXEMPLO LTDA',
      address: { postalCode: '88000000', street: 'Rua Exemplo', number: '10', complement: 'Sala 2', district: 'Centro', cityCode: '4200000', state: 'SC' },
      email: 'nota@example.com',
    },
    service: { nationalCode: '140101', municipalCode: '001', description: 'CONSERTO/PINTURA DE CAPÔ - TROCA DE ÓLEO' },
    value: 270,
    simplesTaxRate: 6,
    complementaryInfo: 'OS 182 · Emitida pelo PraticOS (praticos.app)',
    ...overrides,
  };
}

export function nfseXml(input: DpsInput = dpsInput(), opts: { tpAmb?: '1' | '2'; withSignature?: boolean } = {}): string {
  const pki = testPki();
  const cert = openCertificate(pki.pfx(), 'senha-teste', { now: new Date('2026-11-05T12:00:00Z'), trustedRoots: [pki.rootPem] });
  let { xml: dps } = buildDps(input, LAYOUTS.v20261020);
  if (opts.tpAmb) dps = dps.replace(/<tpAmb>\d<\/tpAmb>/, `<tpAmb>${opts.tpAmb}</tpAmb>`);
  const signedDps = signXml(dps, cert.keyPem, leafOf(cert.chainPem), 'infDPS', 'DPS').replace(/^<\?xml[^>]*>/, '');
  const inf =
    `<infNFSe Id="NFS${FIXTURE_KEY}">` +
    '<xLocEmi>Cidade Exemplo</xLocEmi><xLocPrestacao>Cidade Exemplo</xLocPrestacao><nNFSe>29</nNFSe>' +
    '<cLocIncid>4200000</cLocIncid><xLocIncid>Cidade Exemplo</xLocIncid>' +
    '<xTribNac>Lubrificação, limpeza, lustração, revisão, carga e recarga, conserto, restauração, blindagem, manutenção e conservação de máquinas, veículos, aparelhos, equipamentos, motores, elevadores ou de qualquer objeto.</xTribNac>' +
    '<verAplic>SefinNac_Pre_1.4.0</verAplic><ambGer>2</ambGer><tpEmis>1</tpEmis><procEmi>1</procEmi><cStat>100</cStat>' +
    '<dhProc>2026-11-05T10:00:03-03:00</dhProc><nDFSe>123456</nDFSe>' +
    '<emit><CNPJ>00000000000191</CNPJ><IM>12345</IM><xNome>OFICINA EXEMPLO LTDA</xNome>' +
    '<enderNac><xLgr>Avenida Teste</xLgr><nro>100</nro><xBairro>Industrial</xBairro><cMun>4200000</cMun><UF>SC</UF><CEP>88000001</CEP></enderNac>' +
    '<fone>4800000000</fone><email>oficina@example.com</email></emit>' +
    '<valores><vBC>270.00</vBC><vLiq>270.00</vLiq></valores>' +
    signedDps +
    '</infNFSe>';
  const nfse = `<NFSe xmlns="http://www.sped.fazenda.gov.br/nfse" versao="1.01">${inf}</NFSe>`;
  return opts.withSignature === false ? nfse : signXml(nfse, cert.keyPem, leafOf(cert.chainPem), 'infNFSe', 'NFSe');
}
