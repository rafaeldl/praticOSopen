# Sistema Financeiro - PráticOS

O PráticOS possui um sistema financeiro completo para gestão de pagamentos, descontos e acompanhamento de faturamento.

## Visão Geral

O sistema financeiro permite:
- Registrar pagamentos parciais ou totais
- Aplicar descontos com histórico
- Acompanhar status de pagamento (Pago, Parcial, A Receber)
- Visualizar dashboard financeiro com totais e ranking de clientes
- Gerar PDF com resumo financeiro

---

## Status de Pagamento

| Status | Descrição | Cor |
|--------|-----------|-----|
| A Receber | Nenhum pagamento registrado | Laranja |
| Parcial | Pagamento parcial registrado | Azul |
| Pago | Totalmente pago | Verde |

### Cálculo do Status

O status é calculado em memória baseado nos valores:

```dart
if (paidAmount >= total) {
  status = 'paid';      // Pago
} else if (paidAmount > 0) {
  status = 'partial';   // Parcial (calculado em memória)
} else {
  status = 'unpaid';    // A Receber
}
```

**Importante:** No banco de dados (Firestore), apenas `paid` e `unpaid` são salvos. O status `partial` é calculado em memória para manter compatibilidade com índices e filtros existentes.

---

## Fluxo de Pagamentos

### Acessando a Gestão de Pagamentos

1. Abra uma Ordem de Serviço
2. Na seção **RESUMO**, clique em:
   - **Total** - abre a tela de pagamentos
   - **Pagamento** (status) - abre a tela de pagamentos

### Tela de Gestão de Pagamentos

A tela unificada permite:

#### Resumo Financeiro
- Total da OS
- Descontos aplicados
- Valor já pago
- Saldo restante

#### Registrar Pagamento ("Receber")
- Campo de valor pré-preenchido com o que falta receber (não passa disso)
- **Quando**: dia em que o dinheiro entrou, "Hoje" por padrão; abre um seletor de data
  sem datas futuras. Grava `paidAt` na transação (hoje = agora; outro dia = meio-dia do dia)
- "Anexar comprovante" (câmera, galeria ou arquivo), se tiver `attachPhotos`
- Botão azul "Confirmar recebimento" (o valor fica só no campo). Sem forma de pagamento (Pix/dinheiro/cartão)
- Desconto e "Desfazer" ficam no menu "…"

#### Histórico de Transações
- Lista de todas as transações (pagamentos e descontos)
- Ordenadas pelo dia do pagamento (`paidAt ?? createdAt`), mais recente primeiro
- A linha mostra o dia escolhido quando ele difere do dia do registro

### Receber de um cliente (várias OS)

Tela `ReceiveCustomerScreen` (`lib/screens/payments/receive_customer_screen.dart`), empurrada:

- Título "Receber de João" (quebra linha, sem reticências) e a frase "3 OS em aberto. Marque as
  OS que foram pagas." (com 1 OS só "1 OS em aberto.").
- **Formulário em cartões brancos** (`CupertinoListSection.insetGrouped`):
  - "Quanto recebeu": campo padrão (sem borda azul nem lápis), com ⓧ para limpar, teclado numérico
    com vírgula e uma barra "OK" em cima do teclado. Não abre o teclado sozinho. Começa com a soma
    das OS marcadas e é o **único lugar** onde o valor aparece. Rodapé: "Se recebeu só uma parte,
    digite quanto." ou o motivo do botão desligado ("Digite quanto recebeu.", "Passa do que falta
    nessas OS (R$ X).", "Marque pelo menos uma OS.").
  - "Quando › Hoje" (como acima) e "Comprovante › Anexar" (depois, o nome do arquivo com ⓧ para
    tirar), linhas normais do formulário.
- Botão azul "Confirmar recebimento" (58 de altura, o único azul da tela). Sucesso: aviso
  (`showAppToast`) e volta; o Financeiro recarrega.
- **Está pagando**: uma linha por OS em aberto, mais antiga primeiro. Tocar na linha marca ou
  desmarca (✓ no círculo, padrão de seleção do iPhone; com 1 OS não há o que marcar). A linha mostra
  "OS 15 · Fiat Uno" (veículo/aparelho, ou o primeiro serviço, como no recibo em PDF), quanto falta à
  direita e, embaixo, o que este pagamento faz nela: "Quita", "Recebe R$ 300 · fica R$ 199,99" ou
  "Fica para depois". O ⓘ (44 pt) abre a OS (`/order`); ao voltar, o valor digitado fica e a OS é
  lida de novo. Rodapé: "Se o valor não der para tudo, as mais antigas são pagas primeiro."
