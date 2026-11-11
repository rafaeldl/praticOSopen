// "Dados para nota" of the customer (customer.invoice-data.*, customer.detail.invoice-recipient,
// docs/NFSE_DIRECT.md) in the company with the direct nota on. The Receita and ViaCEP
// answers are simulated: nothing leaves the emulator.
import { expect, test, type Page } from './test'
import { makeCustomerInN, readCustomerInN } from './data'
import { login } from './helpers'

const shots = process.env.E2E_SHOTS
const shot = async (page: Page, name: string) => {
  if (shots) await page.screenshot({ path: `${shots}/${name}.png` })
}

async function fakeLookups(page: Page) {
  await page.route('https://brasilapi.com.br/api/cnpj/v1/*', (route) =>
    route.fulfill({
      json: {
        razao_social: 'REVENDA EXEMPLO LTDA',
        descricao_tipo_de_logradouro: 'RUA',
        logradouro: 'DAS FLORES',
        numero: '100',
        bairro: 'CENTRO',
        cep: '80010000',
        municipio: 'CURITIBA',
        codigo_municipio_ibge: 4106902,
        uf: 'PR',
        email: 'fiscal@revenda.test',
      },
    }),
  )
  await page.route('https://viacep.com.br/ws/*/json/', (route) =>
    route.fulfill({ json: { logradouro: 'Avenida Paulista', bairro: 'Bela Vista', localidade: 'São Paulo', uf: 'SP', ibge: '3550308' } }),
  )
}

const panel = (page: Page) => page.getByTestId('customer-detail')

async function editCustomer(page: Page, id: string) {
  await login(page, 'nOwner', `customers?customer=${id}`)
  await panel(page).getByTestId('customer-menu').click()
  await page.getByRole('button', { name: 'Editar cliente' }).click()
  const form = page.getByTestId('customer-form')
  await expect(form.getByTestId('customer-invoice-data')).toBeVisible()
  return form
}

test('CNPJ preenche da Receita, CEP preenche o endereço e grava os dados para nota (customer.invoice-data.edit, .lookup)', async ({ page }) => {
  await fakeLookups(page)
  const customer = await makeCustomerInN({ name: `Loja Centro ${Date.now()}` })
  const form = await editCustomer(page, customer.id)
  await form.getByText('Dados para nota').click()
  await form.getByLabel('CPF/CNPJ').fill('11.222.333/0001-81')
  await expect(form.getByTestId('invoice-taxid-note')).toHaveText('Preenchido com os dados da Receita. Confira antes de salvar.')
  await expect(form.getByLabel('Razão social')).toHaveValue('REVENDA EXEMPLO LTDA')
  await expect(form.getByLabel('CEP')).toHaveValue('80010-000')
  await expect(form.getByLabel('Cidade')).toHaveValue('Curitiba')
  await shot(page, 'web-1-dados-para-nota')

  // Another CEP: the place changes, the number typed stays.
  await form.getByLabel('CEP').fill('01310100')
  await expect(form.getByLabel('Rua')).toHaveValue('Avenida Paulista')
  await expect(form.getByLabel('Número')).toHaveValue('100')
  await form.getByRole('switch').check()
  await form.getByTestId('save-customer').click()
  await expect(form).toHaveCount(0)
  const saved = await readCustomerInN(customer.id)
  expect(saved).toMatchObject({
    taxId: '11222333000181',
    legalName: 'REVENDA EXEMPLO LTDA',
    invoiceEmail: 'fiscal@revenda.test',
    autoIssueInvoice: true,
    fiscalAddress: { postalCode: '01310100', street: 'Avenida Paulista', number: '100', district: 'Bela Vista', cityName: 'São Paulo', cityCode: '3550308', state: 'SP' },
  })
})

test('CNPJ que outro cliente tem: bloqueia e manda as notas para ele (customer.invoice-data.unique-tax-id)', async ({ page }) => {
  await fakeLookups(page)
  const owner = await makeCustomerInN({ name: `Revenda ${Date.now()}`, taxId: '11444777000161', legalName: 'REVENDA DONA LTDA' })
  const store = await makeCustomerInN({ name: `Loja Batel ${Date.now()}` })
  const form = await editCustomer(page, store.id)
  await form.getByText('Dados para nota').click()
  await form.getByLabel('CPF/CNPJ').fill('11.444.777/0001-61')
  await form.getByTestId('save-customer').click()
  await expect(page.getByRole('heading', { name: 'REVENDA DONA LTDA já tem este CNPJ' })).toBeVisible()
  await shot(page, 'web-2-cnpj-repetido')
  await page.getByTestId('taxid-send-notas').click()
  await expect(form).toHaveCount(0)
  const saved = await readCustomerInN(store.id)
  expect(saved?.taxId ?? null).toBeNull()
  expect(saved?.invoiceRecipient).toMatchObject({ id: owner.id, name: owner.name, taxId: '11444777000161' })
  await expect(panel(page).getByTestId('customer-invoice-recipient')).toContainText(owner.name)
})

test('"Mandar a nota para outro cliente" pelo menu e "Nenhum" tira (customer.detail.invoice-recipient)', async ({ page }) => {
  const stamp = Date.now()
  const revenda = await makeCustomerInN({ name: `Revenda Menu ${stamp}`, legalName: `REVENDA MENU ${stamp} LTDA` })
  const store = await makeCustomerInN({ name: `Loja Menu ${stamp}` })
  await login(page, 'nOwner', `customers?customer=${store.id}`)
  await expect(panel(page).getByTestId('customer-invoice-recipient')).toHaveCount(0)
  await panel(page).getByTestId('customer-menu').click()
  await page.getByRole('button', { name: 'Mandar a nota para outro cliente' }).click()
  await expect(page.getByRole('heading', { name: 'Para quem vai a nota?' })).toBeVisible()
  const search = page.getByTestId('invoice-recipient-search')
  if (await search.count()) await search.fill(`revenda menu ${stamp}`)
  await shot(page, 'web-3-para-quem-vai-a-nota')
  await page.getByRole('button', { name: new RegExp(`REVENDA MENU ${stamp} LTDA`) }).click()
  await expect(panel(page).getByTestId('customer-invoice-recipient')).toContainText(revenda.name)
  expect((await readCustomerInN(store.id))?.invoiceRecipient).toMatchObject({ id: revenda.id })
  await shot(page, 'web-4-nota-fiscal-para')

  await panel(page).getByTestId('customer-invoice-recipient').getByRole('button', { name: 'Trocar' }).click()
  await page.getByRole('button', { name: /Nenhum: a nota vai para o próprio cliente/ }).click()
  await expect(panel(page).getByTestId('customer-invoice-recipient')).toHaveCount(0)
  expect((await readCustomerInN(store.id))?.invoiceRecipient ?? null).toBeNull()
})
