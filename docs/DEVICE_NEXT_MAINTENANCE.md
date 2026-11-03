# DEVICE_NEXT_MAINTENANCE.md

## Visão Geral

Quem faz preventiva combina a próxima visita e depois precisa lembrar dela. A próxima manutenção fica no aparelho: o app pergunta a data ao concluir a OS, mostra "Manutenções chegando" no Início e avisa no celular 7 dias antes. Veio dos testes de usuário de 01/11/2026 (P3 do Marcos, item 3 da issue #492, ligada à #110).

É só um lembrete: não cria OS, não entra nas abertas nem no Financeiro. Data por serviço fica para depois. Geração de OS de contrato (`checkAndGenerateDueOrders`) e `reminderDaysBefore` não mudaram.

## Arquitetura

### Dados

Em `/companies/{companyId}/devices/{deviceId}`:

| Campo | Tipo | Quem grava | Uso |
|---|---|---|---|
| `nextMaintenanceDate` | texto `YYYY-MM-DD` | App | Dia da manutenção |
| `nextMaintenanceCustomer` | `{id, name}` | App | Para quem é. O aparelho não tem cliente próprio: é o cliente da OS ao marcar a data |
| `nextMaintenanceLastService` | texto | App | Serviço principal da última OS, para "Última: Troca de óleo" no Início sem uma consulta por linha |
| `nextMaintenanceNoticeFor` | texto `YYYY-MM-DD` | Function | Dia que o aviso já contou |

O aviso também usa `companies/{companyId}/settings/maintenanceNotice_{dia}`, a trava do dia. Só a Function grava nela.

O dia é texto, não `DateTime`: é um dia, não um momento, e a comparação como texto vale no app e no servidor em qualquer fuso.

No `Device`, os três primeiros têm `@JsonKey(includeToJson: false)`, como `Order.completedAt`. Quem grava é só `TenantDeviceRepository.setNextMaintenance`, com `update` destes campos. Assim, salvar um `Device` remontado de um `DeviceAggr` (que não tem data) nunca apaga a data. Pelo mesmo motivo, a ficha lê a data por `streamSingle`, não do aparelho que recebeu pela rota.

O telefone não fica no aparelho. "Chamar cliente" lê o cadastro na hora.

### Peças

| Peça | Papel |
|---|---|
| `lib/services/device_maintenance_service.dart` | Regras puras (`addMonths`, `maintenanceIsNear`, `whatsappMessageUri`, `maintenanceOrder`, `lastDoneOrder`) e `DeviceMaintenanceService` (leituras e gravação) |
| `lib/screens/devices/next_maintenance_offer.dart` | A pergunta ao concluir a OS e a contagem de recusas |
| `lib/screens/devices/maintenance_actions.dart` | Menu do item: Chamar cliente, Abrir OS, Ver aparelho |
| `lib/screens/devices/device_detail_screen.dart` | Bloco no topo da ficha |
| `lib/screens/menu_navigation/home.dart`, `home_content.dart` | "Manutenções chegando" |
| `lib/screens/order/order_screen_v2.dart` | Pergunta depois de marcar pronta |
| `firebase/functions/src/services/maintenance-notice.service.ts` | Aviso diário |
| `scheduledMaintenanceNotices` em `firebase/functions/src/index.ts` | Agendamento, às 08:00 de Brasília |

### Índice

O aviso usa uma consulta de grupo em `devices`, por isso `firestore.indexes.json` tem um `fieldOverride` de `nextMaintenanceDate` em `COLLECTION_GROUP`. Se a Function rodar antes de o índice ficar pronto, a consulta falha e a próxima execução manda o aviso, porque ele cobre os 7 dias.

### Permissões

A data segue a regra de `devices` (`canManageDevices`: dono, admin, supervisor), sem mudança no `firestore.rules`. No app, o mesmo vale por `PermissionType.manageDevices`. Técnico, consultor e gerente veem a data e o Início, mas não recebem a pergunta nem mudam a data.

## Fluxo de Dados

```
Concluir a OS (o servidor aceitou, ou 3 s sem resposta)
  → offerNextMaintenance → pickOne "Quando é a próxima manutenção?"
  → setNextMaintenance grava no aparelho
7 dias antes
  → Início: streamMaintenanceUntil(hoje + 7), tirando quem tem contrato ativo
  → 08:00: sendMaintenanceNotices → notifyMaintenanceDue → FCM e sino
Tocar no item
  → Chamar cliente: wa.me com a mensagem pronta, só com o primeiro nome
  → Abrir OS: openNewOrder(prefill: maintenanceOrder(...))
Concluir a nova OS → a pergunta volta
```

O aviso usa o caminho de sempre do servidor: `sendNotification` grava em `companies/{id}/notifications` (o sino) e envia por FCM aos `users/{id}.fcmTokens`, que o app registra. O toque no aviso só abre o app, porque ele não tem `orderId`; o Início mostra a lista.

## Regras de Negócio

1. **Quando pergunta.** OS com aparelho, com id, sem contrato, e quem concluiu pode editar aparelhos. Vale para o botão azul, para a tela de situação e para OS salva já concluída na Nova OS.
2. **3 recusas seguidas param a pergunta.** Contagem local por empresa (`next_maintenance_declined_{companyId}`). "Não repetir" e voltar sem responder contam. Definir uma data, na pergunta ou na ficha, zera a contagem.
3. **Vários aparelhos.** Uma pergunta só, e a data vale para todos. É uma gravação por aparelho, não um `WriteBatch`: um aparelho apagado não impede os outros. Só o servidor sabe disso, porque sem internet uma leitura que falha não diz que ele foi apagado.
4. **"Não repetir" não apaga preventiva distante.** Tira só a data cumprida por esta OS (atrasada ou nos próximos 7 dias). Uma corretiva não apaga a preventiva de daqui a meses. Voltar sem responder não muda nenhuma data.
5. **Contrato ativo manda.** A ficha mostra `contract.nextDueDate` com "Pelo contrato" e não pede outra. Esses aparelhos ficam fora da pergunta, do Início e do aviso. Técnico e consultor não podem consultar contratos (regra de `orders`), então para eles o Início não consegue tirar esses aparelhos.
6. **Atrasada fica.** Continua no Início, com a data em vermelho, até mudar. Quem conclui sem poder editar aparelhos deixa a data lá: um dono ou supervisor resolve por "Ver aparelho".
7. **Cada data avisa uma vez.** `nextMaintenanceNoticeFor` guarda o dia. Mudar a data avisa de novo, no dia seguinte. A trava do dia é criada antes do envio, então duas execuções ao mesmo tempo mandam um aviso só. O sino salvo conta como entrega: falha só do push não repete, e o sino não ganha cópias. Se nem o sino foi salvo, a trava é solta e a empresa tenta de novo.
8. **Quem recebe o aviso.** Dono, admin, supervisor e o responsável da última OS do aparelho, se ainda estiver na equipe. Uma mensagem por empresa, com o total.
9. **Último serviço.** É o primeiro serviço da OS naquele aparelho (linha sem aparelho vale para todos). Vem da OS concluída, na pergunta, ou da última OS concluída, na ficha. Gravar uma data sem serviço, ou tirar a data, limpa o campo. Sem ele, o Início mostra só o cliente. O aviso do celular não traz esse texto, para não alongar.
10. **Abrir OS.** Traz cliente, aparelho e os serviços da última OS concluída daquele aparelho, sem fotos. Se o histórico não puder ser lido, abre sem serviços. Nada é salvo antes do "✓".
11. **Toque duplo e falha de gravação.** O botão azul já tem a espera de `kStatusTapCooldown`. Se o servidor recusar "pronta", a situação e a marca "parada" voltam, aparece o aviso e não há pergunta. Sem internet, a pergunta sai depois de 3 segundos e a data fica na fila do Firestore. Se a gravação da data for recusada, aparece um aviso e o `streamSingle` da ficha volta sozinho. `OrderDateSheet` e o menu do item fecham uma vez só, e o Início abre um item por vez.

## Exemplos de Uso

```dart
// Próxima manutenção do aparelho, ou null
device.nextMaintenance; // DateTime(2027, 5, 12)

// Gravar ou tirar
DeviceMaintenanceService().save(
  ['deviceId'],
  date: addMonths(DateTime.now(), 6),
  customer: order.customer,
  onFailed: warn,
);
DeviceMaintenanceService().save(['deviceId'], date: null);
```
