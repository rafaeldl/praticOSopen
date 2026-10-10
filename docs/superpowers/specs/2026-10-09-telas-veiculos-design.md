# Telas do app: veículos e aparelhos

Status: proposta · 2026-10-09 · base: `docs/APP_DESIGN_SYSTEM.md` · componentes: `2026-10-09-telas-componentes-design.md`

Protótipos: canvas https://claude.ai/artifact/NfHsv1Ge52LXGdpd9ZYihz, página "Telas do app". As pranchas usam oficina ("Veículo"); o nome e o ícone vêm do segmento: `SegmentConfigProvider.device/devicePlural` → `label('device._entity')` (`lib/services/segment_config_service.dart:351-354`, fallback pt "Equipamento", `app_pt.arb:298`) e `config.deviceIcon` (`segment_config_provider.dart:86`). Nenhuma tela do grupo usa `AppColors`/`AppTypography` hoje.

## Telas do grupo

| Tela | Arquivo | Uso | O que muda |
|---|---|---|---|
| Escolher veículo na OS | `lib/screens/device_list_screen.dart` (`/device_list`, aberta em `order_form.dart:2034-2044` com `{'order': ...}`) | Diário | Título de tarefa, `AddRow`, "Veículos da Ana" primeiro, ícone do segmento, sem deslize |
| Lista de veículos (Ajustes) | mesmo arquivo, via `settings.dart:199-204` | Raro | Mesmo layout, deslize ligado |
| Novo/editar veículo | `lib/screens/device_form_screen.dart` | Diário | Uma tela: Modelo com sugestão + Placa; resto atrás de link; `AppBottomBar` |
| Valores salvos (marca/modelo/categoria) | `lib/screens/accumulated_value_list_screen.dart` (`/accumulated_value_list`, só de `device_form_screen.dart:444-519`) | Diário hoje, raro depois | Sai do caminho do cadastro; correções mínimas |
| Detalhe do aparelho | `lib/screens/devices/device_detail_screen.dart` (só com `useDeviceManagement`, `device_list_screen.dart:272-277`) | Raro | Só correções (cor de status, contraste, textos) |
| Seletor múltiplo na OS | `lib/screens/widgets/device_picker_sheet.dart` (OS com 2+ aparelhos, `order_form.dart:977-979`, `:2444-2445`, `:2488-2489`) | Raro | Rótulo do segmento, botão e textos |

## Problema atual (achados)

| Regra | Evidência | O que o usuário vê | Correção |
|---|---|---|---|
| **Escolher** Segmento | Avatar sem foto sempre `CupertinoIcons.car_detailed` (`device_list_screen.dart:391`) | Assistência de celular vê um carro em todo aparelho | `config.deviceIcon` |
| R1 | Título "Veículos" (`:51`) mesmo em modo seleção | Não diz que é para escolher | `pickEntityTitle`: "Qual é o veículo?" |
| R4 | `Dismissible` ativo no modo seleção (`:197-265`) | Dá para apagar um veículo no meio da OS | Sem deslize quando `isSelectionMode` |
| R3 | Linha 1 = `'${name} ${serial}'` (`:314`); vazio "Não equipamento cadastrado" (`:141`) | "Gol 1.0 ABC1D23" grudado; frase quebrada | Modelo na linha 1; "Placa ABC1D23 · Fiat" na 2; `EmptyState` |
| R7 | Com gestão, status é ponto de 8px sem texto (`:301-309`); `_statusColor` com `systemGreen/Orange/Grey/Red` (`:355-368`), copiado em `device_form_screen.dart:60-73` e `device_detail_screen.dart:46-59` | Cor sem significado | `StatusDot` + `DeviceStatusStyle` |
| **Novo** R1 | Categoria → Marca → Modelo são 3 telas `/accumulated_value_list` (`device_form_screen.dart:444-519`) antes da placa | 3 idas e voltas para cadastrar um carro | `SuggestField` de Modelo que já traz marca e categoria |
| R3 / R4 | Placeholder "Selecionar" (`:267`, `:293`, `:319`); "INFORMAÇÕES BÁSICAS" em `toUpperCase` (`:255`); Categoria sempre visível (`:258-281`) | Jargão, caixa alta, campo raro na frente | Placeholder `devicePlaceholder` ("Ex.: Fiat Uno 2015"); sem cabeçalho; Categoria atrás do link |
| Z6 / R2 | "Salvar" texto no topo (`:175-181`); selo da câmera `activeBlue` (`:236-238`, 4,02:1 com branco) | Principal escondido; azul do iOS | `AppBottomBar` "Salvar veículo"; foto como `TextLink` |
| **Detalhe** cor | `_orderStatusColor`: `quote` = `systemBlue`, `approved` = `activeBlue` (`device_detail_screen.dart:76-91`) | Orçamento e Aprovada no mesmo azul | `OrderStatusStyle` |
| Contraste | "Próxima geração" em `tertiaryLabel` 13 (`:532-536`) | Cinza claro e pequeno | `textSecondary` 15 |
| **Seletor múltiplo** Segmento | "Para qual equipamento?" fixo (`device_picker_sheet.dart:125`, `app_pt.arb:1324`) | Oficina lê "equipamento" | `selectDeviceFor(config.device)` → "Para qual veículo?" |
| R2 / R3 | `CupertinoButton.filled` = `activeBlue` (`:196-199`), desabilitado sem seleção (`:197`); "Geral" (`:138`) | Botão azul do iOS apagado; "Geral" não explica | `PrimaryButton` sempre ativo ("Adicionar a 2 veículos"; sem seleção: "Escolha pelo menos um"); "Não é de um veículo só" |
| **Valores salvos** R1 / R3 | "Adicionar "X"" no fim da lista (`accumulated_value_list_screen.dart:399`); `usageCount` solto 12px (`:524-541`); "Deseja excluir…" fixo em pt (`:452`); "Limpar" vermelho no lugar do voltar (`:194-204`) | Opção nova some embaixo; número sem rótulo; texto sem tradução | `AddRow` "Usar "X"" no topo; tirar o número; l10n; "Deixar em branco" como linha |