- Enquanto a pessoa não digita, o valor segue a soma das OS marcadas; depois de digitar, marcar e
  desmarcar não muda o valor. O máximo é o que falta nas marcadas.
- O valor vai **primeiro para as OS mais antigas** entre as marcadas (`allocatePayment` em
  `lib/utils/payment_allocation.dart`, centavos inteiros, cada OS limitada ao que falta nela).

**Entradas:**
- Aba Financeiro: na lista de A receber, cliente com 2+ OS em aberto.
  Com 1 OS vai direto ao Receber da OS. OS sem cliente continuam no "Qual OS?".
- Tela do cliente: link "Receber" ao lado de "Falta receber R$ X" (mesma regra do Receber,
  `AuthorizationService.canReceiveOnOrder`: aparece se a pessoa pode receber em pelo menos uma
  OS em aberto do cliente; o consultor só leva as OS que ele criou). Com 1 OS abre o Receber dela.

**Dados** (`CustomerReceiptService` → `buildReceiptPlan` → `TenantReceiptRepository.save`):
- Documento `companies/{companyId}/receipts/{receiptId}` (`Receipt`): `customer` (aggr), `amount`,
  `paidAt`, `allocations` [{`orderId`, `orderNumber`, `amount`, `transactionId`}],
  `receiptFile` ({`url`, `storagePath`, `fileName`, `contentType`}, opcional), `status`
  (`active`; desfazer grava `canceled`, nunca apagado), auditoria (`createdAt`, `createdBy`, ...).
- Cada OS recebe uma transação `payment` normal com a sua parte, `paidAt` e
  `receiptGroupId` = id do recebimento. `paidAmount` sobe por `increment` e `paid`/`payment`
  viram `paid` na OS que fica quitada (mesma conta de `OrderPaymentMath.addPaymentUpdate`).
- Recebimento + todas as OS num único **WriteBatch** (tudo ou nada, funciona offline; a tela
  não espera o servidor).
- **Antes de gravar**, a tela lê as OS marcadas no servidor (`CustomerReceiptService.readFromServer`,
  8 s). As OS vêm de uma leitura do Financeiro e o batch só soma (`increment`): se uma OS foi paga
  depois (link do Asaas pago, outra pessoa recebeu), ela seria paga de novo. Se o que falta em
  alguma mudou, nada é gravado, a tela mostra os valores novos e avisa "Os valores mudaram desde
  que a tela abriu. Confira e confirme de novo.". Sem internet a leitura falha e o recebimento
  segue como antes (offline).
- Comprovante: enviado **uma vez** para `tenants/{companyId}/receipts/{receiptId}/{arquivo}`
  (precisa de internet; se falhar, nada é gravado). Cada OS ganha um `OrderDocument` do tipo
  `receipt` apontando para o mesmo arquivo, com `linkedTransactionId` = transação dela, e a
  transação guarda `receiptDocumentId`. Assim o "ver comprovante" da OS continua igual.

### Mandar cobrança de várias OS (Asaas)

Em "Receber de João", com a conta Asaas conectada (piloto) e permissão `chargeOrder`, o "…" do
topo tem "Mandar link para pagar…", que abre `CreateCustomerChargeScreen`
(`lib/screens/payments/create_customer_charge_screen.dart`, sheet grande): valor (até o que falta
nas OS marcadas, mais antiga primeiro), vencimento e CPF/CNPJ se faltar. O servidor cria **um**
link do Asaas para as OS (`POST /v1/app/customers/{id}/charges`) e o app abre o compartilhar.

- A cobrança aberta aparece na tela ("Link aberto de R$ X", "OS 182, 190 · vence 18/10"), lida de
  `companies/{cid}/customerCharges` (`CustomerChargeRepository.watchOpen`, um filtro só), como uma
  linha acima do valor. Com link aberto, o "…" troca "Mandar link para pagar…" por mandar o link de
  novo, copiar e cancelar (vermelho, com confirmação).
- Criar o link cancela os links abertos de uma OS só dessas OS e o link anterior de várias OS do
  cliente. Enquanto a OS está nesse link, "Mandar cobrança" da OS sozinha explica que é preciso
  cancelar o de várias OS primeiro.
