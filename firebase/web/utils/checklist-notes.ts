// Notes of a checklist question on the customer page: the question's note,
// "Door: near the handle" for each marked option, "Photo 2: scratch" for each
// photo. The api (toPublicForms) only sends notes of marked options and of
// the photos it sends.
export interface ChecklistNoteItem {
  photos?: string[]
  note?: string | null
  optionNotes?: Array<{ option: string; text: string }>
  photoNotes?: Array<{ url: string; text: string }>
}

export function checklistNoteLines(item: ChecklistNoteItem, photoWord: string): string[] {
  const lines: string[] = []
  if (typeof item.note === 'string' && item.note.trim()) lines.push(item.note.trim())
  for (const o of item.optionNotes ?? []) {
    if (o?.text?.trim()) lines.push(`${o.option}: ${o.text.trim()}`)
  }
  const photos = item.photos ?? []
  for (const p of item.photoNotes ?? []) {
    const index = photos.indexOf(p?.url)
    if (p?.text?.trim()) lines.push(index >= 0 ? `${photoWord} ${index + 1}: ${p.text.trim()}` : p.text.trim())
  }
  return lines
}
