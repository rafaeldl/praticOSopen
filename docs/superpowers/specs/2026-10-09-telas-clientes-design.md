# Telas do app: clientes

Status: proposta · 2026-10-09 · base: `docs/APP_DESIGN_SYSTEM.md` · componentes: `2026-10-09-telas-componentes-design.md`

Protótipos: canvas https://claude.ai/artifact/NfHsv1Ge52LXGdpd9ZYihz, página "Telas do app". Nenhuma tela deste grupo usa `AppColors`/`AppTypography` hoje (zero imports de `lib/theme/`): vale para todas e não se repete abaixo.

## Telas do grupo

| Tela | Arquivo | Uso | O que muda |
|---|---|---|---|
| Aba Clientes | `lib/screens/menu_navigation/home_customer_list.dart` (2ª aba, `navigation_controller.dart:35`) | Semanal/diário | Toque abre a tela do cliente (hoje filtra a aba Início). Linha sem avatar, com status de OS em aberto |
| Tela do cliente | **nova** | Diário | Ligar, WhatsApp, "Nova OS para Ana", OS do cliente, total e falta receber. Editar/apagar no "…" |
| Escolher cliente na OS | `lib/screens/customers/customer_list_screen.dart` (`/customer_list`, aberta em `order_form.dart:1993-2001`) | Diário | Título de tarefa, `AddRow`, "Usados por último", sem deslize |
| Novo/editar cliente | `lib/screens/customers/customer_form_screen.dart` + `lib/widgets/tax_id_form_field.dart` | Diário | Só Nome e Telefone na 1ª tela; resto atrás de `MoreFieldsLink`; `AppBottomBar` "Salvar cliente" |
| (morto) | `lib/screens/customers/customer_os_list.dart` | — | Remover: sem rota nem import em `lib/`/`test/` |

## Problema atual (achados)

| Regra | Evidência | O que o usuário vê | Correção |
|---|---|---|---|
| **Aba** R1 / Z | `home_customer_list.dart:230-236`: toque aplica `setCustomerFilter`, recarrega e troca para a aba 0. Seta `chevron_right` em `:294` | Toca no cliente e cai no Início com um filtro de 13px (`home.dart:335-358`). Não existe tela do cliente | Toque abre a tela do cliente. O histórico vira a lista "OS da Ana" lá dentro |
| R4 | Editar só por toque longo (`:237-243`) ou deslize (`:191-198`); apagar só por deslize (`:199-220`) | Quem não conhece o gesto não acha "Editar" | Editar e Apagar no `MoreMenu` da tela do cliente; deslize fica como atalho |
| R3 | Vazio `'${l10n.no} ${customer} ${l10n.registered}'` (`:125`); `no` está duplicada em `app_pt.arb:57/677/724` e vence "Não" | **"Não cliente cadastrado"** | `EmptyState` com frase pronta de `EntityPhrases` |
| R3 | `'${doYouWantToRemoveThe} ${customer} "${name}"?'` (`:206`), título "Confirmar Exclusão" (`:205`) | Frase formal montada aos pedaços | "Apagar Ana Ribeiro?" / "As OS dela continuam salvas." / "Apagar" e "Voltar" |
| Tipografia / a11y | Telefone 14 (`:286`); iniciais 16 `systemGrey` sobre `systemGrey5` (`:255-265`); "+" só ícone (`:44-49`) | Telefone pequeno, avatar sem função, "+" lido como "botão" | `AppListRow` (19/17), sem avatar, "+" com `Semantics(label: l10n.newCustomer)` |
| **Escolher** R1 | Título "Clientes" (`customer_list_screen.dart:43`) mesmo em modo seleção (`:34`) | Não diz que é para escolher | "Quem é o cliente?" |
| R4 | `Dismissible` ativo no modo seleção (`:195-245`) | Dá para apagar um cliente no meio da OS | Sem deslize quando `isSelectionMode` |
| R6 | Criar só pelo "+" do topo (`:44-53`); vazio "Toque em + para adicionar…" 14px (`:131`, `:140`) | Leigo procura o botão embaixo | `AddRow` "Cadastrar cliente novo" no topo da lista |
| Cópia | `_buildCustomerItem` (`:183-325`) ≈ `home_customer_list.dart:163-310` | — | As duas telas usam o mesmo `AppListRow` |
| **Form** Z6 | "Salvar" é texto no topo (`customer_form_screen.dart:69-76`) | Com teclado aberto, o principal é um texto no canto | `AppBottomBar` "Salvar cliente" |
| R4 | E-mail, CPF/CNPJ (`:133-137`, só para cobrar pelo Asaas, comentário `:132`) e endereço (`:138-171`) sempre visíveis | 5 campos para quem só precisa de nome e WhatsApp | Nome + Telefone; o resto em `MoreFieldsLink` |
| Z / R3 | Círculo 100×100 sem ação (`:86-100`); "Nome Completo" (`:110`); ícone de mapa 16px como alvo (`:139-163`); rótulos 16 (`:108`, `:125`, `:161`) | Espaço morto, Title Case, alvo minúsculo | Remover círculo; `ScreenTitle` "Novo cliente"; "Abrir no mapa" como `TextLink` só com endereço; `AppFormField` |

