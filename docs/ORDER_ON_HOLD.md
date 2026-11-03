# ORDER_ON_HOLD.md

## Visão Geral

Marca de **OS parada**: diz por que um serviço aprovado ou em andamento parou e há quantos dias. É separada da situação da OS (`status`): nenhum status novo foi criado, e financeiro, métricas e filtros por situação não leem a marca. Uma OS parada continua onde estava.

Origem: teste de usuário da persona Sandra (P1, gravidade 4) e item 2 da issue #492.

## Arquitetura

### Dados

Campo `onHold` no documento `/companies/{companyId}/orders/{orderId}`:

```json
{
  "onHold": {
    "reason": "part",
    "note": "Bomba chega sexta",
    "since": "2026-11-02T12:30:00.000Z"
  }
}
```

| Campo | Regra |
|-------|-------|
| `reason` | Obrigatório: `part`, `customer`, `authorization` ou `other` (`OrderHoldReason`) |
| `note` | Opcional, até 500 caracteres. Sem observação, a chave não existe |
| `since` | Obrigatório. Início da parada, ISO em UTC. Os dias parados contam dias de calendário no fuso do aparelho |

Sem marca, o campo não existe: retomar apaga o campo.

### Código

| Parte | Onde |
|-------|------|
| Modelo | `lib/models/order.dart`: `OrderHold`, `OrderHoldReason`, `Order.onHold`, `isOnHold`, `canBeOnHold` |
| Estado | `lib/mobx/order_store.dart`: `hold`, `markOnHold`, `resumeHold`, limpeza em `setStatus` |
| Gravação | `TenantOrderRepository.setHold` |
| Permissão | `AuthorizationService.canChangeOrderHold`, `OrderPermissions.canChangeHold` |
| Tela da OS | `lib/screens/order/order_screen_v2.dart`, `lib/screens/order/order_hold_sheet.dart` |
| Início | `HomeView.onHold`, `HomeRules.stopped`, `OrderListRow.holdText`, `OrderHoldStyle` (`lib/theme/status_style.dart`) |
| Servidor | `firebase/functions/src/services/order-hold.service.ts`: limpeza chamada por `handleOrderUpdatedAsaas`; `setOrderHold`/`removeOrderHold` para `POST`/`DELETE /v1/app/orders/:id/hold` (app web, `docs/WEB_API.md`) |
| Regras | `orderHoldValid` e `orderHoldChangeAllowed` em `firebase/firestore.rules` |

### Por que `onHold` fica fora do `toJson`

Como `completedAt`, o campo usa `@JsonKey(includeToJson: false)`. O save completo da OS é um `set(merge)` com a cópia que está na memória; se levasse a marca, uma cópia velha em outro aparelho traria de volta uma marca já retirada. Por isso a marca só é gravada por `setHold`, em um `update` próprio que funciona offline. Versões antigas do app também preservam o campo, porque não o conhecem.

## Fluxo de Dados

```
Marcar:   toque em "Marcar como parada" → toque no motivo
          → OrderStore.markOnHold → setHold → comentário interno

Retomar:  botão azul "Retomar serviço" (ou menu "…")
          → OrderStore.resumeHold → setHold(null) → comentário interno

Concluir, cancelar ou voltar a orçamento pelo app:
          OrderStore.setStatus → save da OS → setHold(null)

Mudar a situação por API, bot, MCP ou app antigo:
          trigger onOrderUpdatedAsaas → clearOrderHold
```

## Regras de Negócio

