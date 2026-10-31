# Mapa de regras de negócio: duas verdades

Commit de referência: `fd9e64da`. Mudanças em API, regras e app ficam como proposta; nada aqui foi aplicado.

**Conclusão.** O app é a dona da maior parte das regras. Um cliente web que grave direto no Firestore teria de repetir totais, pagamentos, fluxo de status e permissões, e as regras do Firestore não pegariam um erro dele. Regra de dinheiro e de status vai para a API; regra de exibição fica no cliente, com casos compartilhados.

Legenda da recomendação: **API** = mover para o servidor; **Casos** = cada cliente implementa, com `contract-cases/`; **Contrato** = dado único em JSON ou no Firestore, sem lógica copiada.

## Regras

| # | Regra | Onde vive | Quem mais repete | Risco se divergir | Recomendação |
|---|---|---|---|---|---|
| 1 | Total da OS | `lib/mobx/order_store.dart:1767` (`updateTotal`), `lib/utils/order_items.dart:4` | `order_payment_math.dart:107` (`computeTotal`), `order_store.dart:661` (contrato), `order.service.ts:292,462,510`, `orders-management.routes.ts:261`, `invoice.service.ts:136` | Valor cobrado e nota fiscal diferentes do que a tela mostra. **Já diverge**, ver D1 | **API**: endpoint de itens que recalcula. Até lá, Casos |
| 2 | Desconto e transações | `order_payment_math.dart:128-260` | `order.service.ts:591` (`applyPaymentTransaction`), `customer-receipt.service.ts` | Saldo errado, total negativo. **Já diverge**, ver D2, D3 | **API**: `POST /v1/app/orders/:id/payments` já existe; falta alinhar permissão (D6) |
| 3 | Situação do pagamento | `order_payment_math.dart:110`, `order_store.dart:808` | `order.service.ts:579`, gatilho `order-payment.service.ts:613` | "Pago" errado na lista e no Financeiro | **API**; leitura e rótulo com Casos |
| 4 | Saldo restante | `order_payment_math.dart:118` | `order.dart:78` e `order_store.dart:186` (sem piso em 0), `order.service.ts:722`, `firebase/web/components/order/OrderTotalSection.vue:43` | Saldo negativo no link do cliente (D4) | **Casos** |
| 5 | Transição de status | `authorization_service.dart:381,435` | `routes/bot/orders.routes.ts:15` (outra tabela, sem perfil), `routes/public/orders.routes.ts:256,338`, `routes/v1/orders.routes.ts:248` (nenhuma validação) | Perfil faz no web o que não faz no app. **Já diverge**, ver D5 | **API**: validar no `PATCH`. Exige aprovação |
| 6 | Efeitos do status | `order_store.dart:759`, `order-trigger.service.ts`, `order-completion.service.ts` | `order.service.ts:421` (`updateOrder` não limpa `payment`; grava `done`, que o app não grava) | OS cancelada pela API segue "paga" | **API** |
| 7 | Permissões por perfil | `lib/models/permission.dart:131` | `app-permission.middleware.ts`, `__tests__/rbac/app-permissions.json` | Baixo: já tem teste cruzado | **Contrato**: gerar a tabela do web do JSON existente |
| 8 | Acesso à OS por status | `authorization_service.dart:281,314,341` | Só exclusão e leitura estão em `firestore.rules:396,424` | Regra de edição precisa valer no servidor | **API** para gravar; **Casos** para a tela |
| 9 | Quem recebe | `authorization_service.dart:527` | `firestore.rules:74`, `customer-receipt.service.ts:48`, `orders.routes.ts:462` (pede `chargeOrder`) | Consultor recebe no app e toma 403 na API (D6) | **API**: uma regra só |
| 10 | Valores desligados (`useFinancial`) | `segment_config_service.dart`, `permission.dart:144` | `app-permission.middleware.ts`, `public/orders.routes.ts:115`, `firebase/web/utils/values.ts:8` | Preço aparece em empresa que desligou | **API**: projeção sem valores para quem não vê preço |
| 11 | Labels por segmento | `segment_config_service.dart:336` | `firebase/web/composables/useOrderI18n.ts:3,413`, `public/orders.routes.ts:26`, `useProfileI18n.ts:344` | Termo errado ("Dispositivo" em vez de "Veículo") | **Contrato**: ler `/segments`. Portar só a ordem de prioridade, com Casos |
| 12 | Status: texto | `lib/l10n/*.arb`, `order.dart:106` | `useOrderI18n.ts:3` | Baixo: hoje batem em pt | **Contrato**: gerar do ARB |
| 13 | Máscaras e campos | `segment_config_service.dart:399`, `custom_field.dart`, `/segments` | Sem cópia no web | Máscara errada por país | **Contrato**: mesmo `customFields`; porta a resolução com Casos |
| 14 | Telefone | `lib/utils/phone_format.dart` (`phone_numbers_parser`) | `format.utils.ts:8` (`normalizePhone` assume 55), `validation.utils.ts:12`, `mask.utils.ts` | Telefone gravado em dois formatos, busca falha | **Casos**, com `libphonenumber-js` |
| 15 | CPF/CNPJ | `lib/utils/tax_id.dart` | `tax-id.utils.ts` (igual) | Nota recusada | **Casos** |
| 16 | Numeração da OS | Gatilho `index.ts:36`; `firestore.service.ts:253` | Só servidor. App nunca envia `number` em edição (`tenant_order_repository.dart:169`) | Web mostra OS sem número até o gatilho rodar | **Manter no servidor**: criar via API devolve o número |
| 17 | Agregados na OS | `Customer.toAggr`, `Device.toAggr` etc. | `order.service.ts:357,365` grava menos campos: sem `taxId`, sem `category`, sem `deviceIds` (D7) | OS da API some da consulta por aparelho; cópias envelhecem | **API**: montar o agregado no servidor |
| 18 | `keywords` de busca | `lib/utils/search_utils.dart:36`, gravado por `customer_store.dart:69` | `search.utils.ts` (acentos por outro método; o servidor soma telefone) | Busca acha cliente de uma origem e não de outra (D8) | **API**, ou trigger único |
| 19 | Contratos recorrentes | `order_store.dart:621,690`: roda **ao abrir o app** | Nenhuma | Web repetindo gera OS em dobro; sem app aberto, nada é gerado | **API**: job agendado, idempotente |
| 20 | Atrasada | `home_groups.dart:41`: inclui orçamento | `order.service.ts:244`: só approved e progress | Contagens diferentes | **Casos** |
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

