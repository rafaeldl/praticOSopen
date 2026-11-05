/**
 * DANFSe v2.0 (NT 008/2026): one A4 portrait page drawn from DanfseData.
 *
 * Positions and sizes follow item 2.4.5 (in cm, from the page edge). Blocks
 * with no data shrink to one line (notes 2-4) and the room goes to
 * "Descrição do Serviço" and "Informações Complementares" (item 2.3). The
 * optional "Canhoto" block is not printed (item 2.3.3).
 *
 * Fonts: NT 008 names Arial (labels) and Microsoft Sans Serif (content).
 * Neither may be bundled here, so the PDF uses the standard Helvetica, which
 * has Arial's metrics; sizes, weights and case follow item 2.4.
 */

import PDFDocument from 'pdfkit';
import QRCode from 'qrcode';
import { NFSE_LOGO_PNG_BASE64 } from './logo';
import type { DanfseData, DanfseParty } from './parse';

export type DanfseSituation = 'normal' | 'canceled' | 'replaced';

export const QR_CODE_URL = 'https://www.nfse.gov.br/ConsultaPublica/?tpc=1&chave=';

/** What the QR code opens: the national public lookup of this nota (item 2.4.3). */
export function qrCodeUrl(accessKey: string): string {
  return `${QR_CODE_URL}${accessKey}`;
}

const CM = 72 / 2.54;
const PAGE_W = 21 * CM;
const PAGE_H = 29.7 * CM;
const LEFT = 0.3;
const WIDTH = 20.4;
const BOTTOM = 29.4; // body ends 0.30 cm above the page edge, like the top
const COL = [0.3, 5.41, 10.51, 15.62];
const COL_W = 5.09;
const WIDE_W = 10.19;
const ROW = 0.64;
const SUPPRESSED_ROW = 0.42;

const FONT = 'Helvetica';
const FONT_BOLD = 'Helvetica-Bold';
const BLACK = '#000000';
const SHADE = '#F2F2F2'; // light gray, 5%
const RED = '#FF0000'; // M100/Y100
const WATERMARK = '#A6A6A6'; // K35

const cm = (v: number) => v * CM;

interface Cell {
  x: number;
  w: number;
  label: string;
  value: string;
  shaded?: boolean;
}

class Page {
  /** Divider lines, stroked last so the gray shading never covers them. */
  private readonly lines: number[] = [];

  constructor(private readonly doc: PDFKit.PDFDocument) {}

  shade(x: number, y: number, w: number, h: number) {
    this.doc.save().rect(cm(x), cm(y), cm(w), cm(h)).fill(SHADE).restore();
  }

  hline(y: number) {
    this.lines.push(y);
  }

  /** Block dividers (0.5 pt) and the page border (1 pt), over everything else (item 2.2.3). */
  strokeLines() {
    const doc = this.doc;
    doc.save().lineWidth(0.5).strokeColor(BLACK);
    for (const y of this.lines) doc.moveTo(cm(LEFT), cm(y)).lineTo(cm(LEFT + WIDTH), cm(y)).stroke();
    doc.restore();
    doc.save().lineWidth(1).strokeColor(BLACK).rect(cm(LEFT), cm(0.3), cm(WIDTH), cm(BOTTOM - 0.3)).stroke().restore();
  }


  /** Fits text in a box; adds "..." when it does not fit (item 2.1). */
  text(value: string, x: number, y: number, w: number, h: number, size: number, bold = false, color = BLACK, align: 'left' | 'center' = 'left') {
    const doc = this.doc.font(bold ? FONT_BOLD : FONT).fontSize(size).fillColor(color);
    const opts = { width: cm(w) - 4, align, lineGap: 0 };
    // Always room for one line of this size, whatever the box says.
    const room = Math.max(cm(h), size * 1.2) + 0.5;
    let shown = value;
    if (doc.heightOfString(shown, opts) > room) {
      let lo = 0;
      let hi = value.length;
      while (lo < hi) {
        const mid = Math.ceil((lo + hi) / 2);
        if (doc.heightOfString(`${value.slice(0, mid).trimEnd()}...`, opts) <= room) lo = mid;
        else hi = mid - 1;
      }
      shown = `${value.slice(0, lo).trimEnd()}...`;
    }
    doc.text(shown, cm(x) + 2, cm(y), { ...opts, height: room + 1, ellipsis: false });
  }

  textHeight(value: string, w: number, size: number): number {
    return this.doc.font(FONT).fontSize(size).heightOfString(value, { width: cm(w) - 4, lineGap: 0 }) / CM;
  }