- Pago no Asaas: cada OS ganha a sua parte (`asaas_{pagamento}_{n}`, travada como qualquer
  pagamento Asaas) e é criado um recebimento (`receipts/asaas_{pagamento}`), então a tela
  "Recebimento" e o recibo funcionam como num recebimento manual.
- **Recebido por fora com o link aberto:** se o que entrou quita o link, o servidor dá baixa no
  Asaas (recebido em dinheiro, sem avisar o cliente); se é só uma parte, o link passa a cobrar o
  que falta. Roda no servidor quando a OS muda, então vale também para recebimento offline. Ver
  `docs/ASAAS_INTEGRATION.md`.

### Receber em OS de outra pessoa (consultor)

O consultor só grava nas OS que ele criou (regras do Firestore). Em "Receber de João" ele vê as
OS dele primeiro e uma seção "Outras OS de {nome}" (só número, quanto falta e data, vindas de
`GET /v1/app/customers/{id}/open-orders`), desmarcadas e sem ⓘ (não abrem); ele inclui marcando a
linha.

- Sem OS de outra pessoa marcada: caminho normal do app (WriteBatch, funciona offline).
- Com alguma OS de outra pessoa: o recebimento vai pelo servidor
  (`POST /v1/app/customers/{id}/receipts`, `CustomerReceiptService` → `AsaasApiService`). Precisa
  de internet; se falhar, aviso (`showAppToast`) e o que foi digitado fica na tela.
- O servidor confere papel (owner/admin/manager/consultor, com "Valores e cobrança" ligado),
  mesma empresa, mesmo cliente, OS que não é orçamento nem cancelada e valor até o que falta em
  cada OS. Grava numa transação só os campos de pagamento de cada OS (mesmas transações do app,
  `{receiptId}_{n}` com `receiptGroupId`) e o recebimento, com `createdBy` = consultor (ele
  consegue abrir e desfazer como os dele).
- Quem tem acesso ao financeiro continua no caminho offline do app.

### Recebimento (ver, mandar recibo, desfazer)

Tela `ReceiptDetailScreen` (`lib/screens/payments/receipt_detail_screen.dart`), empurrada e só
para quem vê o financeiro (`viewFinancialReports`, via `ProtectedRoute`):

- Título grande = valor ("R$ 700,00"); embaixo "João Silva · 14/10/2026".
- Uma linha por OS com a situação **atual** dela: "OS 185 · R$ 400 · quitada" ou
  "OS 184 · R$ 100 · falta R$ 200". Tocar abre a OS.
- "Ver comprovante" quando o recebimento tem arquivo (imagem no visualizador, PDF fora).
- Um botão azul: **"Mandar recibo para João"** (PDF do recibo, ver `docs/PDF_GENERATION.md`).
- Menu "…" com **"Desfazer recebimento"** (vermelho) → `CupertinoAlertDialog` de confirmação.
- Recebimento já desfeito: "Este recebimento foi desfeito.", sem botão nem menu.
- Quem abre: quem recebe (`AuthorizationService.canReceivePayments`). Botão e "Desfazer" só
  para quem pode mexer nesse recebimento (`canManageReceipt`): acesso ao financeiro, ou o
  consultor que o registrou (as regras só deixam o consultor ler os recebimentos dele).

**Entradas:**
- Receber da OS: tocar num pagamento com `receiptGroupId` abre o Recebimento (em vez da folha
  do pagamento).
- Tela do cliente: seção "Recebimentos" (só com acesso ao financeiro e se houver algum ativo),
  uma linha por recebimento ("R$ 700,00" / "14/10/2026 · 2 OS").
  `TenantReceiptRepository.watchActiveOfCustomer` filtra por `customer.id` (um filtro de
  igualdade, sem índice composto) e ordena/filtra `active` no app.

**Desfazer** (`CustomerReceiptService.undo` → `buildReceiptUndo` em
`lib/utils/receipt_undo.dart` → `TenantReceiptRepository.cancel`):
- Um único **WriteBatch**: o recebimento vira `status: 'canceled'` (com `updatedAt`/`updatedBy`)
  e cada OS perde a transação dele, com a mesma conta de remover um pagamento à mão
  (`OrderPaymentMath.removeTransaction`): `paidAmount` desce e `paid`/`payment` são recalculados.
  O `OrderDocument` do comprovante sai da OS, mas **o arquivo fica no Storage** (é do
  recebimento). As OS são lidas na hora (servidor, ou cache offline); OS que já não têm a
  transação ficam de fora.