**Duas telas abertas.** O save da OS regrava `services` e `products` inteiros, então app e web ao mesmo tempo perdem itens. O web precisa gravar por campo ou transação.

`docs/api-spec.yaml` cobre só parte do que existe: faltam `/v1/app/orders`, `team`, `invites`, `devices`, `ai` e `integrations`.

## Divergências que já existem

| # | Divergência | Evidência |
|---|---|---|
| D1 | **Bug.** `computeTotal` ignora `value × quantity`. Remover desconto ou zerar pagamentos numa OS criada pela API ou MCP grava total sem os produtos | `order-totals.json`, `remove-discount-on-api-product-line` |
| D2 | Pagamento em orçamento ou cancelada: app grava `paid`, servidor grava `null` | `payment-on-a-quote` |
| D3 | Desconto acima do total: app grava negativo, servidor limita a 0 | `discount-above-total` |
| D4 | Link do cliente mostra saldo sem piso nem arredondamento | `OrderTotalSection.vue:43` |
| D5 | Quatro regras de status: app, bot, link público, `PATCH` sem validação | `status-transitions.json` |
| D6 | Consultor recebe no app; `/payments` exige `chargeOrder`, que ele não tem | `permission.dart:332`, `orders.routes.ts:462` |
| D7 | API não grava `deviceIds` nem `total` da linha de produto; item sem preço vira 0 no servidor e "sem valor" no app | `order.service.ts:335-347,382` |
| D8 | Clientes do app sem `keywords` de telefone | `customer_store.dart:69` |
| D9 | Moeda por idioma no app, por país no web | Regra 21 |
| D10 | `roundMoney` do JS difere do Dart em valor negativo com meio centavo | `half-cent-rounds-away-from-zero-when-negative` |

Sem divergência encontrada: CPF/CNPJ, repartição de pagamento, `isSafeInvoiceUrl`/`sanitizeReceiptUrl`/`asaas_billing.dart`, `showsValues`/`companyShowsValues`, tabela de permissões.

## Mecanismo anti-divergência

Mesmo desenho que já funciona em `test/models/permission_matrix_test.dart` e `rbac/app-permissions.json`: um JSON no repo, lido pelos testes de cada linguagem.

- **Casos:** `docs/web-app/contract-cases/`. `order-totals`, `payment-status`, `payment-transactions`, `status-transitions`, `order-permissions`.
- **`expect`** é o comportamento do app hoje. **`correct`** marca bug do app: o web segue `correct`. **`divergesIn.functions`** registra diferença conhecida; ao corrigir, o teste falha de propósito e a entrada sai (igual a `gap` da matriz RBAC).
- **Runners:** em `contract-cases/runners/`, como `.txt` para não entrarem no `analyze` nem no CI antes de aprovados. O nome no topo de cada um diz para onde vai.

Validado em 2026-10-31 com os runners copiados temporariamente: Dart 144 de 144 contra `OrderStore` e `AuthorizationService` reais; referência web 144 de 144; `functions` 23 de 23. Dois valores alterados de propósito geraram duas falhas.

| Job | Workflow | Roda | Mudança necessária |
|---|---|---|---|
| Flutter Analyze | `code_quality.yml` | `flutter test` | Adicionar `test/**` e `docs/web-app/contract-cases/**` em `paths`. Hoje alterar só teste não dispara o job |
| Lint + Test | `functions_check.yml` | `npm test` | Adicionar `docs/web-app/contract-cases/**` ao `paths` do `push` |
| Test + Build | `web_check.yml` | `npm test` | Adicionar `docs/web-app/contract-cases/**` ao `paths` |

Ao mudar uma regra no Dart, o job Flutter quebra até o JSON ser atualizado, e o JSON atualizado quebra `functions` e web até acompanharem. `.github/workflows` é `risk:high`.

Faltam casos, quando o web chegar nessas telas: segmento (`getLabel`, `getMasks`), telefone, CPF/CNPJ, atrasada, moeda.

## Propostas que exigem aprovação

1. `PATCH /v1/app/orders/:id`: validar transição por perfil. Muda contrato usado pelo app.
2. `POST /v1/app/orders/:id/items`: recalcular total no servidor.
3. Unificar a regra de `/payments` com `canReceiveOnOrderFor`.
4. Projeção de OS sem valores para quem não tem `viewPrices`.
5. Contratos recorrentes em job agendado.
6. Limites de plano no servidor.
7. Endurecer `firestore.rules` depois de o web gravar via API e de as versões antigas do app saírem. Detalhe fora do repositório.
8. Corrigir D1, com teste, em `_itemsTotal`.
