# Mapa de regras de negócio: duas verdades

Mapa feito em `fd9e64da`; casos de contrato e divergências revistos em `e05d6414`. A API de OS do app web (`docs/WEB_API.md`) zerou o `divergesIn.functions`: o que sobra diverge no app ou no web.

**Conclusão.** O app é a dona da maior parte das regras. Um cliente web que grave direto no Firestore teria de repetir totais, pagamentos, fluxo de status e permissões, e as regras do Firestore não pegariam um erro dele. Regra de dinheiro e de status vai para a API; regra de exibição fica no cliente, com casos compartilhados.

Legenda da recomendação: **API** = mover para o servidor; **Casos** = cada cliente implementa, com `contract-cases/`; **Contrato** = dado único em JSON ou no Firestore, sem lógica copiada.

## Regras

| # | Regra | Onde vive | Quem mais repete | Risco se divergir | Recomendação |
|---|---|---|---|---|---|
| 1 | Total da OS | `lib/mobx/order_store.dart:1767` (`updateTotal`), `lib/utils/order_items.dart:4` | `order_payment_math.dart:107` (`computeTotal`), `order_store.dart:661` (contrato), `order.service.ts:292,462,510`, `orders-management.routes.ts:261`, `invoice.service.ts:136` | Valor cobrado e nota fiscal diferentes do que a tela mostra. Bug do app corrigido (D1); servidor recalcula em `order-items.ts` (`order-totals`, `order-items`) | **API**: feito, `/v1/app/orders/:id/items` |
| 2 | Desconto e transações | `order_payment_math.dart:128-260` | `order.service.ts:591` (`applyPaymentTransaction`), `customer-receipt.service.ts` | Saldo errado, total negativo. **Já diverge**, ver D2, D3 | **API**: feito; rotas de pagamento, desconto, zerar e marcar pago (`docs/WEB_API.md`) |
| 3 | Situação do pagamento | `order_payment_math.dart:110`, `order_store.dart:808` | `order.service.ts:579`, gatilho `order-payment.service.ts:613` | "Pago" errado na lista e no Financeiro | **API**; leitura e rótulo com Casos |
| 4 | Saldo restante | `order_payment_math.dart:118` | `order.dart:78` e `order_store.dart:186` (sem piso em 0), `order.service.ts:722`, `firebase/web/components/order/OrderTotalSection.vue:43` | Saldo negativo no link do cliente (D4) | **Casos** |
| 5 | Transição de status | `authorization_service.dart:381,435` | `app-permission.middleware.ts` (`PATCH` e bot), `firestore.rules` (`orderStatusChangeAllowed`), `routes/bot/orders.routes.ts:18` (tabela mais estreita além do perfil), `routes/public/orders.routes.ts` (cliente só decide orçamento) | Perfil faz no web o que não faz no app. Alinhado, ver D5 | **API**: já valida. Manter os casos |
| 6 | Efeitos do status | `order_store.dart:759`, `order-trigger.service.ts`, `order-completion.service.ts` | `order.service.ts:421` (`updateOrder` não limpa `payment`; grava `done`, que o app não grava) | OS cancelada pela API segue "paga" | **API** |
| 7 | Permissões por perfil | `lib/models/permission.dart:131` | `app-permission.middleware.ts`, `__tests__/rbac/app-permissions.json` | Baixo: já tem teste cruzado | **Contrato**: gerar a tabela do web do JSON existente |
| 8 | Acesso à OS por status | `authorization_service.dart:281,314,341` | Só exclusão e leitura estão em `firestore.rules:396,424` | Regra de edição precisa valer no servidor | **API** para gravar; **Casos** para a tela |
| 9 | Quem recebe | `authorization_service.dart:527` | `firestore.rules:74`, `customer-receipt.service.ts:48`, `app-permission.middleware.ts` (`canReceiveOnOrder`) | Resolvido (D6) | **API**: uma regra só |
| 10 | Valores desligados (`useFinancial`) | `segment_config_service.dart`, `permission.dart:144` | `app-permission.middleware.ts`, `public/orders.routes.ts:115`, `firebase/web/utils/values.ts:8` | Preço aparece em empresa que desligou | **API**: projeção sem valores para quem não vê preço |
| 11 | Labels por segmento | `segment_config_service.dart:336` | `firebase/web/composables/useOrderI18n.ts:3,413`, `public/orders.routes.ts:26`, `useProfileI18n.ts:344` | Termo errado ("Dispositivo" em vez de "Veículo") | **Contrato**: ler `/segments`. Portar só a ordem de prioridade, com Casos |
| 12 | Status: texto | `lib/l10n/*.arb`, `order.dart:106` | `useOrderI18n.ts:3` | Baixo: hoje batem em pt | **Contrato**: gerar do ARB |
| 13 | Máscaras e campos | `segment_config_service.dart:399`, `custom_field.dart`, `/segments` | Sem cópia no web | Máscara errada por país | **Contrato**: mesmo `customFields`; porta a resolução com Casos |
| 14 | Telefone | `lib/utils/phone_format.dart` (`phone_numbers_parser`) | `format.utils.ts` (`normalizePhone`, `dialCodeOf`), `validation.utils.ts:12`, `mask.utils.ts` | Telefone gravado em dois formatos, busca falha | **Casos**, com `libphonenumber-js` |
| 15 | CPF/CNPJ | `lib/utils/tax_id.dart` | `tax-id.utils.ts` (igual) | Nota recusada | **Casos** |
| 16 | Numeração da OS | Gatilho `index.ts:36`; `firestore.service.ts:253` | Só servidor. App nunca envia `number` em edição (`tenant_order_repository.dart:169`) | Web mostra OS sem número até o gatilho rodar | **Manter no servidor**: criar via API devolve o número |
| 17 | Agregados na OS | `Customer.toAggr`, `Device.toAggr` etc. | `order.service.ts:357,365` grava menos campos: sem `taxId`, sem `category`, sem `deviceIds` (D7) | OS da API some da consulta por aparelho; cópias envelhecem | **API**: montar o agregado no servidor |
| 18 | `keywords` de busca | `lib/utils/search_utils.dart:36`, gravado por `customer_store.dart:69` | `search.utils.ts` (acentos por outro método; o servidor soma telefone) | Busca acha cliente de uma origem e não de outra (D8) | **API**, ou trigger único |
| 19 | Contratos recorrentes | `order_store.dart:621,690`: roda **ao abrir o app** | Nenhuma | Web repetindo gera OS em dobro; sem app aberto, nada é gerado | **API**: job agendado, idempotente |
| 20 | Atrasada | `home_groups.dart:41`: inclui orçamento | `order.service.ts` (`getOverdueOrders`): igual à tela | Resolvido | **Casos** |
| 21 | Moeda | `format_service.dart:129`: pelo idioma do app | `firebase/web/utils/format.ts:1`: pelo país da empresa | Mesma OS em R$ e em $ (D9) | **Contrato**: decidir uma regra. País da empresa é a certa |
| 22 | Limites de plano | `feature_gate_service.dart`, `subscription.dart` | `subscription-plans.ts` só guarda; não barra | Web sem limite, receita | **API**: barrar no servidor, decidir plano no web |
| 23 | Recibo de várias OS | `receipt_plan.dart`, `payment_allocation.dart` | `customer-receipt.service.ts`, `payment-allocation.ts` (iguais) | Baixo: mesma regra em centavos | **API**: o web usa a rota existente |
| 24 | Cadastro da empresa | `bootstrap_service.dart`, `onboarding_service.dart` | `registration.service.ts`, `bootstrap-server.service.ts` | Empresa nova diferente por origem | **API** |