- Não há desfazer parcial: na OS, remover um pagamento que é parte de um recebimento (ou
  "Desfazer pagamentos" com uma parte dessas) mostra "Este pagamento faz parte de um
  recebimento de várias OS…" e oferece "Abrir recebimento".

### Recibo para o cliente

- No Recebimento: "Mandar recibo para {nome}" (todas as OS do recebimento).
- No Receber da OS: tocar num pagamento manual → "Mandar recibo" (só esse pagamento, uma OS,
  sem documento `Receipt`). Quem recebe nessa OS (`canReceiveOnOrder`; o consultor, nas dele).
  Pagamentos do Asaas não têm: continuam
  com o "Ver comprovante" do próprio Asaas.
- O PDF é gerado no idioma do app e aberto na folha de compartilhar do sistema (WhatsApp,
  e-mail, imprimir). Detalhes em `docs/PDF_GENERATION.md`.

---

## Regras de Negócio

### Pagamentos por Status da OS

| Status da OS | Pode Registrar Pagamento? |
|--------------|---------------------------|
| Orçamento | Não |
| Aprovado | Sim |
| Em Andamento | Sim |
| Concluído | Sim |
| Cancelado | Não |

**Regra:** Pagamentos só são permitidos a partir do status **Aprovado**. Orçamentos e OS canceladas não aceitam pagamentos.

### Validações

1. **Valor mínimo:** O valor deve ser maior que zero
2. **Valor máximo:** O pagamento/desconto não pode exceder o saldo restante
3. **Status permitido:** Apenas OS aprovadas ou em execução

### Transações

Cada transação registra:
- `id` - Identificador único
- `type` - Tipo (`payment` ou `discount`)
- `amount` - Valor (sempre positivo)
- `description` - Observação opcional
- `createdAt` - Data/hora do registro
- `createdBy` - Usuário que registrou
- `paidAt` - Dia em que o dinheiro entrou (opcional; transações antigas não têm). Onde a data do
  pagamento aparece ou é somada por período, vale `paidAt ?? createdAt` (`PaymentTransaction.paidOn`)
- `receiptGroupId` - Id do recebimento de cliente (`receipts`) de que este pagamento é parte (opcional)
- `receiptDocumentId` - Id do comprovante (`OrderDocument`) ligado a este pagamento (opcional)

---

## Aba Financeiro

Aba fixa na barra inferior (requer `viewFinancialReports`). Separa o que muda com o mês do que é de
hoje e mostra só 5 valores; o detalhe fica nas telas seguintes.

**Muda com o mês** (`PeriodStepper`; o mês seguinte fica desabilitado no mês atual). Dois blocos lado
a lado, só rótulo, valor e chevron; com letra grande de acessibilidade, um embaixo do outro. Ao trocar
o mês só esses dois recarregam (`monthLoading` mostra o indicador no lugar do valor); o resto da tela
fica como está.

- **Recebido**: todo pagamento na data em que entrou (`paidAt ?? createdAt`), inclusive entrada e
  parcela, com a OS concluída ou não, em OS de qualquer mês (`getOrdersPaidSince`, pelo campo
  `lastPaymentAt` que o gatilho da OS mantém). OS antigas sem transações contam no mês em que foram
  criadas. Abre a lista das OS com dinheiro no mês, pagamento mais recente primeiro, cada linha com o
  que entrou nela naquele mês; a soma das linhas é o Recebido. Tocar abre a OS.
- **Vendido**: soma de `total` das OS abertas no mês (`createdAt`), sem orçamento e sem cancelada
  (`FinancialSummary.isSold`, a mesma regra do Relatório). Abre a lista das OS do mês, mais nova
  primeiro; tocar abre a OS.

**Hoje** (lista agrupada, não muda com o mês):

- **A receber**: saldo (`total - paidAmount`) das OS com `status == 'done'`, `payment != 'paid'` e
  saldo > 0 (`FinancialSummary.isReceivable`), sem limite de antiguidade. Abre a lista por cliente,
  mais antigo primeiro: título "A receber", subtítulo "{valor} de {n} clientes", linhas com cliente,
  valor e "desde {data}" (abertura da OS concluída mais antiga). OS sem cliente entram juntas como
  "Cliente sem nome".
- **Em andamento**: saldo das OS `approved` ou `progress` (`FinancialSummary.isInProgress`). Abre a
  lista das OS, mais antiga primeiro; tocar abre a OS. Quando a OS é concluída, o saldo passa para A
  receber.