## Tela proposta

### "Na OS · escolher veículo"
1. Topo: "‹ OS nova". Sem "…".
2. Título: "Qual é o veículo?". Subtítulo: "Da Ana Ribeiro" (cliente já escolhido na OS; sem cliente, subtítulo some).
3. Próximo passo: `AppSearchField` "Buscar por modelo ou placa".
4. Conteúdo: `AddRow` "Cadastrar veículo novo". `SectionLabel` "Veículos da Ana" primeiro; depois `SectionLabel` "Outros veículos". `AppListRow`: miniatura 44 (foto ou ícone do segmento), "Fiat Uno 2015", "Placa ABC1D23 · Fiat", e com gestão `StatusDot` + texto. Sem seta, sem deslize. Toque escolhe e volta (`_store.addDevice`, `order_form.dart:2034-2044`).
5–6. Não tem.
- Vazio: `EmptyState` "Nenhum veículo ainda" + `PrimaryButton` "Cadastrar veículo". Seção vazia não aparece.
- **Filtrar por cliente hoje:** o `Device` não tem cliente (`lib/models/device.dart:9-18`) e o repositório só busca por série, categoria e fabricante (`tenant_device_repository.dart:24-60`). O vínculo existe só na OS: `customer` e `devices`/`deviceIds` (`lib/models/order.dart:17-19`, `:60`, `:137-143`). "Veículos da Ana" = aparelhos distintos das OS dela, via `streamOrders(customerId:)` (`tenant_order_repository.dart:347-349`, índice `customer.id + createdAt↓` já em `firebase/firestore.indexes.json`). Sem migração, mas um veículo cadastrado e ainda sem OS salva não aparece na seção da Ana (vai em "Outros").
- Modo Ajustes: título "Veículos", subtítulo "12 veículos", "+" com rótulo no topo, sem seção da Ana, seta e deslize ligados.

### "Clientes · novo veículo (uma tela)"
1. Topo: "‹ Voltar". 2. Título: "Novo veículo" (`newEntity`).
3. Próximo passo: não tem.
4. Conteúdo: `SuggestField` "Modelo" (placeholder do segmento "Ex.: Fiat Uno 2015"); sugestões enquanto digita: "Fiat Uno 2015 · Fiat · Carro". Escolher uma sugestão preenche `name`, `manufacturer` e `category` de uma vez. Sem sugestão igual: linha "Usar “Fiat Uno 2016”". Depois `AppFormField` "Placa" (rótulo do segmento para `serial`, obrigatório como hoje, `device_form_screen.dart:340`). `TextLink` "+ Foto e mais dados (ano, cor, chassi)": revela foto, marca, categoria, status (só editar, com gestão) e campos do segmento (`DynamicFieldBuilder`, `:420`).
5. Resumo: não tem. 6. `AppBottomBar` com `PrimaryButton` "Salvar veículo".
- Sai: cabeçalho "INFORMAÇÕES BÁSICAS", seção "STATUS" no cadastro novo, rótulos de largura fixa 100 (`:259-264`), "Salvar" do topo, selo azul da câmera.
- Erro: placa vazia → dica em `danger` "Digite a placa". Upload de foto mantém o overlay atual (`:219-230`).
- **De onde vêm as sugestões:** `AccumulatedValueRepository` em `companies/{companyId}/accumulatedFields/{fieldType}/values`, tipos `deviceCategory`, `deviceBrand`, `deviceModel` (`accumulated_value_repository.dart:6-25`), ordenadas por `usageCount` no cliente (`:54-56`). O modelo é gravado com `group` = categoria e marca juntas por "-" e em minúsculas (`accumulated_value_list_screen.dart:76-85`, `accumulated_value_repository.dart:126`; chamado com `[category, manufacturer]` em `device_form_screen.dart:504`). Isso não devolve "Fiat" e "Carro" com a grafia original e quebra com hífen no nome. Duas saídas: (a) sugerir a partir dos próprios aparelhos da empresa, que já têm `name`/`manufacturer`/`category` separados (`device.dart:10-13`), contando repetições; (b) gravar `brand` e `category` no valor `deviceModel`. Proposta: (a) para começar, sem migração; continuar chamando `use()` (`:119-163`) para manter o acumulado.

