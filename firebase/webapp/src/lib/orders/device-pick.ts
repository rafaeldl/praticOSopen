// "Em quais veículos?" (order.device-picker.one / .multi): the app's
// DeviceMultiPickerScreen (lib/screens/widgets/device_picker_sheet.dart). One
// screen with Geral, Selecionar Tudo (more than one device) and the devices.
// Geral clears the devices; a device clears Geral; Selecionar Tudo with all
// marked clears everything. ✓ only with something chosen. Pure.

export interface PickState { general: boolean; ids: string[] }

export const emptyPick = (): PickState => ({ general: false, ids: [] })

export function toggleGeneral(state: PickState): PickState {
  return state.general ? { general: false, ids: state.ids } : { general: true, ids: [] }
}

export function toggleAll(state: PickState, all: readonly string[]): PickState {
  const every = all.length > 0 && all.every((id) => state.ids.includes(id))
  return { general: false, ids: every ? [] : [...all] }
}

export function toggleDevice(state: PickState, id: string): PickState {
  return { general: false, ids: state.ids.includes(id) ? state.ids.filter((x) => x !== id) : [...state.ids, id] }
}

export const canConfirm = (state: PickState) => state.general || state.ids.length > 0

export type PickResult =
  | { kind: 'general' }
  | { kind: 'specific'; deviceId: string }
  | { kind: 'all' }
  | { kind: 'multiSpecific'; deviceIds: string[] }

/** Checked in the app's order: Geral, exactly one, all, several. */
export function pickResult(state: PickState, all: readonly string[]): PickResult | null {
  if (state.general) return { kind: 'general' }
  const ids = all.filter((id) => state.ids.includes(id))
  if (ids.length === 1) return { kind: 'specific', deviceId: ids[0] as string }
  if (ids.length > 1 && ids.length === all.length) return { kind: 'all' }
  if (ids.length > 1) return { kind: 'multiSpecific', deviceIds: ids }
  return null
}

/** One line per device (the app clones the line), or one line without device for Geral. */
export function deviceIdsOf(result: PickResult, all: readonly string[]): (string | null)[] {
  if (result.kind === 'general') return [null]
  if (result.kind === 'specific') return [result.deviceId]
  if (result.kind === 'all') return [...all]
  return result.deviceIds
}