  cell(cell: Cell, y: number, h = ROW, labelSize = 6, valueSize = 7) {
    if (cell.shaded) this.shade(cell.x, y, cell.w, h);
    this.text(cell.label, cell.x, y + 0.04, cell.w, 0.24, labelSize, true);
    this.text(cell.value, cell.x, y + 0.3, cell.w, h - 0.32, valueSize);
  }

  /** Block title in the first column (7 pt, bold, upper case, shaded). */
  blockTitle(title: string, y: number, h = ROW) {
    this.shade(LEFT, y, COL_W, h);
    this.text(title, LEFT, y + 0.06, COL_W, 0.3, 7, true);
  }

  /** A block with no data: one line with the fixed sentence (notes 2-4). */
  suppressed(sentence: string, y: number): number {
    this.hline(y);
    this.shade(LEFT, y, WIDTH, SUPPRESSED_ROW);
    this.text(sentence, LEFT, y + 0.09, WIDTH, 0.3, 7, true);
    return y + SUPPRESSED_ROW;
  }
}

function partyRows(p: DanfseParty, withRegistration: boolean): Cell[][] {
  const first: Cell[] = [{ x: COL[1], w: COL_W, label: 'CNPJ / CPF / NIF', value: p.taxId }];
  if (withRegistration) first.push({ x: COL[2], w: COL_W, label: 'Indicador Municipal (Inscrição)', value: p.municipalRegistration });
  first.push({ x: COL[3], w: COL_W, label: 'Telefone', value: p.phone });
  return [
    first,
    [
      { x: COL[0], w: WIDE_W, label: 'Nome / Nome Empresarial', value: p.name },
      { x: COL[2], w: COL_W, label: 'Município / Sigla UF', value: p.city },
      { x: COL[3], w: COL_W, label: 'Código IBGE / CEP', value: p.cityCodeAndPostalCode },
    ],
    [
      { x: COL[0], w: WIDE_W, label: 'Endereço', value: p.address },
      { x: COL[2], w: WIDE_W, label: 'E-mail', value: p.email },
    ],
  ];
}

/** Draws a block whose first row starts with the block title. */
function block(page: Page, title: string, rows: Cell[][], y: number): number {
  page.hline(y);
  rows.forEach((row, i) => {
    if (i === 0) page.blockTitle(title, y);
    row.forEach((c) => page.cell(c, y));
    y += ROW;
  });
  return y;
}