**Receber não é filtrado:** o filtro por concluída vale só para o que aparece. `FinancialSummary.isOpen`
e `openOrdersOldestFirst` continuam cobrindo toda OS ativa com saldo. Tocar num cliente de A receber
vai por `Debtor.openOrders` (todas as OS em aberto dele, concluídas ou não): com uma OS abre o
**Receber** dela; com várias abre **Receber de {cliente}** (ver acima), que começa só com as OS de A
receber marcadas (`checkedOrderIds`), então abre com o valor da linha; as outras ficam na lista,
desmarcadas. OS sem cliente continuam abrindo a escolha "Qual OS?".

**Próxima cobrança** (`lib/utils/next_charge.dart`): uma linha com cliente e valor. Tocar abre uma
folha de ações com "{nome} deve {valor} desde {data}", **Mandar cobrança**, **Agora não** e Cancelar.
Sem candidato, a seção some.

**Notas fiscais** (`NfseMonthRow`): última linha da aba, só com a nota fiscal ligada (`docs/NFSE_ASAAS.md`). Mostra a quantidade emitida no mês do seletor, nunca dinheiro: a nota só leva serviços, então o total não bate com o Vendido.

- Candidatos: clientes de A receber sem "Agora não" nos últimos 30 dias e sem link em aberto. O link é
  lido nas OS em aberto do cliente (`orders/{id}/charges`) e em `customerCharges`, um cliente por vez,
  só até achar o primeiro livre (`OrderChargeRepository.hasOpen`, `CustomerChargeRepository.hasOpen`).
  Se a leitura falhar a seção some: sugerir poderia duplicar uma cobrança.
- Ordem: primeiro quem tem "desde" nos últimos 90 dias, da dívida mais antiga para a mais nova; só
  depois as com mais de 90 dias, da mais nova para a mais antiga.
- **Mandar cobrança**: usa o `SendChargeFlow` (com Asaas gera a cobrança e compartilha o link; sem
  Asaas compartilha o link da OS). Cliente com mais de uma OS concluída escolhe antes em "Qual OS?".
- **Agora não**: pausa o cliente por 30 dias e passa para o próximo. Fica em `SharedPreferences`, por
  empresa e cliente (`NextChargeSnoozes`), só no aparelho, nada no banco. Nunca tira o cliente de A
  receber.

Outros pontos:

- A consulta (`getUnpaidOrders`) traz `payment` `unpaid`, `partial` ou `null`: OS aprovada pelo link
  ou pela API grava só o status e pode ficar com `null`. OS sem o campo `payment` ficam de fora; o
  script `firebase/functions/scripts/backfill-order-payment-status.ts` corrige esses dados e preenche
  `lastPaymentAt` nas OS antigas (simula por padrão; `--apply` grava).
- Mês sem OS continua mostrando a tela inteira, com os valores zerados. Erro: mensagem fixa +
  "Tentar novamente".
- "…" abre o Relatório, no mês escolhido na aba, e "Outro período" (seletor de datas).

**Um nome, uma conta.** "Recebido" e "A receber" só aparecem com o sentido acima. O Relatório divide
o Vendido das OS criadas no período, então usa outros nomes: **Já pago** e **Falta pagar** (as duas
partes somam o Vendido, salvo OS paga a mais): Recebido é o dinheiro que entrou no mês, de qualquer OS,
e Já pago é o que foi pago das OS abertas no mês. Na OS e na tela do cliente, "Falta receber" é o
saldo daquela OS ou de todas as OS em aberto do cliente.

Arquivos: `lib/screens/dashboard/financial_tab.dart`, `lib/screens/dashboard/financial_list_screen.dart`
(as quatro listas), `lib/mobx/financial_tab_store.dart`, `lib/utils/financial_summary.dart` e
`lib/utils/next_charge.dart` (contas puras), `lib/screens/widgets/period_stepper.dart`,
`lib/screens/payments/receive_customer_screen.dart`.

### Data de conclusão da OS (`completedAt`)

Quando a OS passou a `done`, em ISO UTC. Ainda não aparece na tela nem muda nenhuma regra.

- **Só o servidor grava** (`firebase/functions/src/services/order-completion.service.ts`), nos gatilhos
  `onOrderUpdatedAsaas` (mudança de status, para toda empresa) e `firestoreUpdateTenantOSNumber` (OS
  criada já concluída). Assim vale para qualquer caminho: tela da OS, API, bot, MCP.
