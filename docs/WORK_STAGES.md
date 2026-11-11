# WORK_STAGES.md

## Visão Geral

**Etapas** dizem em que ponto da oficina está uma OS em andamento (por exemplo, Pintura e depois Polimento) e em que ordem cada equipe trabalha. A situação da OS não muda: a etapa só vale enquanto a OS está em `progress`. Financeiro, nota fiscal, filtros, IA e bot não leem nada novo.

Origem: pedido de uma funilaria com duas equipes, em que o dono monta todo dia a ordem de cada equipe e entrega impressa (issue #637). Cada OS fica em **uma etapa por vez**.

É desligado por padrão: sem `workStages` na empresa, nada muda em lugar nenhum.

## Arquitetura

### Dados

Na empresa, `/companies/{companyId}`:

```json
{
  "workStages": [
    { "id": "paint", "name": "Pintura", "keywords": ["pint", "lataria"] },
    { "id": "polish", "name": "Polimento", "keywords": ["polim", "higien"] }
  ]
}
```

| Campo | Regra |
|-------|-------|
| `id` | Obrigatório, fixo (é o que a OS guarda) |
| `name` | Obrigatório, o que aparece na coluna e na folha |
| `keywords` | Opcional. Pedaços do nome do serviço que pertencem à etapa, sem acento e sem maiúscula. Decidem a folha impressa e a sugestão "Próxima: X" |

A ordem da lista é a ordem das colunas. Entrada sem `id` ou sem `name` é ignorada. Dono e admin configuram no web, em Ajustes › Sua empresa › Etapas do serviço (ver abaixo).

Na OS, `/companies/{companyId}/orders/{orderId}`:

```json
{ "stage": { "id": "paint", "rank": 1730900000000, "since": "2026-11-06T12:30:00.000Z" } }
```

| Campo | Regra |
|-------|-------|
| `id` | Uma etapa de `workStages` |
| `rank` | Posição na coluna, número com casas decimais: menor fica em cima. Mover uma OS grava só ela (a média entre as vizinhas), nunca reescreve a coluna |
| `since` | Quando entrou nesta etapa. Reordenar dentro da etapa não muda |

### Código

| Parte | Onde |
|-------|------|
| Servidor | `firebase/functions/src/services/order-stage.service.ts`: `setOrderStage`, `clearOrderStage`, `workStagesOf` |
| Rota | `PUT /v1/app/orders/:id/stage` (`docs/WEB_API.md`) |
| Permissão | `canChangeOrderStage` (mesma da OS parada) e `canChangeOrderStatus(..., 'progress')` para começar uma aprovada |
| Limpeza | `updateOrder` tira a etapa quando a situação sai de `progress`; o trigger `handleOrderUpdatedAsaas` cobre os outros caminhos (app, bot, MCP) |
| Web | `src/lib/orders/stages.ts` (leitura, coluna, ordem, serviços da etapa), `OrderBoard.vue`, `StagePrint.vue`, `lib/print-frame.ts`, `TvBoardView.vue` |
| App Flutter | `lib/models/work_stage.dart` (`WorkStage.listFrom/of/next`, `OrderStage`), `SegmentConfigProvider.workStages` (lido em `auth_wrapper.dart`), `OrderStore.moveToStage`, `lib/services/order_stage_api_service.dart` (chama a mesma rota) e a tela da OS (`order_screen_v2.dart`). `Order.stage` tem `includeToJson: false`: o save completo nunca o grava |

## Fluxo de Dados

```
Arrastar de Aprovado para Pintura (ou "…" → Pintura, ou Shift + →)
  → PUT /orders/:id/stage {stageId: paint}
  → mesma transação: status progress (+ pagamento como em updateOrder), stage, comentário "Etapa: Pintura"

Arrastar dentro de Pintura (ou Alt + ↑/↓, ou "Subir/Descer na fila")
  → PUT /orders/:id/stage {stageId: paint, rank: média das vizinhas}
  → só a posição; sem comentário

De Polimento para Concluído
  → PATCH /orders/:id {status: done} → updateOrder apaga stage

Tela da OS no app: botão azul "Passar para Polimento" (ou "…" → "Mudar etapa")
  → PUT /orders/:id/stage {stageId} (sem rank: fim da coluna)
  → a tela muda na hora e volta, com aviso, se o servidor recusar ou não houver internet

Situação mudada pelo app, bot ou MCP
  → trigger onOrderUpdated → clearOrderStage (só se a OS saiu de progress)
```

## Regras de Negócio

1. A etapa só existe em `progress`. Lida fora disso, é ignorada (`normalizeOrder`) até ser apagada.
2. Uma OS em andamento sem etapa (posta em andamento pelo app ou antes das etapas), ou com uma etapa que a empresa tirou, aparece na **primeira** coluna, pela data de criação. É a mesma escala do `rank` que o servidor grava sem posição (a hora), então dá para pôr um cartão acima, entre ou abaixo dessas OS.
3. Pôr uma OS aprovada numa etapa a passa para em andamento na mesma gravação. Quem não pode fazer essa passagem recebe 403.
4. Quem muda de etapa e reordena: dono, admin, gerente, supervisor e o técnico nas OS que vê. O consultor não (mesma regra da OS parada).
5. Sem `rank`, a OS vai para o fim da coluna (o servidor usa a hora). Na tela, a ordem muda na hora e volta se o servidor recusar.
6. Folha impressa: data, nome da etapa e, na ordem da coluna, número, cliente, veículo, os serviços da etapa (pelas palavras; todos, se nenhum bater) e um quadrado para marcar. Nunca valores. Abre pelo "…" do cabeçalho da coluna e sai por um quadro escondido só com a folha (`src/lib/print-frame.ts`): imprimir a página inteira saía em branco no Safari.
7. Modo TV: "Em andamento" vira uma coluna por etapa, na ordem do quadro.
8. A OS parada continua com a marca na etapa; atrasada e parada aparecem no cartão como sempre.
9. No app, a linha da situação fica "Em Andamento · Pintura". O botão azul em andamento leva à próxima etapa; na última, volta a ser "Marcar como pronta". Com duas etapas ou mais, tocar na linha da situação abre "Qual a situação?" com uma linha por etapa no lugar de "Em Andamento" ("Em Andamento · Pintura", "Em Andamento · Polimento"), e "Mudar etapa" também fica no "…". Quem vê os botões segue a mesma permissão da OS parada. "Começar serviço" continua só mudando a situação: a OS cai na primeira etapa.

## Etapas do serviço (web)

Em Ajustes › Sua empresa, linha "Etapas do serviço" (só dono e admin, como o resto da tela). A linha mostra as etapas em ordem ("Pintura → Polimento") ou "Desligado". Abre uma gaveta onde se adiciona, renomeia, sobe, desce e tira etapas, e escreve as palavras dos serviços que sugerem cada uma (opcional, separadas por vírgula).

- Grava direto no documento da empresa (`saveCompany`, igual aos outros ajustes; as regras já deixam dono e admin gravar) e atualiza `session.company`, então o Quadro muda sem recarregar.
- Etapa que já existia mantém o `id`, mesmo trocando o nome: as OS continuam onde estão. Etapa nova ganha um `id` tirado do nome, sem acento e sem repetir (`stageIdFor`).
- Nome vazio ou repetido não salva e mostra o erro. Palavras são guardadas em minúsculas, sem repetir.
- Tirar todas grava `workStages: []`: etapas desligadas e Quadro de volta a uma coluna por situação. OS numa etapa tirada aparecem na primeira.
- No app, as etapas novas aparecem quando o app recarrega a empresa (ao abrir de novo).
- Código: `src/components/settings/StagesForm.vue`, `stagesFromDrafts`/`draftsOf`/`stageIdFor` em `src/lib/orders/stages.ts`.

## Exemplos de Uso

Ligar para uma empresa por script (Admin SDK), sem a tela:

```js
await db.doc(`companies/${companyId}`).set({
  workStages: [
    { id: 'paint', name: 'Pintura', keywords: ['pint', 'lataria', 'conserto'] },
    { id: 'polish', name: 'Polimento', keywords: ['polim', 'higien'] },
  ],
}, { merge: true })
```

Desligar: apagar `workStages` (as OS mantêm `stage` até sair de em andamento, sem efeito na tela).

## Testes

| Arquivo | Cobre |
|---------|-------|
| `firebase/functions/src/services/__tests__/order-stage.service.test.ts` | Limpeza pelo trigger, leitura de `workStages` |
| `firebase/functions/src/routes/v1/__tests__/orders.routes.test.ts` | Grupo "etapas da OS": começar, reordenar, comentário, recusas, sair de em andamento |
| `firebase/functions/src/__tests__/rbac/api-matrix.ts` | `orders.stage.set` por perfil |
| `firebase/webapp/tests/work-stages.test.ts` | Coluna, ordem, posição entre vizinhas, serviços da etapa, sugestão, e a edição (ids mantidos, ids novos, nome vazio ou repetido) |
| `firebase/webapp/e2e/company.spec.ts` | Etapas do serviço: criar, ordenar, ver no Quadro e desligar |
| `test/models/work_stage_test.dart` | Leitura de `workStages`, etapa atual e próxima, save sem `stage` |
| `test/mobx/order_store_stage_test.dart` | Mudança na hora, volta quando o servidor recusa, limpeza ao sair de em andamento |
| `test/services/order_stage_api_service_test.dart` | `PUT` com etapa, token e empresa; recusa |
| `test/screens/order/order_screen_v2_extras_test.dart` | Grupo "work stages": linha da situação, botão azul, "Mudar etapa", etapas na lista de situações, sem etapas igual |
| `firebase/webapp/e2e/work-stages.spec.ts` | Quadro com etapas: começar, Alt + seta, imprimir, Shift + seta, consultor |

## Limites conhecidos

- A tela de etapas existe só no web; no app ainda não.
- No app, a etapa só aparece na tela da OS (não na Início nem nas listas). Mudar de etapa pelo app precisa de internet.
- O Quadro carrega as 130 OS mais novas; uma OS em andamento muito antiga pode ficar de fora da coluna.
- Quem lê pela API (sem valores) não tem os serviços na lista: a folha impressa sai sem eles e o cartão não sugere a próxima etapa.
