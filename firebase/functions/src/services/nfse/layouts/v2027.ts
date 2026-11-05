/**
 * Layout 2027 (spec §5.9): from competence 01/01/2027 the DPS of Simples and
 * MEI carries the IBS/CBS group. One module per package the government applies,
 * each the package's DPS plus `<IBSCBS>` (layouts/ibscbs.ts):
 *
 * - v2027_20260209: production package.
 * - v2027_20261020: Produção Restrita package (NT 009).
 *
 * `dps.ts` switches to them by date; `config/nfse.layoutByEnvironment` can
 * turn them on earlier (to test in Produção Restrita) or keep the old one.
 */

import { withIbsCbs } from './ibscbs';
import { layoutV20260209 } from './v20260209';
import { layoutV20261020 } from './v20261020';

export const layoutV2027Production = withIbsCbs(layoutV20260209, 'v20260209', 'v2027_20260209');
export const layoutV2027Test = withIbsCbs(layoutV20261020, 'v20261020', 'v2027_20261020');
