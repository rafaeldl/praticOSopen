# CONTRACTS_SERVER_JOB.md

## Visão Geral

A OS de contrato recorrente hoje nasce no aparelho: ao abrir o app, `checkAndGenerateDueOrders` (`lib/mobx/order_store.dart`, chamado em `auth_wrapper.dart` quando a empresa tem `useContracts`) gera as OS vencidas. Sem app aberto, nada é gerado, e o web não pode repetir a regra sem duplicar.

O servidor agora tem a mesma geração, em três entradas:

| Entrada | Quando | `now` |
|---|---|---|
| `scheduledContractOrders` (job) | Todo dia às 02:00 de Brasília, só com `config/contracts.jobEnabled == true` | Horário agendado do job (`event.scheduleTime`) |
| `POST /v1/app/contracts/generate-due` | Quando o app ou o web pedir | Hora da chamada |
| App antigo | Ao abrir, como sempre | `DateTime.now()` do aparelho |

O app não mudou nesta etapa.

## Arquitetura

- `firebase/functions/src/services/contract-generation.ts`: regras puras (vencimento, próximo vencimento, OS gerada, id da OS). Sem Firestore.
- `firebase/functions/src/services/contract.service.ts`: transação por modelo, empresas com `useContracts`, chave do job.
- `firebase/functions/src/routes/v1/contracts.routes.ts`: a rota.
- `firebase/functions/src/index.ts`: o job.
- Casos compartilhados: `docs/web-app/contract-cases/contract-generation.json`, rodando no Dart (`test/contract/contract_generation_cases_test.dart`, com o `generateOrderFromContract` real) e em Functions (`contract-generation.cases.test.ts`).

Firestore:

```
companies/{companyId}                    useContracts, name, country
companies/{companyId}/orders/{modelo}    isContract: true, contract { ... }
companies/{companyId}/orders/contract_{modelo}_{AAAAMMDD}   OS gerada (servidor ou app, mesmo id)
config/contracts                         jobEnabled (chave global do job)
```

## Fluxo de Dados

Para cada empresa com `useContracts == true`, a consulta `isContract == true` traz os modelos. Para cada modelo vencido, uma transação:

