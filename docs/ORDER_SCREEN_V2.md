# ORDER_SCREEN_V2.md

## Visão Geral

A tela da OS (redesenho). É a única tela da OS: a tela antiga (`OrderForm`) e a opção "Nova tela da OS" foram removidas, e `/order` sempre abre a `OrderScreenV2`.

Specs: `docs/superpowers/specs/2026-10-11-telas-os-ia-design.md` (vale sobre) `2026-10-09-os-ai-assistant-design.md`, mais as seções de OS de `2026-10-10-telas-hig-design.md` e `2026-10-11-telas-paridade-design.md`.

## Arquitetura

| Arquivo | Papel |
|---|---|
| `lib/screens/order/order_route.dart` | `OrderRoute` (rota `/order`): abre a `OrderScreenV2`, que lê os argumentos (`order`, e `scrollToComments`/`commentId` vindos de notificação). `openNewOrder` abre a Nova OS em sheet grande |
| `lib/screens/order/order_screen_v2.dart` | A tela: status, próximo passo, cliente/veículo, itens, totais, "…" |
| `lib/screens/order/order_item_search_screen.dart` | "O que vai na OS?": uma busca em serviços e produtos; "Criar “X” e pôr na OS"; "Mais usados" |
| `lib/screens/order/order_item_sheet.dart` | Sheet do item: preço (em branco = sem valor), quantidade (produto), "Tirar da OS" |
| `lib/screens/order/order_screen_services.dart` | `OrderPermissions` (preços, status, apagar, campos principais, checklists, fotos) e `OrderScreenActions` (PDF, link do cliente, pagamentos, fotos e documentos, checklists, comentários, mapa, desconto, contrato), injetáveis nos testes |
| `lib/screens/order/order_extras.dart` | Sheets de data (agendar, prazo) e de endereço; `checklistMissing` |
| `lib/screens/widgets/order_custom_fields.dart` | Campos do segmento (`service_order.*`): `orderBuiltInFieldKeys`, `orderCustomFieldsFor`, `OrderCustomFieldSections`, `applyCustomFieldValue` |
| `lib/screens/widgets/order_media_actions.dart` | Adicionar foto/documento, abrir e apagar documento |
| `lib/screens/widgets/order_status_share.dart` | "Avisar o cliente?" depois de mudar o status (regras + link do cliente + compartilhar) |
| `lib/screens/widgets/contract_config_sheet.dart` | Sheet do contrato recorrente |
| `lib/screens/widgets/photo_viewer_screen.dart` | Fotos da OS em tela cheia (`PhotoViewerScreen`): passar, compartilhar, capa e apagar |
| `lib/utils/order_items.dart` | Soma sem os itens sem valor; "Mais usados" derivado das últimas ~50 OS |

Sem modelo novo e sem campo novo (nada muda no Firestore nem nas Functions). Estado continua no `OrderStore`; repositórios os mesmos.

## Fluxo de Dados

- **OS nova:** `OrderStore.loadOrder()` + `deferSave = true`. Escolher cliente, veículo, itens e status muda só a memória. **"Salvar OS"** (só com cliente) desliga o `deferSave` e chama `createItem()`. Voltar com algo preenchido pergunta "Sair sem salvar?".
- **OS existente:** busca a versão atual (`getSingle`) e chama `setOrder`. Cada mudança grava na hora.
- **Cliente:** `/customer_list` ("Quem é o cliente?"); buscar pela placa devolve cliente e veículo (`CustomerPick`).
- **Itens:** tocar no item da busca já põe na OS com o preço do catálogo. Criar pela busca grava o serviço (ou produto, se só houver `manageProducts`) só com o nome.

## Regras de Negócio

1. Item sem preço é `null` ("sem valor"), não entra no total e não trava o salvar. `OrderStore.updateTotal` passou a tratar `null`.
2. Criar pela busca só com `manageServices`/`manageProducts`; nome igual (sem acento/caixa) esconde a opção.
3. Preços, total, "Falta receber" e "Receber" só com `viewPrices`.
4. Próximo passo (único botão azul da OS salva): Orçamento → "Cliente aprovou"; Aprovada → "Começar o serviço"; Em andamento → "Marcar como pronto"; Pronta com saldo → "Receber R$ X"; Pronta e paga → "Mandar para o cliente"; Cancelada → "Reabrir". Sem permissão para a mudança, só a frase aparece.
5. "Pronta" bloqueia com checklist pendente; "Cancelar OS" pede confirmação.
6. "…" com 3 grupos: "Adicionar à OS ›"; "Mandar para o cliente" · "PDF"; "Cancelar OS" / "Apagar OS" em vermelho.
7. "Adicionar à OS ›" mostra só o que a OS ainda não tem: Checklist, Fotos ou documento, Comentário, Endereço do atendimento (com atendimento fora), Agendar dia e hora (com agenda), Prazo de entrega, Desconto (com `viewPrices`, depois de aprovada e com saldo), Repetir esta OS (com contratos) e Outro veículo. Sem `canEditOrderMainFields`/`canManageOrderForms`/`attachPhotos` as opções somem. Campos do ramo e vários veículos aparecem aqui.
8. "Nesta OS" mostra só o que existe: agendado, prazo, endereço (tocar: abrir no mapa, mudar, tirar), contrato (frequência e próxima data; tocar: mudar ou desativar; OS gerada leva à OS do contrato), checklists (ponto âmbar/verde e "Faltam N perguntas"; deslizar apaga depois de confirmar). Depois "OS geradas", "Fotos" (tocar abre o visualizador), "Documentos" (tocar abre; deslizar apaga) e os comentários no fim da OS salva.
9. Depois de mudar para Aprovada, Em andamento ou Pronta, "Avisar o cliente?" (cliente com telefone, sem link ativo, sem "Agora não" nesta sessão). "Enviar via WhatsApp" abre o compartilhar com o link.
10. Desconto entra como transação (`addDiscountTransaction`, o mesmo do Receber) e aparece acima do total.
11. Sem foto de capa; fotos aparecem em "Fotos" só quando existem.
12. Campos do segmento (`customData`) aparecem na OS logo depois dos itens, agrupados por seção, (campos já fixos da tela ficam de fora; esvaziar o último apaga `customData`). Gravam na hora numa OS salva e só em memória até "Salvar OS" numa nova.
13. Com 2 ou mais veículos os itens se agrupam por veículo (e "Geral" para os sem veículo), cada bloco com o seu "Subtotal" (só com `viewPrices`). Ao pôr um item, a pergunta do `DevicePickerSheet`: um veículo, vários, todos ou geral.
14. "Falar o que fazer" (e a leitura da foto pela IA) só aparece quando o servidor diz que a IA está ligada para a empresa (`GET /v1/app/ai/status`; desligada por padrão). A IA preenche a mesma tela com marca-texto; ver `docs/AI_ORDER_ASSIST.md`.

## Exemplos de Uso

```dart
Navigator.pushNamed(context, '/order'); // OS nova em branco
Navigator.pushNamed(context, '/order', arguments: {'order': order});
```

Testes: `test/screens/order/order_screen_v2_test.dart`, `test/screens/order/order_screen_v2_extras_test.dart`, `test/screens/widgets/order_status_share_test.dart`, `test/screens/order/order_route_test.dart`, `test/screens/widgets/photo_viewer_screen_test.dart`, `test/utils/order_items_test.dart`.