export async function renderDanfse(
  data: DanfseData,
  situation: DanfseSituation = 'normal',
  opts: { compress?: boolean } = {},
): Promise<Buffer> {
  const doc = new PDFDocument({
    compress: opts.compress ?? true,
    size: [PAGE_W, PAGE_H],
    margin: 0,
    autoFirstPage: true,
    info: { Title: `DANFSe ${data.identification.number}`, Producer: 'PraticOS', Creator: 'PraticOS' },
  });
  const chunks: Buffer[] = [];
  doc.on('data', (c: Buffer) => chunks.push(c));
  const done = new Promise<Buffer>((resolve, reject) => {
    doc.on('end', () => resolve(Buffer.concat(chunks)));
    doc.on('error', reject);
  });
  const page = new Page(doc);


  // ---- Header (item 2.4.3) -------------------------------------------------
  page.shade(LEFT, 0.3, WIDTH, 1.16);
  doc.image(Buffer.from(NFSE_LOGO_PNG_BASE64, 'base64'), cm(0.49), cm(0.44), { fit: [cm(4), cm(0.85)] });
  page.text('DANFSe v2.0', 5.41, 0.38, 10.19, 0.38, 9, true, BLACK, 'center');
  page.text('Documento Auxiliar da NFS-e', 5.41, 0.72, 10.19, 0.38, 9, true, BLACK, 'center');
  if (data.testEnvironment) page.text('NFS-e SEM VALIDADE JURÍDICA', 5.41, 1.06, 10.19, 0.38, 9, true, RED, 'center');
  if (data.header.city) page.text(`Município: ${data.header.city}`, 15.62, 0.36, 5.09, 0.6, 8);
  page.text(`Ambiente Gerador: ${data.header.generator}`, 15.62, 0.97, 5.09, 0.24, 6);
  page.text(`Tipo de Ambiente: ${data.header.environment}`, 15.62, 1.22, 5.09, 0.24, 6);

  // ---- NFS-e data (item 2.1.2) --------------------------------------------
  page.hline(1.48);
  page.cell({ x: COL[0], w: 15.3, label: 'CHAVE DE ACESSO DA NFS-E', value: data.accessKey }, 1.48, 0.77, 7, 7);
  const id = data.identification;
  const idRows: Cell[][] = [
    [
      { x: COL[0], w: COL_W, label: 'NÚMERO DA NFS-E', value: id.number },
      { x: COL[1], w: COL_W, label: 'COMPETÊNCIA DA NFS-E', value: id.competence },
      { x: COL[2], w: COL_W, label: 'DATA E HORA DA EMISSÃO DA NFS-E', value: id.issuedAt },
    ],
    [
      { x: COL[0], w: COL_W, label: 'NÚMERO DA DPS', value: id.dpsNumber },
      { x: COL[1], w: COL_W, label: 'SÉRIE DA DPS', value: id.dpsSeries },
      { x: COL[2], w: COL_W, label: 'DATA E HORA DA EMISSÃO DA DPS', value: id.dpsIssuedAt },
    ],
    [
      { x: COL[0], w: COL_W, label: 'EMITENTE DA NFS-E', value: id.emitter, shaded: true },
      { x: COL[1], w: COL_W, label: 'SITUAÇÃO DA NFS-E', value: id.situation },
      { x: COL[2], w: COL_W, label: 'FINALIDADE', value: id.purpose },
    ],
  ];
  [2.27, 2.96, 3.65].forEach((y, i) => idRows[i].forEach((c) => page.cell(c, y, 0.67, 7, 7)));
  const qr = await QRCode.toBuffer(qrCodeUrl(data.accessKey), { type: 'png', margin: 0, errorCorrectionLevel: 'M', scale: 8 });
  doc.image(qr, cm(17.48), cm(1.67), { width: cm(1.52), height: cm(1.52) });
  page.text(
    'A autenticidade desta NFS-e pode ser verificada pela leitura deste código QR ou pela consulta da chave de acesso no portal nacional da NFS-e',
    15.8,
    3.28,
    4.72,
    0.98,
    6,
  );

  // ---- Parties ------------------------------------------------------------
  let y = 4.34;
  const provider = partyRows(data.provider, true);
  provider.push([
    { x: COL[0], w: COL_W, label: 'Simples Nacional na Data de Competência', value: data.provider.simplesNacional },
    { x: COL[2], w: WIDE_W, label: 'Regime de Apuração Tributária pelo SN', value: data.provider.simplesRegime },
  ]);
  y = block(page, 'PRESTADOR / FORNECEDOR', provider, y);

  y = data.taker
    ? block(page, 'TOMADOR / ADQUIRENTE', partyRows(data.taker, true), y)
    : page.suppressed('TOMADOR/ADQUIRENTE DA OPERAÇÃO NÃO IDENTIFICADO NA NFS-e', y);

  if (data.recipient === 'taker') y = page.suppressed('O DESTINATÁRIO É O PRÓPRIO TOMADOR/ADQUIRENTE DA OPERAÇÃO', y);
  else if (data.recipient) y = block(page, 'DESTINATÁRIO DA OPERAÇÃO', partyRows(data.recipient, false), y);
  else y = page.suppressed('DESTINATÁRIO DA OPERAÇÃO NÃO IDENTIFICADO NA NFS-e', y);

  y = data.intermediary
    ? block(page, 'INTERMEDIÁRIO DA OPERAÇÃO', partyRows(data.intermediary, true), y)
    : page.suppressed('INTERMEDIÁRIO DA OPERAÇÃO NÃO IDENTIFICADO NA NFS-e', y);

  // ---- Service: title row and code description (height fixed) ------------
  const s = data.service;
  y = block(
    page,
    'SERVIÇO PRESTADO',
    [
      [
        { x: COL[1], w: COL_W, label: 'Código de Tributação Nacional / Municipal', value: s.codes },
        { x: COL[2], w: COL_W, label: 'Código da NBS', value: s.nbs },
        { x: COL[3], w: COL_W, label: 'Local da Prestação / Sigla UF / País', value: s.place },
      ],
    ],
    y,
  );
  page.text(s.codeDescription, LEFT, y + 0.04, WIDTH, 0.34, 7);
  y += 0.38;
  const descriptionTop = y;

  // ---- Bottom part, laid out from the page end upwards --------------------
  const lower: Array<(top: number) => number> = [];
  const lowerHeights: number[] = [];
  const t = data.municipalTax;
  if (t) {
    const rows: Cell[][] = [
      [
        { x: COL[1], w: COL_W, label: 'Tipo de Tributação do ISSQN', value: t.taxation },
        { x: COL[2], w: WIDE_W, label: 'Município / Sigla UF / País da Incidência do ISSQN', value: t.incidence },
      ],
      [
        { x: COL[0], w: COL_W, label: 'Regime Especial de Tributação do ISSQN', value: t.specialRegime },
        { x: COL[1], w: COL_W, label: 'Tipo de Imunidade do ISSQN', value: t.immunity },
        { x: COL[2], w: COL_W, label: 'Suspensão da Exigibilidade do ISSQN', value: t.suspension },
        { x: COL[3], w: COL_W, label: 'Número Processo Suspensão', value: t.suspensionProcess },
      ],
    ];
    if (t.hasBenefitRow) {
      rows.push([
        { x: COL[0], w: COL_W, label: 'Benefício Municipal', value: t.benefit },
        { x: COL[1], w: COL_W, label: 'Cálculo do BM', value: t.benefitCalc },
        { x: COL[2], w: COL_W, label: 'Total Deduções/Reduções', value: t.deductions },
        { x: COL[3], w: COL_W, label: 'Desconto Incondicionado', value: t.unconditionalDiscount },
      ]);
    }
    rows.push([
      { x: COL[0], w: COL_W, label: 'BC ISSQN', value: t.base },
      { x: COL[1], w: COL_W, label: 'Alíquota Aplicada', value: t.rate },
      { x: COL[2], w: COL_W, label: 'Retenção do ISSQN', value: t.withholding },
      { x: COL[3], w: COL_W, label: 'ISSQN Apurado', value: t.issqn },
    ]);
    lowerHeights.push(rows.length * ROW);
    lower.push((top) => block(page, 'TRIBUTAÇÃO MUNICIPAL (ISSQN)', rows, top));
  } else {
    lowerHeights.push(SUPPRESSED_ROW);
    lower.push((top) => page.suppressed('TRIBUTAÇÃO MUNICIPAL (ISSQN) - OPERAÇÃO NÃO SUJEITA AO ISSQN', top));
  }

  const f = data.federalTax;
  const federal: Cell[][] = [
    [
      { x: COL[1], w: COL_W, label: 'IRRF', value: f.irrf },
      { x: COL[2], w: COL_W, label: 'Contribuição Previdenciária - Retida', value: f.socialSecurity },
      { x: COL[3], w: COL_W, label: 'Contribuições Sociais - Retidas', value: f.socialContributions },
    ],
  ];
  if (f.showPisCofinsRow) {
    federal.push([
      { x: COL[0], w: COL_W, label: 'PIS - Débito Apuração Própria', value: f.pis },
      { x: COL[1], w: COL_W, label: 'COFINS - Débito Apuração Própria', value: f.cofins },
      { x: COL[2], w: WIDE_W, label: 'Descrição Contrib. Sociais - Retidas', value: f.contributionsDescription },
    ]);
  }
  lowerHeights.push(federal.length * ROW);
  lower.push((top) => block(page, 'TRIBUTAÇÃO FEDERAL (EXCETO CBS)', federal, top));

  const i = data.ibsCbs;
  const ibsRows: Cell[][] = [
    [
      { x: COL[1], w: COL_W, label: 'CST / cClassTrib', value: i.cstClass },
      { x: COL[2], w: WIDE_W, label: 'Indicador de Operação / Código IBGE Incidência / Município Incidência / Sigla UF', value: i.incidence },
    ],
    [
      { x: COL[0], w: COL_W, label: 'Exclusões e Reduções da Base de Cálculo', value: i.exclusions },
      { x: COL[1], w: COL_W, label: 'Base de Cálculo Após Exclusões e Reduções', value: i.base },
      { x: COL[2], w: COL_W, label: 'Red. Alíquota IBS / Red. Alíquota CBS', value: i.rateReductions },
      { x: COL[3], w: COL_W, label: 'Alíquota - IBS UF / IBS Mun', value: i.ibsRates },
    ],
    [
      { x: COL[0], w: COL_W, label: 'Alíq. Efetiva Municipal - IBS', value: i.ibsMunEffective },
      { x: COL[1], w: COL_W, label: 'Valor Apurado Municipal - IBS', value: i.ibsMunValue },
      { x: COL[2], w: COL_W, label: 'Alíq. Efetiva Estadual - IBS', value: i.ibsUfEffective },
      { x: COL[3], w: COL_W, label: 'Valor Apurado Estadual - IBS', value: i.ibsUfValue },
    ],
    [
      { x: COL[0], w: COL_W, label: 'Valor Total Apurado - IBS', value: i.ibsTotal },
      { x: COL[1], w: COL_W, label: 'Alíquota - CBS', value: i.cbsRate },
      { x: COL[2], w: COL_W, label: 'Alíquota Efetiva - CBS', value: i.cbsEffective },
      { x: COL[3], w: COL_W, label: 'Valor Total Apurado - CBS', value: i.cbsTotal },
    ],
  ];
  lowerHeights.push(ibsRows.length * ROW);
  lower.push((top) => block(page, 'TRIBUTAÇÃO IBS / CBS', ibsRows, top));

  const v = data.totals;
  const totalRows: Cell[][] = [
    [
      { x: COL[1], w: COL_W, label: 'VALOR DA OPERAÇÃO / SERVIÇO', value: v.serviceValue },
      { x: COL[2], w: COL_W, label: 'Desconto Incondicionado', value: v.unconditionalDiscount },
      { x: COL[3], w: COL_W, label: 'Desconto Condicionado', value: v.conditionalDiscount },
    ],
    [
      { x: COL[0], w: COL_W, label: 'Total das Retenções (ISSQN / Federais)', value: v.withholdings },
      { x: COL[1], w: COL_W, label: 'VALOR LÍQUIDO DA NFS-e', value: v.netValue },
      { x: COL[2], w: COL_W, label: 'Total do IBS/CBS', value: v.ibsCbsTotal },
      { x: COL[3], w: COL_W, label: 'VALOR LÍQUIDO DA NFS-e + IBS/CBS', value: v.netPlusIbsCbs, shaded: true },
    ],
  ];
  lowerHeights.push(totalRows.length * 0.69);
  lower.push((top) => {
    page.hline(top);
    totalRows.forEach((row, r) => {
      const rowTop = top + r * 0.69;
      if (r === 0) page.blockTitle('VALOR TOTAL DA NFS-E', rowTop, 0.67);
      row.forEach((c) => page.cell(c, rowTop, 0.67));
    });
    return top + totalRows.length * 0.69;
  });

  // ---- Description and complementary info share what is left -------------
  const fixedLower = lowerHeights.reduce((a, b) => a + b, 0);
  const infoTitle = 0.39;
  const free = BOTTOM - descriptionTop - fixedLower - infoTitle - 0.1;
  const infoNeed = Math.max(0.6, page.textHeight(data.complementaryInfo, WIDTH, 7) + 0.15);
  const descNeed = Math.max(ROW, page.textHeight(s.description, WIDTH, 7) + 0.35);
  let descH = Math.min(descNeed, Math.max(ROW, free - infoNeed));
  if (free - descH > infoNeed) descH = Math.max(descH, free - infoNeed);
  const infoH = free - descH;

  page.text('Descrição do Serviço', LEFT, descriptionTop + 0.04, WIDTH, 0.24, 6, true);
  page.text(s.description, LEFT, descriptionTop + 0.3, WIDTH, descH - 0.32, 7);
  y = descriptionTop + descH;

  lower.forEach((draw) => {
    y = draw(y);
  });

  page.hline(y);
  page.shade(LEFT, y, WIDTH, infoTitle);
  page.text('INFORMAÇÕES COMPLEMENTARES', LEFT, y + 0.08, WIDTH, 0.3, 7, true);
  y += infoTitle;
  // The approximate-taxes sentence is fixed (item 2.4.5): truncate before it, never it.
  const parts = data.complementaryInfo.split(' | ');
  const fixed = parts.pop() ?? '';
  const room = infoH - page.textHeight(fixed, WIDTH, 7) - 0.15;
  if (parts.length) page.text(parts.join(' | '), LEFT, y + 0.05, WIDTH, Math.max(0.3, room), 7);
  page.text(fixed, LEFT, y + 0.05 + (parts.length ? Math.max(0.3, room) : 0), WIDTH, infoH, 7);

  page.strokeLines();

  // ---- Watermark (items 2.5.1 and 2.5.2), see-through over the content ------
  if (situation !== 'normal') {
    const word = situation === 'canceled' ? 'CANCELADA' : 'SUBSTITUÍDA';
    doc.save();
    doc.rotate(-55, { origin: [PAGE_W / 2, PAGE_H / 2] });
    doc.font(FONT).fontSize(90).fillColor(WATERMARK).fillOpacity(0.55);
    const w = doc.widthOfString(word);
    doc.text(word, PAGE_W / 2 - w / 2, PAGE_H / 2 - 45, { lineBreak: false });
    doc.restore();
  }

  doc.end();
  return done;
}
