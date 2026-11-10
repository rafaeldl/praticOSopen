// NFS-e direta in the web (docs/NFSE_DIRECT.md): "Seus CNPJs" with the chosen one
// beside the list (nfse.direct.setup), and "Importar notas" (nfse.direct.import)
// after a new CNPJ's certificate and from a CNPJ that never imported. The
// government is never called: /v1/app/nfse/* is answered here and the emitters
// the server would write are written by the test. All data is fictional.
import { expect, test, type Page, type Route } from './test'
import { deleteDocInN, writeDocInN } from './data'
import { expectNoAxeViolations, login, setTheme } from './helpers'

const shots = process.env.E2E_SHOTS
const shot = async (page: Page, name: string) => {
  if (shots) await page.screenshot({ path: `${shots}/${name}.png` })
}
const ok = (route: Route, data: unknown, status = 200) => route.fulfill({ status, contentType: 'application/json', body: JSON.stringify({ success: true, data }) })

const emitter = (over: Record<string, unknown> = {}) => ({
  taxId: '11222333000181',
  legalName: 'OFICINA EXEMPLO LTDA',
  regime: 'simples',
  cityName: '',
  enabledInCity: false,
  municipalRegistration: null,
  service: null,
  certificate: { notAfter: '2027-10-16T00:00:00Z', uploadedAt: '2026-11-05T12:00:00Z', uploadedBy: { name: 'Nadia Dona Nota' }, status: 'active' },
  importBatchId: null,
  ...over,
})

const proposal = {
  counts: { notas: 42, canceled: 1, customers: 5, newCustomers: 2, completedCustomers: 1, ask: 1, linked: 30, historyOnly: 12 },
  emitter: { fill: {}, view: { legalName: 'OFICINA EXEMPLO LTDA', regime: 'simples', municipalRegistration: '12345', service: { name: 'Manutenção de veículos', issRate: 2.5 }, descriptionStyle: null, dpsSeries: '10' } },
  groups: [
    { key: '45723174000110', taxId: '45723174000110', legalName: 'REVENDA EXEMPLO LTDA', action: 'ask', notas: 4, customerId: 'cust-x', customerName: 'Revenda', stores: [], links: [] },
    { key: '07526557000100', taxId: '07526557000100', legalName: 'FROTA EXEMPLO SA', action: 'complete', notas: 9, customerId: 'cust-y', customerName: 'Frota', stores: [{ customerId: 'cust-z', customerName: 'Frota Filial', orders: 3 }], links: [] },
  ],
  autoIssue: [{ customerId: 'cust-y', customerName: 'Frota', orders: 10, withNota: 9 }],
}

/** The import routes: reads twice, then the proposal; "Importar" answers applied. */
async function fakeImport(page: Page, emitterId: string) {
  const calls: { path: string; body: unknown }[] = []
  let reads = 0
  await page.route('**/v1/app/nfse/imports**', async (route) => {
    const path = new URL(route.request().url()).pathname.replace(/^.*\/v1\/app\/nfse\/imports/, '')
    calls.push({ path, body: route.request().postDataJSON() })
    const base = { id: 'batch-1', emitterId }
    if (path.endsWith('/apply')) return ok(route, { ...base, status: 'applied', proposal, expiresAt: '2026-12-05T00:00:00Z' })
    reads++
    // The second read takes a moment, so "Lendo suas notas no governo…" shows.
    if (reads === 2) await new Promise((resolve) => setTimeout(resolve, 800))
    if (reads < 3) return ok(route, { ...base, status: 'reading', read: { documents: reads * 20, lastNsu: reads * 20 } })
    return ok(route, { ...base, status: 'proposed', read: { documents: 50, lastNsu: 50 }, proposal })
  })
  return calls
}

const drawer = (page: Page) => page.getByTestId('nfse-import')

async function importFlow(page: Page) {
  await expect(drawer(page).getByTestId('nfse-import-headline')).toHaveText('Achamos 42 notas para 5 clientes. Vamos preencher seus clientes e o serviço da nota.')
  await expect(drawer(page).getByTestId('nfse-import-service')).toContainText('Manutenção de veículos · ISS 2,5%')
  await expect(drawer(page).getByTestId('nfse-import-series')).toContainText('10')
  await expect(drawer(page)).toContainText('Nota fiscal para Frota')
  await expect(drawer(page).getByTestId('nfse-import-new')).toHaveText('3 clientes novos')
  await drawer(page).getByTestId('nfse-import-ask-45723174000110').getByLabel('Sim').check()
  await expect(drawer(page).getByTestId('nfse-import-completed')).toHaveText('2 completam clientes que você já tem')
  await drawer(page).getByTestId('nfse-import-auto-cust-y').check()
}

/** Each test cleans only its own emitters: the two run side by side. */
const cleanUp = (...ids: string[]) => Promise.all(ids.map((id) => deleteDocInN(`fiscalEmitters/${id}`).catch(() => undefined)))

