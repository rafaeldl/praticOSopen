# ORDER_SCREEN_V2.md

## Visão Geral

Nova tela da OS (fase 1 do redesenho, sem IA), atrás da opção local **"Nova tela da OS"** (Mais › Interface, desligada por padrão). Com a opção desligada nada muda: `/order` continua abrindo o `OrderForm` antigo.

Specs: `docs/superpowers/specs/2026-10-11-telas-os-ia-design.md` (vale sobre) `2026-10-09-os-ai-assistant-design.md`, mais as seções de OS de `2026-10-10-telas-hig-design.md` e `2026-10-11-telas-paridade-design.md`.

## Arquitetura

| Arquivo | Papel |
|---|---|
| `lib/services/order_screen_preference.dart` | `OrderScreenPreference`: valor em `SharedPreferences` (`useNewOrderScreen`), espelhado num `ValueNotifier`; carregado no `main()` |
| `lib/screens/order/order_route.dart` | `OrderRoute` (rota `/order`): escolhe a tela nova ou a antiga uma vez por abertura. Abrir os comentários (`scrollToComments`/`commentId`, vindo de notificação) também vai para a nova |
| `lib/screens/order/order_screen_v2.dart` | A tela: status, próximo passo, cliente/veículo, itens, totais, "…" |
| `lib/screens/order/order_item_search_screen.dart` | "O que vai na OS?": uma busca em serviços e produtos; "Criar “X” e pôr na OS"; "Mais usados" |
| `lib/screens/order/order_item_sheet.dart` | Sheet do item: preço (em branco = sem valor), quantidade (produto), "Tirar da OS" |
| `lib/screens/order/order_screen_services.dart` | `OrderPermissions` (preços, status, apagar, campos principais, checklists, fotos) e `OrderScreenActions` (PDF, link do cliente, pagamentos, fotos e documentos, checklists, comentários, mapa, desconto, contrato), injetáveis nos testes |
| `lib/screens/order/order_extras.dart` | Sheets de data (agendar, prazo) e de endereço; `checklistMissing` |
| `lib/screens/widgets/order_custom_fields.dart` | Campos do segmento (`service_order.*`): `orderBuiltInFieldKeys`, `orderCustomFieldsFor`, `OrderCustomFieldSections`, `applyCustomFieldValue`; compartilhado com o `OrderForm` antigo |
| `lib/screens/widgets/order_media_actions.dart` | Adicionar foto/documento, abrir e apagar documento: compartilhado com `OrderMediaWidget` e `OrderForm` |
| `lib/screens/widgets/order_status_share.dart` | "Avisar o cliente?" depois de mudar o status (regras + diálogo + compartilhar o link): compartilhado com `OrderForm` |
| `lib/screens/widgets/contract_config_sheet.dart` | Sheet do contrato recorrente (saiu de dentro do `order_form.dart`) |
| `lib/utils/order_items.dart` | Soma sem os itens sem valor; "Mais usados" derivado das últimas ~50 OS |

Sem modelo novo e sem campo novo (nada muda no Firestore nem nas Functions). Estado continua no `OrderStore`; repositórios os mesmos.

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
6. "…" com 3 grupos: "Adicionar à OS ›"; "Mandar para o cliente" · "PDF"; "Cancelar OS" / "Apagar OS" em vermelho.
7. "Adicionar à OS ›" mostra só o que a OS ainda não tem: Checklist, Fotos ou documento, Comentário, Endereço do atendimento (com atendimento fora), Agendar dia e hora (com agenda), Prazo de entrega, Desconto (com `viewPrices`, depois de aprovada e com saldo), Repetir esta OS (com contratos) e Outro veículo. Sem `canEditOrderMainFields`/`canManageOrderForms`/`attachPhotos` as opções somem. Não há mais atalho para a tela antiga ("Outros campos"): campos do ramo e vários veículos já aparecem aqui.
8. "Nesta OS" mostra só o que existe: agendado, prazo, endereço (tocar: abrir no mapa, mudar, tirar), contrato (frequência e próxima data; tocar: mudar ou desativar; OS gerada leva à OS do contrato), checklists (ponto âmbar/verde e "Faltam N perguntas"; deslizar apaga depois de confirmar). Depois "OS geradas", "Fotos" (tocar abre o visualizador), "Documentos" (tocar abre; deslizar apaga) e os comentários no fim da OS salva.
9. Depois de mudar para Aprovada, Em andamento ou Pronta, "Avisar o cliente?" (mesma regra da tela antiga: cliente com telefone, sem link ativo, sem "Agora não" nesta sessão). "Enviar via WhatsApp" abre o compartilhar com o link.
10. Desconto entra como transação (`addDiscountTransaction`, o mesmo do Receber) e aparece acima do total.
11. Sem foto de capa; fotos aparecem em "Fotos" só quando existem.
12. Campos do segmento (`customData`) aparecem na OS logo depois dos itens, agrupados por seção, com as mesmas regras do `OrderForm` (campos já fixos da tela ficam de fora; esvaziar o último apaga `customData`). Gravam na hora numa OS salva e só em memória até "Salvar OS" numa nova.
13. Com 2 ou mais veículos os itens se agrupam por veículo (e "Geral" para os sem veículo), cada bloco com o seu "Subtotal" (só com `viewPrices`). Ao pôr um item, a mesma pergunta da tela antiga (`DevicePickerSheet`): um veículo, vários, todos ou geral.
14. Foto e "Falar o que fazer" só aparecem na Nova OS com `kAiOrderAssistEnabled` (desligado por padrão). A IA preenche a mesma tela com marca-texto; ver `docs/AI_ORDER_ASSIST.md`.

## Exemplos de Uso

```dart
// Ligar a tela nova neste aparelho
await OrderScreenPreference.set(true);
Navigator.pushNamed(context, '/order'); // OS nova em branco
Navigator.pushNamed(context, '/order', arguments: {'order': order});
```

Testes: `test/screens/order/order_screen_v2_test.dart`, `test/screens/order/order_screen_v2_extras_test.dart`, `test/screens/widgets/order_status_share_test.dart`, `test/screens/order/order_route_test.dart`, `test/utils/order_items_test.dart`.
