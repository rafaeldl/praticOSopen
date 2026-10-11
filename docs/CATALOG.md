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