test('CNPJ que nunca importou: frase sem cidade, exemplo neutro e "Importar notas" com as respostas (nfse.direct.setup, nfse.direct.import)', async ({ page }) => {
  await cleanUp('e2e-emitter')
  await writeDocInN('fiscalEmitters/e2e-emitter', emitter())
  const calls = await fakeImport(page, 'e2e-emitter')
  await login(page, 'nOwner', 'invoices/direct?e=e2e-emitter')
  const detail = page.getByTestId('nfse-emitter-detail')
  await expect(detail).toBeVisible()
  await expect(detail.getByTestId('nfse-emitter-city')).toHaveText('Ainda não conferimos se este CNPJ já pode emitir nota pelo governo.')
  await expect(detail.getByTestId('nfse-emitter-style')).toHaveText('Serviço 1, Serviço 2')
  await expect(detail).not.toContainText('Troca de óleo')
  // The list starts at the page margin, like the header (it used to touch the edge).
  const head = await page.locator('.page-head .page-title').boundingBox()
  const list = await page.getByTestId('nfse-emitter-e2e-emitter').boundingBox()
  expect(Math.abs((list?.x ?? 0) - (head?.x ?? 0))).toBeLessThan(2)
  await shot(page, '1-emitente-sem-importar')
  await expectNoAxeViolations(page, 'emitente sem importar')

  await detail.getByTestId('nfse-emitter-import').click()
  await expect(drawer(page).getByTestId('nfse-import-reading')).toHaveText('20 documentos lidos')
  await shot(page, '1b-lendo-notas')
  await importFlow(page)
  const body = drawer(page).locator('.drawer-body')
  await body.evaluate((el) => el.scrollTo(0, 0))
  await shot(page, '2-resumo-importacao')
  await body.evaluate((el) => el.scrollTo(0, el.scrollHeight))
  await shot(page, '3-resumo-importacao-fim')
  await expectNoAxeViolations(page, 'resumo da importação')
  await setTheme(page, 'dark')
  await body.evaluate((el) => el.scrollTo(0, 0))
  await shot(page, '4-resumo-importacao-escuro')
  await setTheme(page, 'light')

  await drawer(page).getByTestId('nfse-import-apply').click()
  await expect(drawer(page)).toHaveCount(0)
  await expect(page.getByText('Notas importadas')).toBeVisible()
  await shot(page, '5-importado')
  expect(calls.map((c) => c.path)).toEqual(['', '/batch-1/continue', '/batch-1/continue', '/batch-1/apply'])
  expect(calls[0]?.body).toEqual({ emitterId: 'e2e-emitter' })
  expect(calls[3]?.body).toEqual({ answers: { sameCustomer: { '45723174000110': true }, autoIssueCustomerIds: ['cust-y'] } })
  await cleanUp('e2e-emitter')
})

test('CNPJ novo: depois do certificado, a importação abre sozinha (nfse.direct.import)', async ({ page }) => {
  await cleanUp('e2e-imported', 'e2e-new')
  await writeDocInN('fiscalEmitters/e2e-imported', emitter({ legalName: 'AUTO CENTRO EXEMPLO ME', importBatchId: 'old-batch', cityName: 'Cidade Exemplo', enabledInCity: true }))
  const calls = await fakeImport(page, 'e2e-new')
  await page.route('**/v1/app/nfse/emitters/certificate', async (route) => {
    await writeDocInN('fiscalEmitters/e2e-new', emitter({ taxId: '45723174000110', legalName: 'JOAO EXEMPLO MEI', regime: 'mei' }))
    return ok(route, { emitterId: 'e2e-new', created: true, taxId: '45723174000110', holderName: 'JOAO EXEMPLO MEI', notAfter: '2027-10-16T00:00:00Z' }, 201)
  })
  await login(page, 'nOwner', 'invoices/direct')
  await page.getByTestId('nfse-direct-add').click()
  const form = page.getByTestId('certificate-form')
  await form.locator('input[type="file"]').setInputFiles({ name: 'exemplo.pfx', mimeType: 'application/x-pkcs12', buffer: Buffer.from([1, 2, 3, 4]) })
  await form.getByTestId('certificate-password').fill('senha-de-teste')
  await form.getByTestId('certificate-accept').check()
  await shot(page, '0-adicionar-cnpj')
  await form.getByTestId('certificate-send').click()

  await expect(drawer(page)).toBeVisible()
  await expect(page).toHaveURL(/e=e2e-new/)
  await importFlow(page)
  await drawer(page).getByTestId('nfse-import-apply').click()
  await expect(drawer(page)).toHaveCount(0)
  expect(calls[0]?.body).toEqual({ emitterId: 'e2e-new' })
  await expect(page.getByTestId('nfse-emitter-detail')).toContainText('JOAO EXEMPLO MEI')
  await cleanUp('e2e-imported', 'e2e-new')
})
