/**
 * Package 20260209 (NT 004/005), the one production applies (spec §5.2).
 * No finNFSe; cServ ends with xDescServ before cNBS.
 */

import { descriptionText, el, headXml, infoComplXml, locPrestXml, plainText, prestXml, tomaXml, valoresXml } from './common';
import { NFSE_NAMESPACE, type DpsInput, type DpsLayout } from './types';

export const layoutV20260209: DpsLayout = {
  id: 'v20260209',
  buildDps(input: DpsInput, dpsId: string): string {
    const s = input.service;
    const cServ =
      `<cServ>${el('cTribNac', s.nationalCode)}${el('cTribMun', plainText(s.municipalCode, 3))}` +
      `${el('xDescServ', descriptionText(input))}${el('cNBS', s.nbs)}</cServ>`;
    return (
      `<DPS xmlns="${NFSE_NAMESPACE}" versao="1.01"><infDPS Id="${dpsId}">` +
      headXml(input) +
      el('cLocEmi', input.emitter.cityCode) +
      prestXml(input) +
      tomaXml(input) +
      `<serv>${locPrestXml(input)}${cServ}${infoComplXml(input)}</serv>` +
      valoresXml(input) +
      `</infDPS></DPS>`
    );
  },
};
