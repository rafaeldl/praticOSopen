/**
 * Synthetic ADN mailbox for the import tests: NFS-e and event XMLs in the
 * shape the national system sends (same tags as the real ones the spike read),
 * with invented companies, CNPJs and values only. No customer data here.
 */

import { gzipBase64 } from '../sefin-client';

export const EMITTER_TAX_ID = '00000000000191';

export interface FakeInvoice {
  n: number;
  issuerTaxId?: string;
  issuerName?: string;
  recipient?: { taxId: string; name: string; street?: string; email?: string } | null;
  value: number;
  date: string;
  series?: string;
  description?: string;
  nationalCode?: string;
  /** opSimpNac of the DPS: 2 = MEI, 3 = Simples. */
  simplesNationalOption?: '2' | '3';
}

export const accessKeyOf = (n: number, issuerTaxId = EMITTER_TAX_ID) => `4200000${2}${issuerTaxId}${String(n).padStart(28, '0')}`.slice(0, 50);

export function nfseXml(invoice: FakeInvoice): string {
  const issuer = invoice.issuerTaxId ?? EMITTER_TAX_ID;
  const key = accessKeyOf(invoice.n, issuer);
  const series = invoice.series ?? '900';
  const recipientXml = invoice.recipient
    ? `<toma><${invoice.recipient.taxId.length === 11 ? 'CPF' : 'CNPJ'}>${invoice.recipient.taxId}</${invoice.recipient.taxId.length === 11 ? 'CPF' : 'CNPJ'}><xNome>${invoice.recipient.name}</xNome>` +
      `<end><endNac><cMun>4200000</cMun><CEP>88000000</CEP></endNac><xLgr>${invoice.recipient.street ?? 'Rua Exemplo'}</xLgr><nro>10</nro><xBairro>Centro</xBairro></end>` +
      (invoice.recipient.email ? `<email>${invoice.recipient.email}</email>` : '') +
      `</toma>`
    : '';
  const isSimples = (invoice.simplesNationalOption ?? '3') === '3';
  return (
    `<?xml version="1.0" encoding="utf-8"?><NFSe versao="1.01" xmlns="http://www.sped.fazenda.gov.br/nfse"><infNFSe Id="NFS${key}">` +
    `<xLocEmi>Cidade Exemplo</xLocEmi><xLocPrestacao>Cidade Exemplo</xLocPrestacao><nNFSe>${invoice.n}</nNFSe><cLocIncid>4200000</cLocIncid>` +
    `<xLocIncid>Cidade Exemplo</xLocIncid><xTribNac>Lubrificação, limpeza e revisão de máquinas</xTribNac><verAplic>EmissorWeb_1.6.0</verAplic>` +
    `<ambGer>2</ambGer><tpEmis>1</tpEmis><procEmi>2</procEmi><cStat>100</cStat><dhProc>${invoice.date}T10:00:00-03:00</dhProc><nDFSe>${invoice.n}</nDFSe>` +
    `<emit><CNPJ>${issuer}</CNPJ><IM>12345</IM><xNome>${invoice.issuerName ?? 'OFICINA EXEMPLO LTDA'}</xNome><enderNac><xLgr>Rua da Oficina</xLgr><nro>1</nro>` +
    `<xBairro>Centro</xBairro><cMun>4200000</cMun><UF>SC</UF><CEP>88000000</CEP></enderNac></emit><valores><vLiq>${invoice.value.toFixed(2)}</vLiq></valores>` +
    `<DPS versao="1.01" xmlns="http://www.sped.fazenda.gov.br/nfse"><infDPS Id="DPS4200000${2}${issuer}${series.padStart(5, '0')}${String(invoice.n).padStart(15, '0')}">` +
    `<tpAmb>1</tpAmb><dhEmi>${invoice.date}T09:59:00-03:00</dhEmi><verAplic>EmissorWeb_1.6.0</verAplic><serie>${series}</serie><nDPS>${invoice.n}</nDPS>` +
    `<dCompet>${invoice.date}</dCompet><tpEmit>1</tpEmit><cLocEmi>4200000</cLocEmi><prest><CNPJ>${issuer}</CNPJ><IM>12345</IM>` +
    `<regTrib><opSimpNac>${invoice.simplesNationalOption ?? '3'}</opSimpNac>${isSimples ? '<regApTribSN>1</regApTribSN>' : ''}<regEspTrib>0</regEspTrib></regTrib></prest>` +
    recipientXml +
    `<serv><locPrest><cLocPrestacao>4200000</cLocPrestacao></locPrest><cServ><cTribNac>${invoice.nationalCode ?? '140101'}</cTribNac>` +
    `<xDescServ>${invoice.description ?? 'TROCA DE OLEO - FILTRO'}</xDescServ></cServ></serv>` +
    `<valores><vServPrest><vServ>${invoice.value.toFixed(2)}</vServ></vServPrest><trib><tribMun><tribISSQN>1</tribISSQN><tpRetISSQN>1</tpRetISSQN></tribMun>` +
    (isSimples ? `<totTrib><pTotTribSN>8.00</pTotTribSN></totTrib>` : `<totTrib><indTotTrib>0</indTotTrib></totTrib>`) +
    `</trib></valores></infDPS></DPS></infNFSe></NFSe>`
  );
}

export function cancelEventXml(n: number, issuerTaxId = EMITTER_TAX_ID): string {
  const key = accessKeyOf(n, issuerTaxId);
  return (
    `<?xml version="1.0" encoding="utf-8"?><evento versao="1.01" xmlns="http://www.sped.fazenda.gov.br/nfse"><infEvento Id="EVT${key}101101001">` +
    `<verAplic>EmissorWeb_1.6.0</verAplic><ambGer>2</ambGer><nSeqEvento>1</nSeqEvento><dhProc>2026-10-02T10:00:00-03:00</dhProc><nDFe>1</nDFe>` +
    `<pedRegEvento versao="1.01"><infPedReg Id="PRE${key}101101"><tpAmb>1</tpAmb><verAplic>x</verAplic><dhEvento>2026-10-02T10:00:00-03:00</dhEvento>` +
    `<CNPJAutor>${issuerTaxId}</CNPJAutor><chNFSe>${key}</chNFSe><e101101><xDesc>Cancelamento de NFS-e</xDesc><cMotivo>1</cMotivo><xMotivo>Erro na emissao</xMotivo></e101101>` +
    `</infPedReg></pedRegEvento></infEvento></evento>`
  );
}

export interface MailboxItem {
  nsu: number;
  type: 'NFSE' | 'EVENTO';
  xml: string;
}

/** The answer of GET /contribuintes/DFe/{nsu}: up to 50 documents with NSU >= nsu (inclusive, the worst case). */
export function dfeAnswer(items: MailboxItem[], nsu: number): { status: number; body: string } {
  const page = items.filter((i) => i.nsu >= nsu).slice(0, 50);
  if (page.length === 0) return { status: 404, body: JSON.stringify({ StatusProcessamento: 'NENHUM_DOCUMENTO_LOCALIZADO', LoteDFe: [] }) };
  return {
    status: 200,
    body: JSON.stringify({
      StatusProcessamento: 'DOCUMENTOS_LOCALIZADOS',
      LoteDFe: page.map((i) => ({ NSU: i.nsu, TipoDocumento: i.type, ArquivoXml: gzipBase64(i.xml), DataHoraGeracao: '2026-11-05T10:00:00' })),
      TipoAmbiente: 'PRODUCAO',
    }),
  };
}
