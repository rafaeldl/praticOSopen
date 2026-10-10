# Telas do app: catálogo (serviços e produtos)

Status: proposta · 2026-10-09 · base: `docs/APP_DESIGN_SYSTEM.md` · componentes: `2026-10-09-telas-componentes-design.md`

Protótipos: canvas https://claude.ai/artifact/NfHsv1Ge52LXGdpd9ZYihz, página "Telas do app".

A descoberta que guia esta spec: `/service_list` e `/product_list` são **duas telas numa só**. É o seletor diário da OS (`order_form.dart:2465-2469` e `:2509-2513`, com `arguments: {'orderStore': _store}`) e também o cadastro raro aberto pela aba Mais (`settings.dart:212` e `:221`). Hoje a tela não muda nada entre os dois usos. A proposta separa os dois modos na mesma tela genérica.

Produto é igual a serviço trocando os nomes (`diff` dos arquivos mostra só Service→Product, ícone, rotas e chaves l10n). Por isso as pranchas mostram só serviço, e o código vira dois componentes genéricos.

## Telas do grupo

| Tela | Arquivo | Uso | O que muda |
|---|---|---|---|
| Lista de serviços | `lib/screens/service_list_screen.dart` (328 l.) | Diário (escolher na OS) e raro (cadastro) | Vira `CatalogListScreen` com 2 modos: escolher e cadastro |
| Lista de produtos | `lib/screens/product_list_screen.dart` (328 l.) | Igual | Some; usa `CatalogListScreen` com rótulos de produto |
| Formulário de serviço | `lib/screens/service_form_screen.dart` (301 l.) | Semanal no começo, depois raro | Vira `CatalogItemForm`: nome e preço primeiro, foto por link, botão embaixo |
| Formulário de produto | `lib/screens/product_form_screen.dart` (301 l.) | Igual | Some; usa `CatalogItemForm` |
| Seletor de valores salvos (marca/modelo) | `lib/screens/accumulated_value_list_screen.dart` (564 l.) | Semanal (cadastro de aparelho) | Só correções (achados abaixo); a troca por `SuggestField` é da spec de clientes/aparelhos |

## Problema atual (achados)

| Regra | Evidência | O que o usuário vê | Correção |
|---|---|---|---|
| **Lista (serviço e produto, linhas iguais nos dois arquivos)** | | | |
| R1 | `service_list_screen.dart:39` define `isSelectionMode`, mas `:48` usa sempre `largeTitle: Text(context.l10n.services)` | Vindo da OS, a tela diz só "Serviços", não diz que é para escolher | Modo escolher: "Qual serviço?" / "Toque para colocar na OS"; cadastro: "Seus serviços" |
| Segurança de uso | `:181-229` `Dismissible` com editar e **apagar do catálogo** ativo também no modo escolher | Na correria da OS, um deslize apaga o serviço do catálogo (não da OS) | Modo escolher sem gesto; apagar só no "…" do formulário |
| R2 / cor | `:275` preço em `CupertinoColors.activeBlue`; `:185` fundo do swipe `systemBlue` | Preço parece link, no azul iOS proibido | Preço em `text` com `AppTypography.tabular` |
| R6 / a11y | `:49-55` "+" com `padding: EdgeInsets.zero`, sem rótulo | Alvo pequeno; leitor de tela diz só "botão" | Modo escolher: `AddRow`; cadastro: `AppBottomBar` "Novo serviço" |
| a11y / tipografia | `:274` preço 14; `:141` dica do vazio 14; `:283` seta `systemGrey3` | Texto pequeno, seta quase invisível | Preço `body` 19; dica 15; seta `textSecondary`, e só no cadastro |
| R4 (vazio) | `:118-149` vazio só com ícone + texto; a ação é o "+" do canto | Usuário novo não acha onde cadastrar | `EmptyState` com frase e botão |
| Criar pela busca | `:152-157` busca só filtra; sem resultado, não há saída | Serviço novo exige sair da OS, ir ao cadastro e voltar | `AddRow` "Criar “{busca}” e pôr na OS" (prancha "criar pela busca") |
| **Formulário (serviço e produto, linhas iguais)** | | | |
| i18n | `service_form_screen.dart:122` "Editar Serviço"/"Novo Serviço", `:128` "Salvar", `:204` "Nome", `:206` "Nome do serviço", `:210`/`:229` "Obrigatório", `:213` "Valor", `:83-109` textos da foto | Em inglês/espanhol a tela fica em português | Tudo por `context.l10n` |
| Moeda | `:31-35` formatador fixo `pt_BR`/`R$`; `:221-226` parse por regex | Fora do Brasil o preço aparece em R$ | `MoneyField` (`FormatService`) |
| Z6 / R6 | `:123-129` "Salvar" é texto no canto do topo, `padding: EdgeInsets.zero` | Ação principal pequena, no canto | `AppBottomBar` com `PrimaryButton` "Salvar serviço" |
| R4 / cor | `:139` foto é o 1º elemento; `:185` selo da câmera `activeBlue` preenchido | Foto (rara) antes de nome e preço; segundo azul preenchido | Nome e preço primeiro; foto vira `TextLink` "+ Foto do serviço" |
| Regra do preço | `:229` validador exige o preço | Quem cobra cada OS de um jeito inventa um valor | Preço opcional, com dica (ver prancha) |
| Destrutivo | não há "Apagar" no formulário, só o swipe da lista | Quem não conhece o gesto não apaga | "…" → `DestructiveAction` "Apagar serviço" |
| **Seletor de valores salvos** | | | |
| R1 | `accumulated_value_list_screen.dart:399` "Adicionar “X”" fica no fim da lista filtrada | Digita "Sam", a opção de criar some embaixo de 8 resultados | `AddRow` "Usar “Sam”" no topo |
| R3 / R7 | `:524-541` número cinza `usageCount` 12 sem rótulo; `:452` "Deseja excluir…" fixo em pt | Número solto ao lado da marca; texto sem tradução | Tirar o número (a ordem já é por uso); confirmação por l10n |