- Reabrir (sair de `done`, inclusive cancelar) apaga o campo; concluir de novo grava a nova data.
- O app lê, mas nunca envia: `Order.completedAt` tem `includeToJson: false`, então um save completo
  com uma cópia velha não sobrescreve. Versões instaladas não conhecem o campo e salvam com
  `set(merge)` só o que conhecem, o que o preserva.
- Eventos de gatilho podem repetir ou chegar fora de ordem: cada gravação confere numa transação o
  status atual da OS, e a data é a hora do evento.
- OS concluídas antes do campo ficam sem data: não há backfill.

## Relatório Financeiro

Tela aberta pela aba (`lib/screens/dashboard/financial_report_screen.dart`, rota `/financial_report`).
Mantém tudo o que o antigo painel tinha: períodos (hoje, semana, mês, ano, outro), faturamento, composição,
ranking de clientes, serviços e produtos, OS do período e PDF para compartilhar.

Considera as OS criadas no período, **sem orçamentos e sem canceladas** (`FinancialSummary.isSold`):
vale para todos os totais, rankings, lista de OS e PDF, e o Faturamento do mês bate com o Vendido da aba.
Dinheiro recebido em OS depois cancelada sai do "Já pago" do Relatório, mas continua no Recebido
da aba, que conta todo pagamento pela data em que entrou.

### Acesso
Aba Financeiro > Relatório Financeiro (requer permissão `viewFinancialReports`)

### Indicadores

| Indicador | Descrição |
|-----------|-----------|
| Vendido | Soma dos totais das OS filtradas (igual ao Vendido da aba no mesmo mês) |
| Já pago | Soma de todos os `paidAmount` das OS filtradas |
| Falta pagar | Soma de `(total - paidAmount)` das OS não pagas, concluídas ou não |
| OS Pagas | Quantidade de OS com status `paid` |

### Cálculo Considerando Pagamentos Parciais

```dart
// Já pago (considera pagamentos parciais)
totalPaidAmount = orders.fold(0.0, (sum, order) {
  if (order.payment == 'paid') {
    return sum + (order.paidAmount ?? order.total ?? 0.0);
  }
  return sum + (order.paidAmount ?? 0.0);
});

// Falta pagar (considera saldo restante)
totalUnpaidAmount = orders
  .where((order) => order.payment != 'paid')
  .fold(0.0, (sum, order) {
    final total = order.total ?? 0.0;
    final paid = order.paidAmount ?? 0.0;
    return sum + (total - paid);
  });
```

### Ranking de Clientes

Mostra os clientes ordenados por:
- Total de OS (valor)
- Valor a receber (considerando pagamentos parciais)

---

## Impressão (PDF)

### Resumo de Totais

O PDF exibe:
- Serviços (se houver)
- Produtos (se houver)
- Subtotal
- Desconto (se houver)
- **Total**
- **Já pago** (se houver pagamento parcial)

### Footer do Resumo

| Situação | Label | Cor |
|----------|-------|-----|
| Totalmente pago | TOTAL PAGO | Verde |
| Pagamento parcial | SALDO RESTANTE | Laranja |
| Sem pagamento | TOTAL A PAGAR | Azul escuro |

---

## Permissões (RBAC)

### Quem pode visualizar dados financeiros?

| Perfil | Ver Preços | Ver Dashboard | Registrar Pagamentos |
|--------|------------|---------------|----------------------|
| Dono | Sim | Sim | Sim |
| Admin | Sim | Sim | Sim |
| Gerente | Sim | Sim | Sim |
| Supervisor | Não | Não | Não |
| Consultor | Sim* | Não | Sim** |
| Técnico | Não | Não | Não |

*Consultor vê preços apenas das próprias OS
**Só nas OS que ele criou (`createdBy`), sem dar desconto

Quem recebe é decidido num lugar só: `AuthorizationService.canReceiveOnOrder(order)`
(lógica pura em `canReceiveOnOrderFor`). Quem tem acesso ao financeiro (`viewFinancialReports`:
dono, admin e gerente) recebe em qualquer OS; o **consultor recebe só nas OS que ele criou**
(`order.createdBy.id`, a mesma posse do `viewOwnOrders` e da regra de update de `/orders`).
Supervisor e técnico nunca recebem. Sem "Valores e cobrança" ninguém recebe.