## Tela proposta

### "Clientes · aba (busca por placa)"
1. Topo (`AppTopBar`): sem voltar (raiz de aba). À direita só "+" com rótulo "Novo cliente".
2. Título: "Clientes". Subtítulo: "38 clientes" (contagem real da lista).
3. Próximo passo: não tem (tela de busca).
4. Conteúdo: `AppSearchField` "Buscar por nome ou telefone" (a busca já cobre nome e telefone, `home_customer_list.dart:140-141`). Seções por letra (`SectionLabel` "A", "C"…). `AppListRow`: nome; linha 2 `StatusDot` "1 OS aberta" (`warning`) ou "1 OS atrasada" (`warning` negrito), **só quando houver**; telefone "(11) 90000-0001"; seta (abre outra tela).
5. Resumo: não tem. 6. Barra fixa: nenhuma (tab bar).
- Sai da 1ª tela: avatar de iniciais, deslize como único caminho de editar/apagar.
- Vazio: `EmptyState` "Você ainda não tem clientes" + `TextLink` "Cadastrar o primeiro cliente". Busca sem resultado: "Nenhum cliente com “Ana”".
- Dado de "OS aberta/atrasada": não existe no `Customer` (`lib/models/customer.dart:9-20`). Calcular com uma só consulta das OS em aberto (`status` em `approved`/`progress`, já existe em `tenant_order_repository.dart:332-337`) agrupada por `customer.id` no cliente. Atrasada = `dueDate` no passado.

### "Clientes · cliente com veículos"
1. Topo: "‹ Clientes" + "…" (`MoreMenu`: "Editar", `DestructiveAction` "Apagar").
2. Título: "Ana Ribeiro". Subtítulo: "(11) 90000-0001".
   Logo abaixo, dois `SecondaryButton`: "Ligar" e "WhatsApp" (só com telefone; sem telefone viram `TextLink` "Adicionar telefone").
3. `NextStepBlock`: "Abrir uma OS para Ana?" + `PrimaryButton` "Nova OS para Ana".
4. Conteúdo: `SectionLabel` "OS da Ana". `AppListRow` por OS: "OS 186 · Fiat Uno 2015", valor à direita (`FormatService`), `StatusDot` via `OrderStatusStyle`, data. Toque abre a OS.
   Dado: `streamOrders(customerId:)` já filtra por `customer.id` (`tenant_order_repository.dart:347-349`) e o índice `customer.id + createdAt↓` existe (`firebase/firestore.indexes.json`).
5. `SummaryLine`: "Total gasto R$ 1.740" / "Falta receber R$ 1.250" (soma de `total` e de `remainingBalance`, `lib/models/order.dart:23`, `:72`, sem OS canceladas). Some se o cliente não tem OS.
6. Barra fixa: nenhuma (o `PrimaryButton` está no bloco 3).
- Vazio (cliente sem OS): seção "OS da Ana" some; o bloco 3 continua.
- Erro ao carregar OS: frase "Não deu para carregar as OS. Tente de novo." + `TextLink` "Tentar de novo".
- "Nova OS para Ana": abre `/order` com `{'order': Order()..customer = customer.toAggr()}`. Uma `Order` sem `id` nem `number` cai em `_store.setOrder(orderArg)` (`order_form.dart:79-96`). **Alinhar com a sessão da OS** (ver abaixo).

### "Na OS · escolher cliente"
1. Topo: "‹ OS nova". Sem "…".
2. Título: "Quem é o cliente?". Subtítulo: "Toque para escolher".
3. Próximo passo: `AppSearchField` "Buscar por nome ou telefone" com foco automático.
4. Conteúdo: `AddRow` "Cadastrar cliente novo" (após salvar, volta direto para a OS, como já faz `customer_list_screen.dart:48-52`). `SectionLabel` "Usados por último" com até 5 clientes; depois a lista por letra. `AppListRow` nome + telefone, **sem seta, sem deslize**. Toque escolhe e volta.
5–6. Não tem.
- "Usados por último": **não existe dado hoje**. `Customer` não tem data de uso (`customer.dart:9-20`; só `createdAt`/`updatedAt` de `base_audit.dart:5-8`) e a lista é por nome (`tenant_customer_repository.dart:24-28`). Opção sem migração: pegar os clientes distintos das últimas OS (`streamOrders` ordena por `createdAt↓`, `tenant_order_repository.dart:328`). Até decidir (ver perguntas), a seção não aparece e a lista fica alfabética.
- Vazio: `EmptyState` "Nenhum cliente ainda" + `PrimaryButton` "Cadastrar cliente".