## Tela proposta

### Catálogo · escolher serviço (modo escolher, vindo da OS)

Prancha: **"Na OS · escolher serviço"**.

1. **Topo** (`AppTopBar`): "‹ OS 186". Sem "…".
2. **Título** (`ScreenTitle`): "Qual serviço?" / "Toque para colocar na OS".
3. **Próximo passo:** não tem bloco; o `AppSearchField` ocupa o lugar, placeholder "Buscar ou digitar um serviço novo".
4. **Conteúdo:** `SectionLabel` "Mais usados"; `AppListRow` com nome (19) e preço à direita (`tabular`, só com permissão de ver valores). **Sem seta e sem deslize.** Depois a lista toda em ordem alfabética. Por último, `AddRow` "Criar serviço novo".
5. **Resumo:** não tem.
6. **Barra de baixo:** não tem (cada toque já resolve).

- O toque hoje abre `/order_service` (`service_list_screen.dart:235-238`) para ajustar o item. O que acontece depois do toque é da sessão da OS (ver Fora de escopo).
- **"Mais usados" não tem dado hoje.** `Service` só tem `name`, `value`, `photo`, `keywords`, `customData` (`lib/models/service.dart:9-14`); a lista é ordenada por nome (`tenant_service_repository.dart:27`). Ver Perguntas em aberto. Até decidir, a seção não aparece (`SectionLabel` some quando vazio).
- Vazio (catálogo sem nada): `EmptyState` "Você ainda não tem serviços. Digite o nome na busca para criar o primeiro." Carregando: `CupertinoActivityIndicator` no lugar da lista.

### Catálogo · criar pela busca

Prancha: **"Na OS · criar serviço pela busca"**.

- Busca sem resultado igual: a 1ª linha da lista vira `AddRow` "Criar “Troca de embreagem” e pôr na OS". Embaixo, texto 15 `textSecondary`: "O preço você coloca na própria OS. O serviço fica salvo para as próximas."
- Toque: cria o `Service` só com o nome (preço vazio) e segue o mesmo caminho de um toque numa linha. Sem abrir formulário.
- Com resultados parciais (digitou "Troca"), o `AddRow` continua no topo, antes dos resultados.
- Erro ao salvar: alerta "Não deu para criar o serviço. Tente de novo." e a busca fica como estava.