A regra libera o **Receber** da OS (botão azul "Receber R$ X", a frase "Falta receber" e a linha
"Falta receber" dos totais), a tela `/payment_management` (`PaymentManagementRoute`, acesso
negado se a pessoa não pode receber naquela OS) e o "Receber de {cliente}" (aba Financeiro e link
"· Receber" na tela do cliente; para o consultor a lista só traz as OS dele, e com uma só vai
direto ao Receber dela). Nas OS dos outros, o consultor vê os valores (`viewPrices`), mas o
"Falta receber" é só texto.

O **desconto** continua só com acesso ao financeiro (`viewFinancialReports`): some do menu "…"
da OS e do Receber para o consultor. Desconto mexe no valor combinado, que é decisão de gestão.

Na tela do cliente, para consultor e técnico, a consulta das OS do cliente também filtra
`createdBy.id` (`FirestoreCustomerDirectory.watchOrdersOf`): as regras só deixam esses perfis
ler as próprias OS, e uma consulta sem esse filtro é negada. São só filtros de igualdade, então
não precisa de índice composto; a ordem (mais nova primeiro) é feita no app.

A regra de `receipts` no `firestore.rules` (`canReceivePayments`: owner, admin, manager e
consultant) cria com `createdBy.id` = usuário; lê e atualiza (desfazer, anexar comprovante) quem
passa em `canViewFinancial` ou quem criou o recebimento; ninguém apaga. As regras não conferem,
no recebimento, se cada OS da repartição é do consultor: isso vale pela regra de update de
`/orders`, que vai no mesmo batch (OS de outro = batch inteiro negado).

### Campos Ocultos por Permissão

Quando o usuário não tem `viewPrices`:
- Total da OS: oculto
- Status de Pagamento: oculto
- Valores de serviços/produtos: ocultos
- Opção de gerar PDF: oculta
- Filtros A Receber/Pago: ocultos

---

## Modelo de Dados

### Order (campos financeiros)

```dart
class Order {
  double? total;           // Valor total da OS
  double? discount;        // Total de descontos
  double? paidAmount;      // Total já pago
  String? payment;         // Status: 'unpaid' | 'paid'
  List<PaymentTransaction>? transactions;
  DateTime? completedAt;   // Quando ficou `done` (só o servidor grava)
}
```

### PaymentTransaction

```dart
class PaymentTransaction {
  String? id;
  PaymentTransactionType type;  // payment | discount
  double amount;
  String? description;
  DateTime createdAt;
  UserAggr? createdBy;
}
```

### Estrutura no Firestore

```
/companies/{companyId}/orders/{orderId}
  ├── total: 500.00
  ├── discount: 50.00
  ├── paidAmount: 200.00
  ├── payment: "unpaid"
  └── transactions: [
        {
          id: "uuid",
          type: "payment",
          amount: 200.00,
          description: "Entrada",
          createdAt: Timestamp,
          createdBy: { id, name }
        },
        {
          id: "uuid",
          type: "discount",
          amount: 50.00,
          description: "Desconto fidelidade",
          createdAt: Timestamp,
          createdBy: { id, name }
        }
      ]
```

---

## Retrocompatibilidade

### OS Antigas (sem paidAmount)

Para OS criadas antes da implementação de pagamentos parciais:

| payment | paidAmount | Comportamento |
|---------|------------|---------------|
| `paid` | `null` | Considera `paidAmount = total` |
| `unpaid` | `null` | Considera `paidAmount = 0` |

Isso garante que:
- Dashboard calcula corretamente os totais
- PDF exibe corretamente o status
- Filtros funcionam normalmente

---

## Implementação Técnica

### Arquivos Principais

| Arquivo | Descrição |
|---------|-----------|
| `lib/screens/payment_management_screen.dart` | Tela unificada de pagamentos |
| `lib/models/payment_transaction.dart` | Modelo de transação |
| `lib/models/order.dart` | Campos financeiros da OS |
| `lib/mobx/order_store.dart` | Lógica de cálculo e ações |
| `lib/services/pdf/pdf_main_os_builder.dart` | Geração do PDF |
| `lib/screens/dashboard/financial_tab.dart` | Aba Financeiro |
| `lib/screens/dashboard/financial_list_screen.dart` | Listas de Recebido, Vendido, A receber e Em andamento |
| `lib/screens/dashboard/financial_report_screen.dart` | Relatório financeiro |

### Métodos do OrderStore

