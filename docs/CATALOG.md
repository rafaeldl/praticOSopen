# CATALOG

## Visão Geral
Tela única de catálogo (Mais > Catálogo) com o seletor "Serviços | Produtos", busca e lista com preço. Também é o seletor de serviço/produto da OS (`/service_list`, `/product_list` com `orderStore`).

## Arquitetura
- `lib/screens/catalog/catalog_list_screen.dart`: `CatalogListScreen` (modo catálogo e modo escolher).
- `lib/screens/catalog/catalog_item_form.dart`: `CatalogItemForm` (serviço e produto). Item novo abre em `AppSheet`; edição é push com botão "Salvar serviço/produto" e "…" com "Apagar".
- `lib/screens/catalog/catalog_source.dart`: `CatalogKind`, `CatalogItem`, `CatalogSource` (Firestore via `ServiceStore`/`ProductStore`) e `CatalogPermissions`.
- Rotas: `/catalog`, `/service_list` e `/product_list` abrem `CatalogListScreen`.

## Regras de Negócio
- Segmentos mostram só o que o usuário pode ver (`viewServices`/`viewProducts`); com um só, sem seletor.
- Criar, editar e apagar exigem `manageServices`/`manageProducts` do tipo. Sem isso, linhas só leitura (sem seta).
- Preço só aparece com `viewPrices`. Item sem preço (`value == null`) aparece como "sem valor"; preço em branco no formulário grava `null`.
- Modo escolher (vindo da OS): título "Qual serviço?", sem seletor, sem seta, toque abre `/order_service` ou `/order_product`.
- Ainda não existe a busca "O que vai na OS?" (fase da OS).

## Preço novo na OS: só nesta OS ou sempre (#588)
Quem muda o preço de um item que veio do Catálogo, dentro da OS, escolhe se o preço vale só para aquela OS ou para as próximas também.

- **App:** `OrderServiceScreen`/`OrderProductScreen` perguntam ao tocar em "Salvar" (`askCatalogPrice` em `lib/screens/order/order_item_form.dart`). "Usar sempre" grava só o `value` do item (`ServiceStore.updatePrice`/`ProductStore.updatePrice`, com `updatedAt`/`updatedBy`) e atualiza o preço guardado na linha (`service.value`/`product.value`). "Só nesta OS" (botão padrão) é o comportamento de antes.
- **Web:** `OrderDetail.vue`, depois de salvar o item pelo `ItemDialog`, lê o item atual do Catálogo (`GET /v1/app/{services|products}/:id`) e pergunta. "Usar sempre" faz `PATCH` com a `version` lida: se alguém mudou o item nesse meio tempo, nada é gravado e aparece o aviso para mudar pelo Catálogo. Regra em `firebase/webapp/src/lib/orders/catalog-price.ts`.
- **Quando pergunta** (`shouldOfferCatalogPrice` no app, `catalogPriceOffer` no web): a linha tem item do Catálogo (`service.id`/`product.id`), o preço mudou nesta edição e ficou diferente do Catálogo (em centavos). Item do Catálogo "sem valor" também pergunta.
- **Quem recebe:** só quem tem `manageServices`/`manageProducts` do tipo e `viewPrices` (hoje, dono e admin). Os outros perfis salvam só na OS, sem pergunta. As regras do Firestore já limitam a escrita do Catálogo a dono/admin.
- **Texto:** o nome do item vem do segmento: `product._entity` ("Peça", "Componente"...) com fallback `l10n.product`; serviço usa `service._entity`/`l10n.service`. Chaves `orderItemCatalogPrice*` nos `.arb` (app e web).
- **Referência no app:** na edição de uma linha, o preço do Catálogo comparado é o guardado na linha quando ela entrou na OS (o app não lê o Catálogo de novo). No web é o preço atual do Catálogo.