### Detalhe do aparelho (prancha "Clientes · veículo do cliente")
Topo "‹ Veículos" + "…" (editar, apagar); título modelo, subtítulo "Placa · cliente"; `NextStepBlock` "Abrir uma OS para este veículo?" com `PrimaryButton` "Nova OS"; seções "OS deste veículo" e "Contrato" (só se houver).

`OrderStatusStyle` nas OS (`:76-91`); "Próxima visita: 12/11" em `textSecondary` 15 (`:532-536`); "OS 123 · Aprovada" com `StatusDot` em vez de "#123 - Aprovada" (`:410`); `SectionLabel` em vez de CAIXA ALTA 13 (`:199`, `:220-224`, `:481-485`); fabricante e série só uma vez (cabeçalho `:146-163` repete `:203-208`); lápis (`:115-117`) vira "…" → "Editar".

### Seletor múltiplo (sem prancha, só achados)
Título "Para qual veículo?"; opção "Não é de um veículo só"; "Todos os veículos" (hoje "Selecionar Tudo", `app_pt.arb:50`); `PrimaryButton` "Adicionar a 2 veículos".

### Valores salvos (sem prancha, só achados)
Depois do `SuggestField`, a tela só abre por "+ Foto e mais dados" (marca/categoria). Correções: `AddRow` "Usar "X"" no topo; sem `usageCount`; textos 13/16 (`:281`, `:331`, `:515`, `:272`, `:323`, `:504`) para 19/15; `primaryColor` (`:259`, `:271`, `:310`, `:322`, `:410`, `:420`, `:547`) para `accentText`; confirmação "Apagar "X" da lista?" no l10n; multi-seleção com `AppBottomBar` "Usar 3 selecionados" (hoje "OK" no topo, `:206-214`).

## Componentes usados

`AppTopBar`, `ScreenTitle`, `AppBottomBar`, `PrimaryButton`, `TextLink`, `MoreMenu`, `SectionLabel`, `AppListRow`, `AddRow`, `StatusDot`, `OrderStatusStyle`, `DeviceStatusStyle`, `EmptyState`, `AppSearchField`, `AppFormField`, `MoreFieldsLink`, `SuggestField`, `EntityPhrases`.

Nenhum componente novo.

## Fora de escopo / alinhar com a sessão da OS

- O subtítulo "Da Ana Ribeiro" e a seção "Veículos da Ana" dependem da OS passar o cliente: hoje passa `{'order': _store.order}` (`order_form.dart:2034-2044`), que já tem `customer`. Se o fluxo novo da OS pedir o veículo antes do cliente, as seções somem.
- Depois de "Cadastrar veículo novo", voltar direto para a OS com o veículo escolhido (como o cliente faz hoje).
- Quando abrir o seletor múltiplo é decisão da OS; aqui só muda o texto e o botão.

## Ordem de implementação

1. Ícone do segmento na lista, `EmptyState`, título "Qual é o veículo?", sem deslize no modo seleção, linha modelo/placa. Teste de widget (segmento celular sem ícone de carro; seleção sem `Dismissible`). risk:low. l10n: `pickEntityTitle`, `emptyEntityList`, `addNewEntity`, `searchByModelOrPlate`.
2. `DeviceStatusStyle` + `StatusDot` na lista e no detalhe; `OrderStatusStyle` no detalhe; contraste da data. Teste do mapa. risk:low. l10n: `nextVisit`.
3. Seletor múltiplo: rótulo do segmento, textos, `PrimaryButton`. Teste com segmento oficina. risk:low. l10n: `selectDeviceFor(device)`, `notForOneDevice`, `allDevices`, `addToDevices` (plural), `pickAtLeastOne`.
4. Seções "Veículos da Ana" / "Outros" a partir das OS do cliente. Teste da derivação (distintos, ordem, sem cliente). risk:low. l10n: `devicesOf(name)`, `otherDevices`, `fromCustomer(name)`.
5. Formulário em uma tela: `SuggestField` com sugestões dos aparelhos da empresa, Placa, link "+ Foto e mais dados", `AppBottomBar`. Teste: escolher sugestão preenche marca e categoria. risk:low. l10n: `newEntity`, `photoAndMoreData`, `useValue(value)`, `saveEntity`, `plateRequired`.
6. Valores salvos: `AddRow` no topo, l10n da confirmação, tipografia, multi com `AppBottomBar`. risk:low. l10n: `deleteSavedValue(value)`, `leaveBlank`, `useSelected` (plural).

## Perguntas em aberto

1. Sugestões de modelo: derivar dos aparelhos cadastrados (sem migração, perde modelos digitados e nunca salvos) ou passar a gravar `brand`/`category` no `deviceModel` acumulado? Proposta: derivar agora.
2. Vale gravar o cliente no aparelho (`Device.customer`) para "Veículos da Ana" funcionar antes da primeira OS? É mudança de modelo compartilhado (risk:high); a proposta não depende disso.