```dart
// Registrar pagamento (offline; retorna a transação ou null se não registrou)
Future<PaymentTransaction?> addPayment(double amount, {String? description})

// Registrar desconto (offline; reduz o total da OS)
Future<bool> addDiscountTransaction(double amount, {String? description})

// Marcar como totalmente pago (precisa de conexão)
Future<bool> markAsFullyPaid({String? description})

// Remover transação (precisa de conexão; transações asaas_* são bloqueadas)
Future<bool> removeTransaction(int index)

// Zerar pagamentos manuais (precisa de conexão; mantém os do Asaas)
Future<bool> resetAllPayments()

// Motivo da última falha (a UI escolhe a mensagem)
PaymentUpdateFailure? lastPaymentFailure // requiresConnection | asaasLocked | failed
```

---

### Persistência dos pagamentos (Outubro 2026)

- Salvar a OS (`createItem`/`updateItem` do `TenantOrderRepository`) **não envia** `transactions`, `paidAmount`, `paid` nem `payment` quando a OS já existe. Isso evita que o app sobrescreva pagamentos lançados pelo servidor (webhook do Asaas, API, bot).
- **Registrar pagamento e desconto funcionam offline.** `addPayment`/`addDiscountTransaction` montam o mapa com `OrderPaymentMath.addPaymentUpdate`/`addDiscountUpdate` e gravam com `applyPaymentFieldUpdate` (`transactions: arrayUnion`, `paidAmount: increment` ou `discount: increment` + `total: increment(-valor)`, mais `payment`/`paid` calculados do estado local). A tela atualiza na hora (otimista); o app não espera a confirmação do servidor, e uma falha posterior vai para o log (Crashlytics).
- **Remover, zerar, marcar como pago, comprovantes e mudança de status** usam `updatePayments(companyId, orderId, mutate, actor:)`, que lê a OS dentro de `runTransaction`, aplica as regras de `lib/utils/order_payment_math.dart` e grava só os campos de pagamento, `discount`, `total` e auditoria. Exigem conexão: offline o app mostra "Sem conexão. Tente de novo quando estiver online." (`paymentRequiresConnection`); outras falhas mostram `paymentUpdateFailed`. A classificação do erro fica em `lib/utils/payment_update_failure.dart`.
- Antes de uma transação, o store espera (até 10 s) a última gravação offline-safe ser confirmada. Se não for confirmada no prazo, a operação **não segue** e mostra `paymentRequiresConnection` (`waitForPendingPaymentWrite`).
- Ao atualizar o estado local com o resultado de uma transação, pagamentos/descontos lançados offline e ainda não confirmados são mantidos (`OrderPaymentMath.mergePendingTransactions`), para não sumirem da tela nem serem lançados de novo.
- A tela de pagamentos bloqueia Registrar/Zerar/Remover enquanto uma operação está em andamento (indicador no botão).
- `updatedBy` é sempre o usuário que fez a ação (`actor: Global.userAggr`), nunca o anterior.
- Saldo restante = `total - paidAmount` (o `total` já é líquido de desconto), no app e no servidor.
- Transações com id `asaas_*` são lançadas pelo servidor e não podem ser removidas no app (estornar no Asaas; mensagem `asaasTransactionCannotBeRemoved`). "Zerar" mantém essas transações.
- Mudança de status para orçamento/cancelada grava `{payment: null, paid: false}` com `applyPaymentFieldUpdate` (funciona offline; `OrderPaymentMath.orderStatusPaymentUpdate`). Voltar para um status ativo recalcula o `payment` via `updatePayments` (precisa de conexão).

---

## Changelog

### Janeiro 2026

#### Simplificação do Sistema de Pagamentos (09/01/2026)

**Mudanças:**
- Nova tela unificada `PaymentManagementScreen`
- Removidos campos redundantes da OS (Desconto, Já pago, Restante)
- Status `partial` calculado em memória
- Pagamentos bloqueados para orçamentos e OS canceladas
- PDF suporta pagamentos parciais
- Dashboard considera pagamentos parciais nos cálculos
- Retrocompatibilidade com OS antigas

**Arquivos criados:**
- `lib/screens/payment_management_screen.dart`

**Arquivos removidos:**
- `lib/screens/payment_form_screen.dart`
- `lib/screens/payment_history_screen.dart`

**Commits:**
- `e565caa` - refactor: simplify payment management with unified screen
- `fdbd75f` - feat: support partial payments in PDF and financial dashboard