## Permissões dentro da mesma empresa

O isolamento entre empresas está coberto. Dentro da mesma empresa, parte das restrições por perfil é aplicada pelo cliente, não pelo servidor. Por isso o web não pode herdar regra só da tela: leitura de valores e gravação de dinheiro e status passam pela API, com a mesma matriz de permissões. O detalhe fica fora do repositório.

## Gravações: Firestore direto ou API

| Dado | Cliente grava direto | Só servidor |
|---|---|---|
| OS: itens, status, datas, cliente, total, desconto | Sim (`set(merge)` da OS inteira) | |
| OS: `transactions`, `paidAmount`, `paid`, `payment` | Sim (`updatePayments`, `applyPaymentFieldUpdate`) | Também o webhook Asaas |
| OS: `number`, `completedAt`, `lastPaymentAt`, `paymentSyncedAt` | | Sim |
| Recibos | Sim (batch); API para consultor com OS alheia | Recibos `asaas_*` |
| Clientes, aparelhos, catálogo, formulários, fotos, comentários | Sim | |
| Empresa e `memberships` de exibição | Sim, admin | `subscription`, `private/*` |
| Cobranças, notas, `settings/*`, convites, equipe, tokens de link | | Sim (`/v1/app/*`) |

**Duas telas abertas.** O save da OS do app regrava `services` e `products` inteiros. O web grava itens pela API, em transação e com `expectedUpdatedAt`; um save do app por cima ainda pode tirar o que o web acabou de pôr.

