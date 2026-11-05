# QUICK_REGISTER.md

## Visão Geral

Cadastro rápido de dentro da OS. Quem digita um cliente, veículo/aparelho, serviço ou peça que ainda não existe não cadastra mais só o nome: o sistema pede, na hora, só os 1 ou 2 dados que as empresas de fato preenchem. Depois, o que faltar aparece como link na própria OS ("+ WhatsApp", "+ Placa") e abre o cadastro sem sair dela.

Por que estes campos (leitura agregada da produção em 2026-11-05, 20 empresas que usam de verdade, cadastros dos últimos 90 dias):

| Cadastro | Preenchido | Quase nunca |
|---|---|---|
| Cliente | telefone 62%, endereço 46% (26% ficaram só com o nome) | e-mail, CPF/CNPJ |
| Veículo/aparelho | placa ou série 100%, modelo 93% | marca 18%, ano, cor |
| Serviço/peça | preço 94% a 98% | foto |

## Arquitetura

### Web (`firebase/webapp`)

- `src/lib/orders/quick-create.ts`: regras puras e gravações.
  - `customerDraft` e `deviceDraft`: o texto vai para o campo que parece (só dígitos é telefone; placa BR é série em maiúsculas).
  - `createCustomer`, `createDevice`, `createItem`: `POST /v1/app/customers|devices|services|products`. O preço só vai com `editPrices`.
  - `missingOnOrder`: o que falta na OS (telefone do cliente; série, ou modelo vazio/igual à série, de cada aparelho).
  - `customerSummary`: a cópia do cliente que a OS guarda (id, nome, telefone, e-mail, CPF/CNPJ).
- `src/components/orders/QuickCreate.vue`: o bloco. Na Nova OS aparece no lugar da busca; na OS salva, numa folha pequena (`Layer kind="sheet"`).
- `NewOrderDrawer.vue` e `OrderDetail.vue`: abrem o bloco no "+ Cadastrar", mostram os links do que falta e abrem `CustomerForm`/`DeviceForm` (carregados sob demanda, com os textos de cadastros).

### App (Flutter)

- Cliente e aparelho: o seletor já abria o formulário completo (`CustomerFormScreen`/`DeviceFormScreen` em `FormSheet`). Agora o cursor começa no telefone quando o nome veio digitado, e na placa/série quando o modelo veio.
- Serviço/peça: "Cadastrar «X»" (`order_item_search_screen.dart`) pergunta serviço ou peça (quando pode os dois) e abre o `CatalogItemForm` com o nome e o cursor no preço (`focusPrice`).
- OS salva: `lib/screens/order/order_missing_data.dart` (`missingOnOrder`, mesma regra do web) e os links no cabeçalho de `order_screen_v2.dart`. `OrderScreenActions.editCustomer`/`editDevice` empurram o formulário do registro; `OrderStore.refreshCustomer`/`refreshDevice` atualizam a cópia na OS.

### Firestore

Nada novo. Cliente em `companies/{id}/customers`, aparelho em `companies/{id}/devices`, itens em `companies/{id}/services|products`. A OS guarda cópias (`customer`, `device`, `devices`), atualizadas quando o cadastro é completado pela OS.

## Fluxo de Dados

```
"+ Cadastrar «X»"
  web: bloco (2 campos) ── Enter ──> POST /v1/app/... ──> escolhido na OS
       └─ "Mais dados" ──> CustomerForm/DeviceForm com o rascunho ──> escolhido
  app: FormSheet do formulário completo (cursor no campo que falta) ──> escolhido

OS salva com algo faltando
  "+ WhatsApp" / "+ Placa" / "+ Modelo"
  web: gaveta por cima da OS ──> PATCH do cadastro ──> PATCH da OS (cópia)
  app: formulário empurrado ──> save do cadastro ──> OrderStore.refresh* (cópia)
```

## Regras de Negócio

1. Só o nome é obrigatório no cliente e no item; no aparelho, modelo **ou** placa/série (como no cadastro completo).
2. Telefone opcional. Telefone de outro cliente avisa no bloco e oferece "Usar {nome}".
3. Rótulo e máscara da placa/série vêm do ramo (`device.serial`: Placa, IMEI, Número de série...). Telefone com a máscara do país.
4. Preço só aparece e só é gravado para quem tem `editPrices` (e `viewPrices`).
5. Na Nova OS, salvar com um bloco aberto avisa "Termine ou cancele o cadastro aberto". Esc volta para a busca.
6. Links do que falta: só quem edita a OS e tem `manageCustomers` (telefone) ou `manageDevices` (aparelho). Nunca pede e-mail ou CPF.
7. Completar pela OS atualiza a cópia **desta** OS. Outras OS do mesmo cliente não mudam.
8. Web: o menu "…" da OS tem "Dados do cliente" e "Dados de {aparelho}" (editam por cima) além de "Abrir cliente"/"Abrir {aparelho}" (vão para a tela do registro).

## Testes

- Web: `tests/quick-create.test.ts` (vitest) e `e2e/quick-register.spec.ts`, `e2e/order-close.spec.ts`, `e2e/orders-review.spec.ts` (Playwright no Emulator Suite).
- App: `test/screens/order/order_missing_data_test.dart`, grupo "completar pela OS" em `order_screen_v2_extras_test.dart`, "Cadastrar «X»" em `catalog_screens_test.dart` e `order_screen_v2_test.dart`.
- Matriz: `customer.picker.create`, `device.list.pick-create`, `order.item-search.create`, `order.quick.complete` e `order.quick.missing-rule` em `docs/web-app/parity-matrix.yaml`.
