# DEVICE_READING.md

## Visão Geral

A "leitura" é o que um medidor do equipamento marca em cada visita: a quilometragem do veículo, o horímetro da máquina, o contador de páginas da impressora. O nome, a unidade e a existência do campo vêm do ramo. Onde o ramo não mede nada (celular, eletrônica), nada aparece.

O que a pessoa vê:

- **Cadastro do equipamento**: o campo fica no primeiro cartão, logo abaixo da placa ou do número de série, e não em "Mais dados".
- **OS**: abaixo de cada equipamento do cabeçalho aparece "Quilometragem: 98.000 km". Numa OS em aberto sem leitura, aparece "+ Quilometragem", que abre uma folha com o número.
- **Ficha do equipamento**: a última leitura ao lado da placa ("Placa ABC1D23 · 98.000 km") e, em cada OS do histórico, a leitura daquela visita.
- **Web**: o mesmo no formulário, na OS e na ficha do aparelho.

## Arquitetura

### Qual campo é a leitura

O ramo marca o campo do equipamento com `reading: true` em `segments/{id}.customFields`. O nome vem de `labels` e a unidade de `suffix`:

```js
{
  key: 'device.mileage',
  type: 'number',
  labels: { 'pt-BR': 'Quilometragem', 'en-US': 'Mileage', 'es-ES': 'Kilometraje' },
  suffix: 'km',
  reading: true,
}
```

Hoje (`firebase/scripts/seed_segments.js`):

| Ramo | Campo | Unidade |
|---|---|---|
| `automotive` | `device.mileage` (Quilometragem) | km |
| `asset_maintenance` | `device.operatingHours` (Horas de Operação) | h |
| demais | nenhum | — |

Um segmento salvo antes da marca continua funcionando: sem nenhum campo marcado, `device.mileage` e `device.operatingHours` (campos numéricos) são tratados como leitura (`legacyReadingKeys`). Para outro ramo ganhar leitura (ex.: contador de páginas em impressoras), basta criar o campo numérico no segmento com `reading: true`.

### Onde fica o valor

| Onde | Campo | O que é |
|---|---|---|
| Equipamento | `devices/{id}.customData.{fieldName}` (ex. `customData.mileage`) | Última leitura. É o mesmo campo que já existia: dados antigos continuam aparecendo. |
| OS | `orders/{id}.deviceReadings` = `{ deviceId: número }` | Leitura de cada equipamento naquela visita. Ausente quando não há. |

Nenhuma migração: OS antigas simplesmente não têm `deviceReadings`.

### Código

| Camada | App (Flutter) | Web |
|---|---|---|
| Regras puras | `lib/utils/device_reading.dart` | `firebase/webapp/src/lib/device-reading.ts` |
| Campo do ramo | `CustomField.reading`, `SegmentConfigProvider.readingField` | `readingFieldOf(segmentFieldList())` |
| Modelo da OS | `Order.deviceReadings`, `OrderStore.setDeviceReading` | `Order.deviceReadings` (`lib/orders/model.ts`) |
| Atualizar equipamento | `TenantDeviceRepository.setReading` via `OrderScreenActions.recordDeviceReading` | `saveDevice` (API `/v1/app/devices/:id`) em `OrderDetail.vue` |
| Telas | `device_form_screen.dart`, `order_screen_v2.dart` (`_buildReading`), `device_reading_sheet.dart`, `device_detail_screen.dart`, `order_history_row.dart` (`detail`) | `DeviceForm.vue`, `OrderDetail.vue`, `ReadingDialog.vue`, `DeviceDetail.vue` |
| Servidor | — | `order-projection.ts` devolve `deviceReadings` (sem dinheiro) para quem não vê valores |

## Fluxo de Dados

```
OS: "+ Quilometragem" → folha → 98000
  → orders/{id}.deviceReadings.{deviceId} = 98000       (sempre)
  → devices/{deviceId}.customData.mileage = 98000      (se pode cadastrar equipamentos
                                                        e a leitura não volta)
Ficha do equipamento ← customData.mileage (última) + deviceReadings de cada OS (histórico)
```

## Regras de Negócio

1. Só número inteiro, zero ou mais. Pontos e vírgulas digitados em valores antigos ("98.000") são separadores de milhar.
2. A leitura da OS sempre é salva. O equipamento só recebe a leitura quando ainda não tem nenhuma ou quando ela não é menor que a atual (medidor só sobe; uma OS antiga editada depois não volta o hodômetro). O cadastro do equipamento continua editando o valor à mão.
3. Atualizar o equipamento exige a permissão de cadastrar equipamentos (`manageDevices` / `canRegisterDevices`). Sem ela, só a OS guarda a leitura.
4. "+ Quilometragem" aparece só em OS em aberto (orçamento, aprovada, em andamento) e para quem pode editar a OS. Leitura já salva aparece em qualquer situação.
5. OS com mais de um equipamento: uma leitura por equipamento, com o nome dele ao lado.
6. A leitura é gravada por chave (`deviceReadings.<deviceId>`), nunca o mapa inteiro: duas pessoas lançando leituras de equipamentos diferentes na mesma OS mantêm as duas (app: `OrderFieldDiff.keyedFields`; web: `writes.setDeviceReading`).

## Pergunta do checklist ligada à leitura (#646)

Uma pergunta numérica do modelo de checklist com `FormItemDefinition.reading: true` é a leitura do equipamento do checklist. No seed: "Quilometragem Atual" (`km_atual`) na Entrada do Veículo (automotive) e "Horas de operação" (`horas_operacao`) na Entrada do Equipamento (asset_maintenance).

```
Checklist: "Quilometragem Atual" → 98000
  → resposta do checklist (como sempre)
  → OrderStore.setDeviceReading(deviceId, 98000)    (mesmo caminho do "+ Quilometragem")
  → TenantDeviceRepository.setReading(...)           (se pode cadastrar equipamentos)
Abrir checklist com a OS já com leitura → a pergunta vazia já vem respondida
Resposta < última visita → aviso "Menor que os 102.000 km da última visita. Está certo?" (não trava)
```

- **Equipamento**: o do checklist (`OrderForm.deviceId`) ou, sem ele, o único da OS. Sem equipamento, com vários e nenhum escolhido, ou em ramo sem leitura: pergunta normal.
- **Última visita**: a última leitura do equipamento (`customData`), lida ao abrir o checklist. Se ela é igual à leitura desta OS, veio desta visita e não há aviso.
- **IA (#688)**: a resposta que a IA aplicar deve passar pelo mesmo `_saveItemResponse` do `FormFillScreen`, que já chama `_syncReading`.
- Código: `lib/utils/checklist_reading.dart`, `FormFillScreen.readingLink`, `_readingLinkFor` em `order_screen_v2.dart`, `OrderScreenActions.deviceLastReading`.

## Fora deste desenho

- **Checklist no web**: o app web não liga a pergunta à leitura (o km respondido lá fica só no checklist).
- **Editor de modelo**: o editor do app mantém a marca `reading` ao editar a pergunta, mas não tem chave para ligar ou desligar.
- PDF e página do cliente ainda não mostram a leitura.

## Exemplos de Uso

```dart
final field = context.read<SegmentConfigProvider>().readingField; // null: ramo sem leitura
if (field != null) {
  final last = deviceReading(device.customData, field);           // 98000
  formatReading(field, last, FormatService()..setLocale('pt'));    // "98.000 km"
}
```

```ts
const field = readingFieldOf(segmentFieldList())
formatReading(field, order.deviceReadings?.[deviceId], session.company?.country) // "1.250 h"
```
