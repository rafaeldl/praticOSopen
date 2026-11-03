// Checklists (lib/forms/model.ts): the app's shapes, the merge that keeps the
// app's and the web's answers together, and the editor's and plan's rules.
import { describe, expect, test } from 'vitest'
import {
  activeCount,
  answerText,
  applyChange,
  canFinishAnyway,
  editedItem,
  firstUnanswered,
  fitsOneMore,
  formsAccess,
  isAnswered,
  missingCount,
  moveItem,
  normalizeOrderForm,
  normalizeTemplate,
  numberAnswer,
  optionText,
  orderFormDoc,
  planLimit,
  questionProblem,
  readyNotCopied,
  requiredMissing,
  saveProblem,
  statusAfter,
  templateMatches,
  type FormItem,
  type OrderForm,
} from '../src/lib/forms/model'
import { parseMoney } from '../src/lib/format'

const item = (id: string, type: FormItem['type'], extra: Partial<FormItem> = {}): FormItem => ({
  id,
  label: id,
  type,
  options: type === 'select' || type === 'checklist' ? ['Bom', 'Ruim'] : null,
  required: false,
  allowPhotos: true,
  ...extra,
})
const form = (items: FormItem[], responses: OrderForm['responses'] = [], status: OrderForm['status'] = 'pending'): OrderForm => ({
  id: 'f',
  formDefinitionId: 't',
  title: 'Vistoria',
  status,
  items,
  responses,
  deviceId: null,
})

describe('formato do app', () => {
  test('modelo legado: name vira title, fields vira items, requiresPhoto vira allowPhotos, isActive ausente é ligado', () => {
    const template = normalizeTemplate('x', { name: 'Antigo', fields: [{ id: 3, label: 'Pneu', type: 'boolean', requiresPhoto: false }, { label: 'Sem id', type: 'text' }] })
    expect(template.title).toBe('Antigo')
    expect(template.isActive).toBe(true)
    expect(template.items[0]).toMatchObject({ id: '3', allowPhotos: false, required: false })
    expect(template.items[1]?.id).toMatch(/\w+/)
    expect(normalizeTemplate('y', { title: 'Off', isActive: false, items: [] }).isActive).toBe(false)
  })

  test('cópia do modelo na OS tem as chaves de OrderForm.toJson, sem id', () => {
    const template = normalizeTemplate('tpl', { title: 'Entrada', titleI18n: { en: 'Check-in' }, items: [{ id: 'a', label: 'Pneu', type: 'select', options: ['Bom', 'Ruim'] }] })
    const doc = orderFormDoc(template, 'device-1', '2026-11-03T10:00:00.000Z')
    expect(Object.keys(doc).sort()).toEqual(['completedAt', 'deviceId', 'formDefinitionId', 'items', 'responses', 'startedAt', 'status', 'title', 'titleI18n', 'updatedAt'])
    expect(doc).toMatchObject({ formDefinitionId: 'tpl', status: 'pending', responses: [], deviceId: 'device-1', titleI18n: { en: 'Check-in' } })
    expect(Object.keys(doc.items[0] as object).sort()).toEqual(['allowPhotos', 'id', 'label', 'labelI18n', 'options', 'optionsI18n', 'required', 'type'])
  })

  test('situação in_progress e completed lidas como o app grava', () => {
    expect(normalizeOrderForm('a', { status: 'in_progress', items: [], responses: [{ itemId: 'x', value: true }] })).toMatchObject({ status: 'in_progress', responses: [{ itemId: 'x', value: true, photoUrls: [] }] })
    expect(normalizeOrderForm('a', { status: 'esquisito' }).status).toBe('pending')
  })
})