1. Só vale para OS `approved` ou `progress`.
2. O motivo é obrigatório e a observação é opcional. O início é o momento em que a pessoa marcou.
3. Marcar leva 2 toques a partir da OS: o link abaixo do botão azul e o motivo. A observação, se houver, é escrita antes do motivo. O menu "…" oferece a mesma ação.
4. Enquanto a OS está parada, o botão azul é "Retomar serviço". Retomar não muda a situação da OS.
5. Concluir e cancelar continuam disponíveis pela situação da OS e tiram a marca. Voltar para orçamento também.
6. Ir de `approved` para `progress` (ou o contrário) não tira a marca, porque a OS continua onde ela vale. Só o "Retomar serviço" a remove nesse caso.
7. Uma marca que sobrou em OS fora de `approved` e `progress` é ignorada na tela (`isOnHold`) até o trigger apagá-la.
8. Se o servidor recusar a gravação, a tela desfaz a marca (ou a traz de volta, ao retomar), mostra um aviso e não grava comentário. Se a recusa vier ao tirar a marca por mudança de situação, nada é desfeito: a marca fica oculta e o trigger a remove.
9. "Retomar serviço" usa o mesmo intervalo de 800 ms do botão azul: um toque duplo não conclui a OS.
10. Financeiro não muda: a OS parada continua contando onde contava.
11. O Início ganha o filtro "Paradas", com as mais antigas primeiro. Em todos os filtros, a OS parada mostra motivo e dias parados. Atrasada e parada ao mesmo tempo, fica com o ponto vermelho e mantém a linha da parada.

### Permissão

Mesma regra de quem muda a situação de OS aprovada ou em andamento:

| Perfil | Marcar e retomar |
|--------|------------------|
| Dono, Admin, Gerente | Sim, em qualquer OS |
| Supervisor | Sim, em qualquer OS |
| Técnico | Sim, nas OS que ele acessa pelas regras |
| Consultor | Não: ele só decide orçamentos |

O consultor vê a marca, mas não a muda. A regra e o app ficam alinhados em `orderHoldChangeAllowed` e `canChangeOrderHold`; os casos estão em `firebase/functions/src/__tests__/rbac/firestore-matrix.ts` (`orders.hold.*`).

### Histórico

O app não tem uma linha do tempo da OS. O padrão existente para registrar acontecimentos é o comentário interno (`addOrderComment`), que aparece na OS e não aparece para o cliente no link. Marcar e retomar deixam um comentário interno com o motivo, ou com os dias parados. A tela grava esse comentário por `OrderScreenActions.logOrderEvent`, depois que o servidor aceita a marca. Sem internet, o comentário espera a conexão voltar com o app aberto. Concluir ou cancelar uma OS parada não gera comentário.

## Exemplos de Uso

```dart
final store = OrderStore()..setOrder(order);

store.markOnHold(reason: OrderHoldReason.part, note: 'Bomba chega sexta');
order.isOnHold; // true
order.onHold!.daysSince(DateTime.now()); // 0

store.resumeHold();
order.isOnHold; // false
```

```dart
// Texto da linha na lista e na OS
OrderHoldStyle.line(l10n, order.onHold!, DateTime.now());
// "Parada há 3 dias · Esperando peça"
```

## Testes

| Arquivo | Cobre |
|---------|-------|
| `test/models/order_hold_test.dart` | Modelo, dias parados, JSON, permissão por perfil |
| `test/mobx/order_store_hold_test.dart` | Marcar, retomar e limpeza por situação |
| `test/screens/order/order_screen_v2_test.dart` | Grupo `stopped order`: 2 toques, retomar, concluir, permissões |
| `test/screens/menu_navigation/home_content_test.dart` | Grupo `Paradas` |
| `firebase/functions/src/services/__tests__/order-hold.service.test.ts` | Limpeza pelo trigger |
| `firebase/functions/src/__tests__/rbac/firestore-matrix.ts` | Regras por perfil (`npm run test:rbac`) |

## Limites conhecidos

- Bot e MCP não mostram nem mudam a marca: eles só a perdem quando a situação sai de `approved` e `progress`. A API do app web marca e retoma (`/v1/app/orders/:id/hold`), com a mesma permissão e o mesmo comentário interno.
- A data de início é o momento da marcação: não dá para informar uma data passada.
- O aviso "OS paradas" de Lembretes é outra coisa: conta OS abertas há mais de 7 dias, marcadas ou não.