### Catálogo · seus serviços (Mais)

Prancha: **"Mais · catálogo"**.

1. **Topo:** "‹ Mais". Sem "…".
2. **Título:** "Seus serviços" / "24 serviços" (contagem real).
3. **Próximo passo:** não tem; `AppSearchField` "Buscar serviço".
4. **Conteúdo:** `AppListRow` nome + preço + **seta** (toque abre o formulário). Sem deslize.
5. **Resumo:** não tem.
6. **Barra de baixo:** `AppBottomBar` com `PrimaryButton` "Novo serviço".

- Sai da 1ª tela: o "+" do canto, o deslize de editar e o de apagar (apagar vai para o "…" do formulário).
- Vazio: `EmptyState` "Você ainda não tem serviços. Cadastre os que você mais faz para montar a OS mais rápido." O botão é o da barra.

### Catálogo · novo serviço

Prancha: **"Mais · novo serviço"**.

1. **Topo:** "‹ Voltar". Ao editar, "…" com `DestructiveAction` "Apagar serviço" (confirmação: "Apagar Troca de óleo?" / "Apagar" e "Voltar").
2. **Título:** "Novo serviço" (ao editar: o nome do serviço).
3. **Próximo passo:** não tem (formulário curto).
4. **Conteúdo:** `AppFormField` "Nome", placeholder "Ex.: Troca de óleo"; `MoneyField` "Preço" com dica "Pode deixar em branco e combinar o preço em cada OS."; depois os campos do segmento (`customData`) com `SectionLabel`; por último `TextLink` "+ Foto do serviço" (com foto: miniatura + "Trocar foto").
5. **Resumo:** não tem.
6. **Barra de baixo:** `AppBottomBar` com `PrimaryButton` "Salvar serviço".

- Erro de validação: só o nome é obrigatório, "Digite o nome do serviço". Preço vazio grava `value = null` (hoje grava 0 via `double.tryParse(...) ?? 0`, `:225`).
- Produto: mesmas pranchas com "Qual produto?", "Seus produtos", "Novo produto", "Ex.: Filtro de óleo", "Salvar produto", "+ Foto do produto".

### Seletor de valores salvos

Sem prancha. Só as correções da tabela de achados; o redesenho fica com a spec de clientes e aparelhos (`SuggestField`).

## Componentes usados

Do doc comum: `AppTopBar`, `ScreenTitle`, `AppSearchField`, `SectionLabel`, `AppListRow`, `AddRow`, `EmptyState`, `AppFormField`, `MoneyField`, `TextLink`, `PrimaryButton`, `AppBottomBar`, `MoreMenu`, `DestructiveAction`, `EntityPhrases`.

Específicos do catálogo (ficam em `lib/screens/catalog/`, **não vão para o doc comum**, porque só servem a serviço e produto):

- `CatalogListScreen` — recebe uma config (`CatalogKind.service | product`) com store, rótulos l10n, ícone e rotas, e o modo (escolher se veio `orderStore`, senão cadastro). Substitui `service_list_screen.dart` e `product_list_screen.dart`.
- `CatalogItemForm` — mesmo esquema para nome, preço, campos do segmento e foto. Substitui `service_form_screen.dart` e `product_form_screen.dart`. Corta ~630 linhas e garante que a correção numa vale na outra.

Componente novo a adicionar no doc comum: nenhum. A dica embaixo do `MoneyField` usa a "dica opcional embaixo" do `AppFormField`.

## Código morto da área (remover)

| Arquivo | Prova | Ação |
|---|---|---|
| `lib/screens/info_form_screen.dart` (`InfoFormScreen`, 101 l.) | rota `/info_form` em `routes.dart:41`, mas nenhum `pushNamed('/info_form')` em `lib/` | Apagar arquivo, rota e import (`routes.dart:15`) |
| `lib/screens/pdf_preview_screen.dart` (`PdfPreviewScreen`, 44 l.) | nenhum import fora do próprio arquivo; só citado em `docs/PDF_GENERATION.md:6` | Apagar e tirar a menção do doc |
| `lib/screens/order_item_row.dart` (`OrderItemRow`, 177 l.) | nenhum import em `lib/` nem `test/` | Apagar (é da OS, mas é lixo) |
| `lib/screens/product_list_screen.dart`, `product_form_screen.dart` | cópias do serviço | Apagar depois que `CatalogListScreen`/`CatalogItemForm` estiverem no ar |