### "Clientes · novo cliente"
1. Topo: "‹ Voltar". 2. Título: "Novo cliente" (editar: "Editar cliente").
3. Próximo passo: não tem.
4. Conteúdo: `AppFormField` "Nome" (placeholder "Ex.: Ana Ribeiro") e `AppFormField` "Telefone ou WhatsApp" (teclado de telefone, máscara atual mantida) com dica "Usado para mandar o orçamento e o aviso de pronto." Depois `MoreFieldsLink` "+ Mais dados (e-mail, CPF ou CNPJ, endereço)", que revela e-mail, `TaxIdFormField` (só BR, `customer_form_screen.dart:133`), endereço com "Abrir no mapa" e os campos do segmento (`DynamicFieldBuilder`, `:219`). No modo editar, campos com valor aparecem direto.
5. Resumo: não tem. 6. `AppBottomBar` com `PrimaryButton` "Salvar cliente".
- Sai: círculo de pessoa, "Salvar" do topo, cabeçalhos em CAIXA ALTA (`:211-216`).
- Erro: nome vazio → dica embaixo do campo em `danger` "Digite o nome do cliente".

## Componentes usados

`AppTopBar`, `ScreenTitle`, `NextStepBlock`, `AppBottomBar`, `SummaryLine`, `PrimaryButton`, `SecondaryButton`, `TextLink`, `DestructiveAction`, `MoreMenu`, `SectionLabel`, `AppListRow`, `AddRow`, `StatusDot`, `OrderStatusStyle`, `EmptyState`, `AppSearchField`, `AppFormField`, `MoreFieldsLink`, `EntityPhrases`.

**Componente novo a adicionar no doc comum:** índice por letra na lista (cabeçalho de seção "A", "B"… do `AppListRow`). Pode ser só uma variante de `SectionLabel`; decidir lá.

## Fora de escopo / alinhar com a sessão da OS

- "Nova OS para Ana" precisa que a OS nova aceite cliente já preenchido e pule a etapa "Quem é o cliente?". Hoje o argumento `order` existe (`order_form.dart:79-96`), mas o fluxo novo da OS é da outra sessão: combinar o contrato (argumento `customer` ou `order` pré-montado).
- Toque numa OS da lista do cliente abre a tela da OS (da outra sessão).
- O filtro de cliente na aba Início (`home.dart:318-358`, `order_store.dart:105`, `:1728`) deixa de ser usado pela aba Clientes. Remover ou manter fica com quem redesenhar o Início.
- Rótulo da aba (`navigation_controller.dart:58`, `l10n.customers`) e título (`config.customerPlural`) podem divergir se um segmento renomear "cliente". Não confirmado.

## Ordem de implementação

1. `EntityPhrases` + `EmptyState` nas duas listas (corrige "Não cliente cadastrado") e confirmação "Apagar Ana Ribeiro?". Teste de widget do vazio. risk:low. l10n: `emptyEntityList`, `deleteEntityConfirm`, `deleteCustomerKeepsOrders`, `back`.
2. Escolher cliente: título "Quem é o cliente?", `AddRow`, sem deslize em modo seleção, `AppListRow`. Teste: no modo seleção não há `Dismissible`. risk:low. l10n: `pickCustomerTitle`, `tapToChoose`, `addNewCustomer`.
3. Formulário: Nome + Telefone, dica, `MoreFieldsLink`, `AppBottomBar` "Salvar cliente". Teste: campos raros escondidos no novo e visíveis no editar com valor. risk:low. l10n: `customerPhoneLabel`, `customerPhoneHint`, `moreCustomerData`, `saveCustomer`, `customerNameRequired`.
4. Tela do cliente (rota `/customer_detail`): topo, Ligar/WhatsApp, lista de OS por `streamOrders(customerId:)`, `SummaryLine`, `MoreMenu`. Teste da soma (sem canceladas) e do vazio. risk:low (só leitura). l10n: `call`, `whatsapp`, `openOrderFor`, `newOrderFor`, `ordersOf`, `totalSpent`, `stillToReceive`, `edit`, `delete`.
5. Aba Clientes: toque abre a tela do cliente; seções por letra; "38 clientes"; `StatusDot` de OS aberta/atrasada. Teste do agrupamento por `customer.id`. risk:low. l10n: `customersCount` (plural), `openOrdersCount`, `lateOrdersCount` (plurais).
6. "Nova OS para Ana" ligado ao fluxo novo da OS. Depende da sessão da OS. risk:low.
7. Remover `customer_os_list.dart`. risk:low.

## Perguntas em aberto

1. "Usados por último": derivar das últimas OS (sem migração, custa uma consulta a mais ao abrir) ou gravar `lastOrderAt` no cliente ao salvar a OS (escrita em modelo compartilhado, risk:high)? Até lá, só alfabética.
2. "Total gasto" conta OS em orçamento ou só aprovadas/concluídas? Proposta: aprovadas, em andamento e concluídas.
