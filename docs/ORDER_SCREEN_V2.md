# ORDER_SCREEN_V2.md

## Visão Geral

Nova tela da OS (fase 1 do redesenho, sem IA), atrás da opção local **"Nova tela da OS"** (Mais › Interface, desligada por padrão). Com a opção desligada nada muda: `/order` continua abrindo o `OrderForm` antigo.

Specs: `docs/superpowers/specs/2026-10-11-telas-os-ia-design.md` (vale sobre) `2026-10-09-os-ai-assistant-design.md`, mais as seções de OS de `2026-10-10-telas-hig-design.md` e `2026-10-11-telas-paridade-design.md`.

## Arquitetura

| Arquivo | Papel |
|---|---|
| `lib/services/order_screen_preference.dart` | `OrderScreenPreference`: valor em `SharedPreferences` (`useNewOrderScreen`), espelhado num `ValueNotifier`; carregado no `main()` |
| `lib/screens/order/order_route.dart` | `OrderRoute` (rota `/order`): escolhe a tela nova ou a antiga uma vez por abertura. Abrir os comentários (`scrollToComments`, vindo de notificação) fica na antiga |
| `lib/screens/order/order_screen_v2.dart` | A tela: status, próximo passo, cliente/veículo, itens, totais, "…" |
| `lib/screens/order/order_item_search_screen.dart` | "O que vai na OS?": uma busca em serviços e produtos; "Criar “X” e pôr na OS"; "Mais usados" |
| `lib/screens/order/order_item_sheet.dart` | Sheet do item: preço (em branco = sem valor), quantidade (produto), "Tirar da OS" |
| `lib/screens/order/order_screen_services.dart` | `OrderPermissions` e `OrderScreenActions` (PDF, link do cliente, pagamentos, tela completa), injetáveis nos testes |
| `lib/utils/order_items.dart` | Soma sem os itens sem valor; "Mais usados" derivado das últimas ~50 OS |

Sem modelo novo e sem campo novo. Estado continua no `OrderStore`; repositórios os mesmos.

## Fluxo de Dados

- **OS nova:** `OrderStore.loadOrder()` + `deferSave = true`. Escolher cliente, veículo, itens e status muda só a memória. **"Salvar OS"** (só com cliente) desliga o `deferSave` e chama `createItem()`. Voltar com algo preenchido pergunta "Sair sem salvar?".
- **OS existente:** busca a versão atual (`getSingle`) e chama `setOrder`. Cada mudança grava na hora, como na tela antiga.
- **Cliente:** `/customer_list` ("Quem é o cliente?"); buscar pela placa devolve cliente e veículo (`CustomerPick`).
- **Itens:** tocar no item da busca já põe na OS com o preço do catálogo. Criar pela busca grava o serviço (ou produto, se só houver `manageProducts`) só com o nome.

## Regras de Negócio

1. Item sem preço é `null` ("sem valor"), não entra no total e não trava o salvar. `OrderStore.updateTotal` passou a tratar `null`.
2. Criar pela busca só com `manageServices`/`manageProducts`; nome igual (sem acento/caixa) esconde a opção.
3. Preços, total, "Falta receber" e "Receber" só com `viewPrices`.
4. Próximo passo (único botão azul da OS salva): Orçamento → "Cliente aprovou"; Aprovada → "Começar o serviço"; Em andamento → "Marcar como pronto"; Pronta com saldo → "Receber R$ X"; Pronta e paga → "Mandar para o cliente"; Cancelada → "Reabrir". Sem permissão para a mudança, só a frase aparece.
5. "Pronta" bloqueia com checklist pendente; "Cancelar OS" pede confirmação.
6. "…" com 3 grupos: "Adicionar à OS ›" (prazo de entrega, outro veículo, e "Checklist, fotos, comentário e mais", que abre a tela completa); "Mandar para o cliente" · "PDF"; "Cancelar OS" / "Apagar OS" em vermelho.
7. Sem foto de capa; fotos aparecem em "Fotos" só quando existem.
8. Foto e "Falar o que fazer" só aparecem na Nova OS com `kAiOrderAssistEnabled` (desligado por padrão). A IA preenche a mesma tela com marca-texto; ver `docs/AI_ORDER_ASSIST.md`.

## Exemplos de Uso

```dart
// Ligar a tela nova neste aparelho
await OrderScreenPreference.set(true);
Navigator.pushNamed(context, '/order'); // OS nova em branco
Navigator.pushNamed(context, '/order', arguments: {'order': order});
```

Testes: `test/screens/order/order_screen_v2_test.dart`, `test/screens/order/order_route_test.dart`, `test/utils/order_items_test.dart`.