## Fora de escopo / alinhar com a sessão da OS

- `order_service_screen.dart` (338 l.), `order_product_screen.dart` (445 l.) e `order_item_row.dart`: são telas do item dentro da OS.
- O que acontece depois do toque no modo escolher (abrir `/order_service` para ajustar, ou pôr direto na OS e ajustar o preço na linha da OS) é decisão da sessão da OS. A prancha "criar pela busca" assume a 2ª ("O preço você coloca na própria OS"). `CatalogListScreen` só devolve o item escolhido; não sabe o que a OS faz com ele.
- As telas de item repetem os problemas do formulário de catálogo (foto no topo, "Salvar" no canto, cabeçalho 13 em caixa alta, `order_service_screen.dart:136-140`).

## Ordem de implementação

1. **Remover código morto** (`info_form_screen`, `pdf_preview_screen`, `order_item_row`, rota `/info_form`). Teste: `flutter analyze` limpo e `routes.dart` sem a rota. risk:low. Sem l10n.
2. **i18n e moeda do formulário** (serviço e produto, antes de unificar): textos por l10n, `MoneyField`, preço opcional. Teste de widget: salvar com preço vazio grava `null`; em `en-US` o preço sai em `$`. risk:low. l10n: `newService`, `editService`, `serviceNameHint` ("Ex.: Troca de óleo"), `catalogPriceHint` ("Pode deixar em branco e combinar o preço em cada OS."), `addServicePhoto` ("+ Foto do serviço"), `saveService`, `serviceNameRequired`, e os de produto.
3. **`CatalogItemForm`** no lugar dos dois formulários; "…" com apagar; `AppBottomBar`. Teste: abre como serviço e como produto com os textos certos; apagar pede confirmação. risk:low. l10n: `deleteService`, `deleteProduct` (via `EntityPhrases.deleteEntityConfirm`).
4. **`CatalogListScreen` modo cadastro** ("Seus serviços", seta, `AppBottomBar`, sem deslize). Teste: contagem no subtítulo; sem `Dismissible`. risk:low. l10n: `yourServices`, `serviceCount` (plural), `newServiceButton`, textos do vazio.
5. **`CatalogListScreen` modo escolher** (título "Qual serviço?", sem seta, sem gesto, `AddRow`). Teste: com `orderStore` não há `Dismissible` nem seta e o título muda. risk:low. l10n: `pickServiceTitle`, `tapToAddToOrder`, `searchOrTypeNewService`, `createNewService`.
6. **Criar pela busca**. Teste: busca sem resultado mostra o `AddRow` no topo; toque cria `Service` só com nome. risk:low. l10n: `createAndAddToOrder` ("Criar “{name}” e pôr na OS"), `createFromSearchHint`.
7. **Correções do seletor de valores salvos** (`AddRow` no topo, sem contador, l10n da confirmação, `accentText`). risk:low.
8. **"Mais usados"**, só depois da resposta abaixo. Se precisar de campo novo no `Service`/`Product`, é modelo compartilhado: risk:high.

## Perguntas em aberto

1. **"Mais usados" não existe hoje.** Opções: (a) contador `usageCount` no `Service`/`Product`, somado ao pôr na OS (escrita a mais por item, modelo compartilhado, risk:high); (b) calcular no app a partir das últimas ~50 OS da empresa (sem mudar modelo, custa leitura); (c) cortar a seção. Qual?
2. **Preço opcional:** serviço sem preço entra na OS com valor 0 ou vazio esperando preencher? Isso muda o total da OS e é decisão da sessão da OS.
3. **Criar pela busca**, quem pode? Hoje cadastrar serviço exige `viewServices` (`settings.dart:207-213`). Um técnico sem essa permissão deve poder criar pelo seletor da OS?
