// The company's options as the app resolves them when it opens
// (auth_wrapper.dart, auth.gate.feature-defaults): the company's own value,
// then the segment's default, then the app's default. The web never writes the
// missing ones back (the app's backfill is a "Não copiar").
export type CompanyFeature = 'useFinancial' | 'useScheduling' | 'fieldService' | 'useContracts' | 'useDeviceManagement'

export function featureOn(
  company: Partial<Record<CompanyFeature, unknown>> | null | undefined,
  feature: CompanyFeature,
  segmentFieldService?: boolean | null,
): boolean {
  const own = company?.[feature]
  if (typeof own === 'boolean') return own
  if (feature === 'fieldService') return segmentFieldService ?? true
  // Values and billing and the agenda are on unless turned off; contracts and device control are off.
  return feature === 'useFinancial' || feature === 'useScheduling'
}