describe('respostas', () => {
  test('respondida: foto na pergunta só de foto, valor não vazio nas outras, lista com algo na de várias', () => {
    expect(isAnswered(item('a', 'photo_only'), { itemId: 'a', value: null, photoUrls: ['u'] })).toBe(true)
    expect(isAnswered(item('a', 'text'), { itemId: 'a', value: '  ', photoUrls: [] })).toBe(false)
    expect(isAnswered(item('a', 'boolean'), { itemId: 'a', value: false, photoUrls: [] })).toBe(true)
    expect(isAnswered(item('a', 'checklist'), { itemId: 'a', value: [], photoUrls: [] })).toBe(false)
  })

  test('Faltam N, primeira sem resposta, obrigatórias abertas e Concluir assim mesmo', () => {
    const items = [item('a', 'boolean', { required: true }), item('b', 'text'), item('c', 'text')]
    const f = form(items, [{ itemId: 'a', value: true, photoUrls: [] }])
    expect(missingCount(f)).toBe(2)
    expect(firstUnanswered(f)).toBe(1)
    expect(firstUnanswered(f, 1)).toBe(2)
    expect(requiredMissing(f)).toEqual([])
    expect(canFinishAnyway(f)).toBe(true)
    expect(canFinishAnyway(form(items))).toBe(false)
    expect(requiredMissing(form(items)).map((i) => i.id)).toEqual(['a'])
  })

  test('mesclar por itemId: a resposta do web não apaga a que o app gravou em outra pergunta', () => {
    const fromApp = [{ itemId: 'a', value: 'Bom', photoUrls: [] }]
    expect(applyChange(fromApp, { kind: 'value', itemId: 'b', value: true })).toEqual([...fromApp, { itemId: 'b', value: true, photoUrls: [] }])
  })

  test('valor novo mantém as fotos de outra pessoa; foto nova mantém o valor; tirar foto tira só ela', () => {
    const before = [{ itemId: 'a', value: 'Ruim', photoUrls: ['app.jpg'] }]
    expect(applyChange(before, { kind: 'value', itemId: 'a', value: 'Bom' })).toEqual([{ itemId: 'a', value: 'Bom', photoUrls: ['app.jpg'] }])
    expect(applyChange(before, { kind: 'addPhotos', itemId: 'a', urls: ['web.jpg', 'app.jpg'] })).toEqual([{ itemId: 'a', value: 'Ruim', photoUrls: ['app.jpg', 'web.jpg'] }])
    expect(applyChange(before, { kind: 'removePhoto', itemId: 'a', url: 'app.jpg' })).toEqual([{ itemId: 'a', value: 'Ruim', photoUrls: [] }])
    expect(applyChange([], { kind: 'removePhoto', itemId: 'a', url: 'x' })).toEqual([])
    // The input is never changed (it is the transaction's snapshot).
    expect(before[0]?.photoUrls).toEqual(['app.jpg'])
  })

  test('primeira resposta passa pending para in_progress; completed fica', () => {
    expect(statusAfter('pending', [{ itemId: 'a', value: 1, photoUrls: [] }])).toBe('in_progress')
    expect(statusAfter('pending', [])).toBe('pending')
    expect(statusAfter('completed', [{ itemId: 'a', value: 1, photoUrls: [] }])).toBe('completed')
  })

  test('número validado pelo jeito do país e gravado como digitado (o app grava texto)', () => {
    const parse = (text: string) => parseMoney(text, 'BR')
    expect(numberAnswer(' 12,5 ', parse)).toBe('12,5')
    expect(numberAnswer('abc', parse)).toBeNull()
    expect(numberAnswer('', parse)).toBe('')
  })

  test('resposta em palavras, com a opção traduzida', () => {
    const select = item('s', 'select', { options: ['Bom', 'Ruim'], optionsI18n: { en: ['Good', 'Bad'] } })
    const words = { yes: 'Sim', no: 'Não', photos: (n: number) => `${n} fotos` }
    expect(answerText(select, { itemId: 's', value: 'Ruim', photoUrls: [] }, 'en', words)).toBe('Bad')
    expect(optionText(select, 'Outro', 'en')).toBe('Outro')
    expect(answerText(item('c', 'checklist'), { itemId: 'c', value: ['Bom', 'Ruim'], photoUrls: [] }, 'pt', words)).toBe('Bom, Ruim')
    expect(answerText(item('b', 'boolean'), { itemId: 'b', value: false, photoUrls: [] }, 'pt', words)).toBe('Não')
    expect(answerText(item('p', 'photo_only'), { itemId: 'p', value: null, photoUrls: ['1', '2'] }, 'pt', words)).toBe('2 fotos')
  })
})