`docs/api-spec.yaml` cobre só parte do que existe: faltam `team`, `invites`, `devices`, `ai` e `integrations`.

## Divergências que já existem

| # | Divergência | Evidência |
|---|---|---|
| D1 | **Corrigida.** `computeTotal` usa `productLineTotal`; linha sem `total` vale `value × quantity` | `order-totals.json`, `payment-transactions.json`, sem `divergesIn` |
| D2 | **Corrigida.** Pagamento em orçamento ou cancelada: `payment` null e `paid` false. O servidor faz em todas as rotas; o app também, online e offline | `payment-on-a-quote`, `payment-on-a-canceled-order`, `discount-on-a-quote`, `remove-payment-on-a-quote` |
| D3 | **Corrigida.** Total nunca negativo. O servidor limita a 0 em todos os caminhos (`computeOrderTotal`), inclusive ao remover item; o app também | `discount-above-total`, `discount-above-items-stops-at-zero`, `remove-keeps-total-above-zero` |
| D4 | **Corrigida no app** (`Order.remainingBalance` e `OrderStore.remainingBalance` com piso em 0 e arredondados). **Aberta no link do cliente:** `OrderTotalSection.vue:42` mostra saldo sem piso nem arredondamento. Fora dos casos: é `firebase/web` | `OrderTotalSection.vue:42`, `test/models/order_remaining_balance_test.dart` |
| D5 | **Resolvida no essencial.** App, `PATCH`, bot e `firestore.rules` usam o mesmo fluxo por perfil. O bot ainda aplica tabela mais estreita (não reabre) e o link do cliente só decide orçamento. Mesmo status: o servidor aceita de propósito (`sameStatus`) | `status-transitions.json`, `enforcedBy` |
| D6 | **Corrigida.** `POST /:id/payments` usa `canReceiveOnOrder` (igual a `canReceiveOnOrderFor`). Desconto em rota própria, só do financeiro | `order-receive.json`, casos `consultant-own-*-values-on` |
| D7 | **Corrigida.** A API grava `deviceIds` e o `total` da linha, aceita `total` com `editPrices` e mantém item sem preço como `null` | `order-totals.json`, `order-items.json`; `deviceIds` em `order.service.ts:382` |
| D8 | **Corrigida no app** ao criar cliente: `customerKeywords` grava nome sem stopwords, frase e telefone, como `customer.service.ts`. Editar cliente no app ainda não regrava `keywords`. Fora dos casos | `test/utils/search_utils_test.dart` |
| D9 | **Aberta no app, de propósito por ora.** Moeda pelo país da empresa é a decisão; o app segue o idioma. O `country` da empresa vem do idioma do app no cadastro (`onboarding_flow.dart:90`), então não é confiável, e a troca mexe em ~28 telas e na leitura dos campos de valor. `getFormatContext` não conhece PY, BO, AO e MZ | `currency.json` |
| D10 | **Corrigida.** `roundMoney` (`utils/money.ts`) é simétrico, como o Dart | `round-money.json` |

Achados novos ao escrever os casos (os do servidor, já corrigidos):

