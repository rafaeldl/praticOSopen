/**
 * Package 20261020 (NT 009), the one the test environment (Produção Restrita)
 * applies. Adds finNFSe after tpEmit; cServ has cNBS before xDescServ.
 * IBS/CBS (2027) is the next module, not this one.
 */

import { descriptionText, el, headXml, infoComplXml, locPrestXml, plainText, prestXml, tomaXml, valoresXml } from './common';
import { NFSE_NAMESPACE, type DpsInput, type DpsLayout } from './types';

export const layoutV20261020: DpsLayout = {
  id: 'v20261020',
  buildDps(input: DpsInput, dpsId: string): string {
    const s = input.service;
    const cServ =
      `<cServ>${el('cTribNac', s.nationalCode)}${el('cTribMun', plainText(s.municipalCode, 3))}` +
      `${el('cNBS', s.nbs)}${el('xDescServ', descriptionText(input))}</cServ>`;
    return (
      `<DPS xmlns="${NFSE_NAMESPACE}" versao="1.01"><infDPS Id="${dpsId}">` +
      headXml(input) +
      el('finNFSe', 0) +
      el('cLocEmi', input.emitter.cityCode) +
      prestXml(input) +
      tomaXml(input) +
      `<serv>${locPrestXml(input)}${cServ}${infoComplXml(input)}</serv>` +
      valoresXml(input) +
      `</infDPS></DPS>`
    );
  },
};
