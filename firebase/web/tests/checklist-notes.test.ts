import { test } from 'node:test'
import assert from 'node:assert/strict'
import { checklistNoteLines } from '../utils/checklist-notes.ts'

test('question, option and photo notes, in that order', () => {
  assert.deepEqual(
    checklistNoteLines(
      {
        photos: ['https://x/1.jpg', 'https://x/2.jpg'],
        note: 'Amassado na porta traseira esquerda',
        optionNotes: [{ option: 'Porta', text: 'perto da maçaneta' }],
        photoNotes: [{ url: 'https://x/2.jpg', text: 'Risco' }],
      },
      'Foto',
    ),
    ['Amassado na porta traseira esquerda', 'Porta: perto da maçaneta', 'Foto 2: Risco'],
  )
})

test('older api without notes shows nothing', () => {
  assert.deepEqual(checklistNoteLines({ photos: [] }, 'Foto'), [])
  assert.deepEqual(checklistNoteLines({ note: '  ' }, 'Foto'), [])
})