describe('editor', () => {
  test('pergunta: texto obrigatório; escolha pede 2 opções, uma por linha', () => {
    expect(questionProblem(' ', 'text', '')).toBe('label')
    expect(questionProblem('Pneu', 'select', 'Bom\n\n')).toBe('options')
    expect(questionProblem('Pneu', 'checklist', 'Bom\nRuim')).toBeNull()
  })

  test('o que falta para salvar: nome, pergunta ou os dois', () => {
    expect(saveProblem('', [])).toBe('both')
    expect(saveProblem('', [item('a', 'text')])).toBe('name')
    expect(saveProblem('X', [])).toBe('question')
    expect(saveProblem('X', [item('a', 'text')])).toBeNull()
  })

  test('Só foto nunca é obrigatória; tradução só fica com o mesmo texto', () => {
    const before = item('a', 'select', { label: 'Pneu', labelI18n: { en: 'Tire' }, optionsI18n: { en: ['Good', 'Bad'] } })
    const same = editedItem(before, { id: 'a', label: 'Pneu', type: 'select', optionsText: 'Bom\nRuim', required: true, allowPhotos: false })
    expect(same).toMatchObject({ labelI18n: { en: 'Tire' }, optionsI18n: { en: ['Good', 'Bad'] }, required: true, allowPhotos: false })
    const changed = editedItem(before, { id: 'a', label: 'Pneus', type: 'select', optionsText: 'Bom\nMédio\nRuim', required: true, allowPhotos: true })
    expect(changed).toMatchObject({ labelI18n: null, optionsI18n: null, options: ['Bom', 'Médio', 'Ruim'] })
    expect(editedItem(null, { id: 'b', label: 'Foto', type: 'photo_only', optionsText: '', required: true, allowPhotos: false })).toMatchObject({ required: false, allowPhotos: true, options: null })
  })

  test('subir e descer uma pergunta; nas pontas nada muda', () => {
    const list = ['a', 'b', 'c']
    expect(moveItem(list, 2, -1)).toEqual(['a', 'c', 'b'])
    expect(moveItem(list, 0, -1)).toBe(list)
    expect(moveItem(list, 2, 1)).toBe(list)
  })
})

describe('listas e plano', () => {
  test('ativos contam isActive != false', () => {
    expect(activeCount([normalizeTemplate('a', { title: 'A' }), normalizeTemplate('b', { title: 'B', isActive: false })])).toBe(1)
  })

  test('pronto já copiado (mesmo id ou mesmo nome) não aparece de novo; desligado também não', () => {
    const ready = [normalizeTemplate('seg-1', { title: 'Entrada' }), normalizeTemplate('seg-2', { title: 'Saída' }), normalizeTemplate('seg-3', { title: 'Teste' }), normalizeTemplate('seg-4', { title: 'Off', isActive: false })]
    const company = [normalizeTemplate('seg-1', { title: 'Entrada' }), normalizeTemplate('mine', { title: 'saida' })]
    expect(readyNotCopied(ready, company).map((t) => t.id)).toEqual(['seg-3'])
  })

  test('busca no título e na descrição, sem acento', () => {
    const template = normalizeTemplate('a', { title: 'Vistoria', description: 'Antes do serviço' })
    expect(templateMatches(template, 'servico', 'pt')).toBe(true)
    expect(templateMatches(template, 'xyz', 'pt')).toBe(false)
  })

  test('limite do plano: Free 1; limites gravados valem; plano vencido volta ao Free; Business sem limite', () => {
    const now = new Date('2026-11-03T12:00:00Z')
    expect(planLimit(null, now)).toBe(1)
    expect(planLimit({ plan: 'pro' }, now)).toBe(10)
    expect(planLimit({ plan: 'starter', limits: { formTemplates: 5 } }, now)).toBe(5)
    expect(planLimit({ plan: 'pro', expiresAt: '2026-10-01T00:00:00Z' }, now)).toBe(1)
    expect(planLimit({ plan: 'business' }, now)).toBe(-1)
    expect(fitsOneMore(1, 1)).toBe(false)
    expect(fitsOneMore(0, 1)).toBe(true)
    expect(fitsOneMore(50, -1)).toBe(true)
  })

  test('quem faz o quê: gerente lê e reabre, consultor e técnico respondem sem reabrir', () => {
    expect(formsAccess('manager', true, false, true)).toEqual({ manage: true, fill: false, reopen: true })
    expect(formsAccess('technician', false, true, true)).toEqual({ manage: false, fill: true, reopen: false })
    expect(formsAccess('owner', true, true, true).reopen).toBe(true)
    expect(formsAccess('admin', true, true, false)).toEqual({ manage: false, fill: false, reopen: false })
  })
})