1. Lê o modelo e confere de novo: `contract.active == true`, `nextDueDate <= now`, dia do vencimento até o dia do `endDate` e `autoGenerate == true`.
2. Calcula o id `contract_{idDoModelo}_{AAAAMMDD}`, o dia do vencimento no fuso da empresa (America/Sao_Paulo enquanto a empresa não tem fuso próprio). O app usa a mesma função (`lib/utils/contract_generation.dart`, PR #513).
3. Lê a OS desse id. Se não existe, grava a OS.
4. Atualiza no modelo só `contract.lastGeneratedDate`, `contract.nextDueDate`, `contract.generatedCount` e, se não há próximo vencimento ou ele passa do `endDate`, `contract.active = false`.

O número da OS fica vazio: o gatilho `firestoreUpdateTenantOSNumber` numera, igual à OS do app.

## Regras de Negócio

Uma regra só para app e servidor, provada pelos casos (`contract-generation.json`, versão 2):

- **Vence** quando `active == true`, `nextDueDate <= agora` e o dia do vencimento não passa do dia do `endDate` (o término conta como incluído).
- **Gera** só com `autoGenerate == true`. Contrato só de lembrete não cria OS.
- **OS gerada**: cliente, `device`/`devices`/`deviceIds` (normalizados como `Order.fromJson`), serviços e produtos só com item, descrição, valor, quantidade e total da linha (cai foto e `deviceId` da linha), responsável, `createdBy` e `updatedBy` = autor do modelo, `company` = `{id, name, country}`, situação `quote`, pagamento `unpaid`, `photos: []`, total = soma das linhas sem desconto, `contract = {parentOrderId, parentOrderNumber}`. Endereço, campos extras, datas e desconto do modelo não são copiados.
- **Próximo vencimento**: `lastGeneratedDate = agora` e o próximo vencimento é o primeiro depois de agora, contando períodos a partir do vencimento gerado:
  - diário e semanal: + N dias, mantendo a hora do vencimento;
  - mensal e anual: meia-noite, com o dia rolando como o `DateTime` do Dart (31/01 → 03/03; 30/01 → 02/03; 29/02 anual → 01/03). Depois de rolar, o contrato fica no dia novo.
  - frequência desconhecida: próximo vencimento vazio, e o contrato para.
- **Dias perdidos** não são repostos: app fechado por 3 meses gera uma OS só, nunca uma por abertura. Gerar atrasado não muda o dia do contrato (vencia dia 15, gerou dia 20, continua vencendo dia 15).
- **Fim**: nada é gerado com vencimento depois do `endDate`. Se o próximo vencimento passa do `endDate`, o contrato desliga (`active = false`).
- **Perfil (rota)**: precisa de `createOrder` (gerente não gera). Consultor e técnico geram só dos contratos que criaram, como a consulta do app.
- **Datas**: o app grava hora local sem fuso (`2026-12-03T00:00:00.000`). O servidor lê essas datas como hora de Brasília e grava no mesmo formato. Data com `Z` ou fuso é convertida.

## Idempotência

- Job, rota e retentativa juntos: uma OS. Teste com 20 gerações em paralelo no emulador (`contract-concurrency.emulator.test.ts`).
- Retentativa do job usa o mesmo horário agendado e não acha nada vencido.
- Modelo "voltado" por um save antigo da tela (mesmo vencimento de novo): a OS daquele id já existe, então só avança o modelo (`alreadyGenerated`).
- O próximo vencimento conta do vencimento, não da hora em que o job rodou: um job atrasado alguns segundos não pula o dia seguinte (teste `a daily contract run a few seconds late`).

## App antigo gerando junto

O app não usa transação: lê a consulta, grava a OS com id aleatório e regrava o modelo inteiro. Testes no emulador com o mesmo passo a passo:

| Ordem | Resultado |
|---|---|
| App termina antes do servidor | 1 OS (o servidor vê o modelo avançado) |
| Servidor termina antes e o app lê dado novo | 1 OS |
| Servidor grava entre a leitura e o save do app | **2 OS**. O save do app ganha: mesmo próximo vencimento, `generatedCount` perde uma |
| Servidor grava entre a OS e o save do modelo | **2 OS** |
| App lê o resultado em cache de antes do job | **2 OS**, horas depois |

**Janela medida** (emulador, com atraso de rede simulado por chamada):

- sem atraso: o app lê em ~4 ms e salva o modelo em ~9 ms; duplica se o job começa até ~10 ms antes ou junto;
- 150 ms por chamada: lê em ~155 ms e salva em ~470 ms; duplica com o job começando entre ~200 e ~400 ms depois de o app abrir.

Ou seja, a janela vai da leitura do app até o save do modelo: duas idas ao servidor (gravar a OS e o modelo). No celular, em 4G, isso fica na casa de centenas de milissegundos a poucos segundos. Offline, o `await` da gravação não termina até voltar a rede, e a janela dura o tempo offline.

**O caso que importa é o cache.** O app lê `streamContractOrders(...).first`. Com o cache local ligado (padrão no celular), a primeira resposta de um listener vem do cache quando há documentos guardados (`QueryListener::ShouldRaiseInitialEvent` no SDK nativo, `wait_for_sync_when_online` falso). Com o job ligado, o modelo avança de madrugada e o celular abre de manhã com o contrato ainda "vencido" no cache. Resultado esperado: uma OS a mais para quase todo contrato vencido de empresa que abre o app no dia. Isso não foi reproduzido em aparelho; o teste reproduz a leitura em cache.

## Ligar o job

Desligado por padrão: o deploy sobe o job, mas ele sai sem fazer nada enquanto `config/contracts.jobEnabled` não for `true`. Antes de ligar:

1. O app precisa parar de gerar sozinho (chamar a rota em vez de `checkAndGenerateDueOrders`, ou ler o modelo do servidor dentro de transação), e as versões antigas precisam sair de uso.
2. Ou aceitar o risco de duplicar com alguma proteção do servidor. Opções no fim deste documento.

A rota pode ser usada pelo web desde já: ela tem o mesmo risco que dois celulares abertos hoje.

## Pendente de decisão

- Quando ligar o job e o que fazer com as versões antigas do app (acima).
- Proteção opcional contra a OS duplicada do app antigo: um gatilho na criação que encontre a OS do mesmo modelo e vencimento gerada pelo servidor e marque ou apague a do app. Não foi feito: apaga dado criado pelo usuário.
- Empresas abandonadas com `useContracts` vão passar a receber uma OS por período para sempre. Hoje só gera quem abre o app. Talvez gerar só para empresa com uso recente ou plano ativo.
- Empresas fora do Brasil: o job roda no horário de Brasília. Para fusos a oeste (ex.: EUA), a OS mensal sai na noite anterior pelo horário local.
- Regras herdadas do app que talvez não sejam as desejadas: dia 31 vira dia 3 e fica; linha perde `deviceId` e foto.
- App com o PR #513 usa o mesmo id e cria a OS em transação, então não duplica com o job. Consultor e técnico não leem OS que ainda não existe: para eles o app relê o modelo no servidor e só gera se ele ainda vence na mesma data.

## Exemplos de Uso

```bash
# Ligar o job (decisão do dono, não fazer antes do item "Ligar o job")
# Firestore: config/contracts { jobEnabled: true }

# Rota
curl -X POST "$API/v1/app/contracts/generate-due" \
  -H "Authorization: Bearer $ID_TOKEN" -H "X-Company-Id: $COMPANY"
# → { success, data: { contractsOn, generated, alreadyGenerated, errors, orders: [{ templateId, orderId }] } }
```

Testes:

```bash
cd firebase/functions
npm test                 # casos, serviço e rota (Firestore em memória)
npm run test:contracts   # concorrência no emulador (também roda em test:rules)
fvm flutter test test/contract/contract_generation_cases_test.dart   # no PR #513
```