- **Valor na resposta.** Corrigido: lista, detalhe e respostas de escrita passam por `order-projection.ts` (`visibility.json`).
- **Telefone.** Corrigido: `normalizePhone` mantém o país de quem digita `+` e usa o país da empresa (`phone.json`).
- **Apagar OS.** `firestore.rules` recusa apagar OS com dinheiro, exceto admin; `canDeleteOrder` no app e `DELETE /v1/app/orders/:id` seguem a mesma regra (`order-delete.json`).
- **Recibo.** Corrigido: `buildReceiptPlan` recusa orçamento, cancelada e valor acima do aberto, como o servidor (`receipts.json`).
- **Atrasada.** Corrigido: `getOverdueOrders` inclui orçamento, como a tela (`overdue.json`).

Sem divergência encontrada: CPF/CNPJ, repartição de pagamento, `isSafeInvoiceUrl`/`sanitizeReceiptUrl`/`asaas_billing.dart`, `showsValues`/`companyShowsValues`, tabela de permissões.

## Mecanismo anti-divergência

Mesmo desenho que já funciona em `test/models/permission_matrix_test.dart` e `rbac/app-permissions.json`: um JSON no repo, lido pelos testes de cada linguagem.

- **Casos:** `docs/web-app/contract-cases/*.json`. `runsIn` diz quais linguagens leem cada arquivo.
- **`expect`** é o que todas as linguagens fazem. **`correct`** é a decisão quando alguém ainda diverge.
- **`divergesIn.<linguagem>`** é o que aquela linguagem faz hoje, mesclado sobre a decisão. Cada runner testa `divergesIn[linguagem]` sobre `correct ?? expect`. Corrigiu a linguagem sem tirar a entrada, o teste falha de propósito.
- **Sem divergência:** caso com `correct` e sem `divergesIn` também falha: promova para `expect`. Idem entrada igual à decisão, id repetido e linguagem desconhecida.
- **Arquivo novo:** se nomeia uma linguagem em `runsIn` e o runner dela não lê, falha.
- **Runners:** `test/contract/contract_cases_test.dart` (app real: `OrderStore`, `AuthorizationService`, `OrderPaymentMath`) e `firebase/functions/src/__tests__/contract-cases.test.ts` (serviços reais em Firestore fake; rotas `v1/orders` reais onde a regra mora na rota). O do web está em `contract-cases/runners/*.txt` até entrar em `feat/webapp-foundation`; ele lê `correct ?? expect`.
- **Limites:** `firestoreRules` e `order-delete.json` descrevem as regras, mas não rodam no emulador. `order-delete.json` roda nas rotas reais de Functions.

| Job | Workflow | Roda | `paths` |
|---|---|---|---|
| Flutter Analyze | `code_quality.yml` | `flutter test` | `test/**`, `docs/web-app/contract-cases/**` |
| Lint + Test | `functions_check.yml` | `npm test` | `docs/web-app/contract-cases/**`, no `push` |
| Web | `webapp_check.yml`, a criar em `feat/webapp-foundation` | `npm test` | `docs/web-app/contract-cases/**`. `web_check.yml` é o link do cliente e não roda estes casos |

Ao mudar uma regra no Dart, o job Flutter quebra até o JSON ser atualizado, e o JSON atualizado quebra `functions` e web até acompanharem. `.github/workflows` é `risk:high`.

Ao juntar com o web: `orderTotal` de `runners/order-rules.ts.txt` precisa limitar a 0 (D3), senão `order-totals.json` falha lá.

## Propostas que exigem aprovação

1. ~~`PATCH /v1/app/orders/:id`: validar transição por perfil.~~ Feito.
2. ~~`POST /v1/app/orders/:id/items`: recalcular total no servidor.~~ Feito (`docs/WEB_API.md`).
3. ~~Unificar a regra de `/payments` com `canReceiveOnOrderFor` (D6).~~ Feito.
4. ~~Projeção de OS sem valores para quem não tem `viewPrices`.~~ Feito.
5. Contratos recorrentes em job agendado.
6. Limites de plano no servidor.
7. Endurecer `firestore.rules` depois de o web gravar via API e de as versões antigas do app saírem. Detalhe fora do repositório.
8. Corrigir D9 no app, tirando as entradas de `divergesIn` (servidor já segue a decisão).
