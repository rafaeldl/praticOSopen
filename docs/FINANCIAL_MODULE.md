# Modulo Financeiro Completo - PraticOS

## Visao Geral

O modulo financeiro expande o sistema atual (pagamentos vinculados a OS) para uma gestao financeira completa com:

- **Contas a Pagar** - despesas, boletos, custos fixos e variaveis
- **Contas a Receber** - recebiveis avulsos + automaticos via OS
- **Contas Bancarias** - saldo em banco, caixa, cartao, carteira digital
- **Extrato** - visao cronologica de todas as movimentacoes reais
- **Parcelas** - parcelamento com entries vinculadas para acoes em lote
- **Estornos** - reversao de pagamentos com trilha de auditoria
- **Indicadores** - lucro, fluxo de caixa projetado, margem, DRE simplificado, despesas por categoria
- **Comprovantes** - anexo de recibos, notas fiscais e comprovantes
- **Sincronizacao bidirecional com OS** - pagamento por qualquer tela

> **Nota:** O sistema atual de pagamentos na OS (`PaymentTransaction`) continua funcionando. O novo modulo se integra a ele via sincronizacao bidirecional. Ver `docs/FINANCEIRO.md` para documentacao do sistema atual.

---

## Conceito Central: Entries vs Payments

O modulo financeiro se baseia em dois conceitos fundamentais:

```
financialEntries  = PLANEJAMENTO (o que tenho a pagar/receber, com vencimento e status)
financialPayments = EXECUCAO / EXTRATO (o que realmente aconteceu, fluxo real de caixa)
```

### Fluxo Tipico

1. **Criar despesa** -> cria `FinancialEntry` (status: `pending`, direction: `payable`)
2. **Pagar despesa** -> cria `FinancialPayment` (type: `expense`) + atualiza entry (status: `paid`) + debita conta bancaria
3. **Extrato** -> mostra o `FinancialPayment` na timeline cronologica

> **IMPORTANTE:** Toda operacao que envolve multiplos documentos (entry + payment + account) DEVE usar `WriteBatch` ou `Transaction` do Firestore para garantir atomicidade. Ver secao [Integridade de Dados](#integridade-de-dados).

### Exemplos

| Acao do Usuario | Entry | Payment | Conta Bancaria |
|-----------------|-------|---------|----------------|
| Cadastra aluguel R$2.500 venc 10/04 | Cria entry (pending) | -- | -- |
| Paga aluguel via Pix da conta Banco | Atualiza entry (paid) | Cria payment (expense, -R$2.500) | Banco: -R$2.500 |
| Recebe pagamento OS #142 R$350 | Atualiza entry receivable (paid) | Cria payment (income, +R$350) | Caixa: +R$350 |
| Transfere R$1.000 Caixa -> Banco | -- | Cria 2 payments vinculados (transfer) | Caixa: -R$1.000, Banco: +R$1.000 |
| Estorna pagamento de aluguel | Reabre entry (pending) | Cria payment reverso (reversed) | Banco: +R$2.500 |

---

## Arquitetura

### Colecoes Firestore

Todas sob `/companies/{companyId}/`:

```
/companies/{companyId}/
  |-- financialAccounts/    <- Contas bancarias (banco, caixa, cartao...)
  |-- financialEntries/     <- Contas a pagar/receber (planejamento)
  |-- financialPayments/    <- Movimentacoes reais (extrato)
  +-- orders/               <- OS existentes (integracao bidirecional)
```

### Fluxo de Dados

```
                    +---------------------+
                    |  financialAccounts   |
                    |  (saldo em contas)   |
                    +----------+----------+
                               | debita/credita
                               | (WriteBatch atomico)
                               |
+--------------+    +----------v----------+    +--------------+
|  financial   |--->|  financialPayments  |<---|    orders     |
|  Entries     |    |  (extrato real)     |    |  (OS + Pay-   |
|  (planejado) |    +---------------------+    |  mentTrans.)  |
+--------------+         ^                     +--------------+
                         |                            ^
                         |    sync via syncSource      |
                         +----------------------------+
```

### Camadas

```
UI (Screens + Modals)
  |-- FinancialStatementScreen       <- Extrato (tela principal da tab)
  |-- FinancialEntryFormScreen       <- Form criar/editar despesa ou recebimento (push modal)
  |-- FinancialAccountListScreen     <- Lista de contas bancarias (push)
  |-- FinancialAccountFormScreen     <- Form criar/editar conta (push)
  |-- PaymentConfirmationSheet       <- Half-sheet para confirmar pagamento de entry
  +-- TransferSheet                  <- Half-sheet para transferencia entre contas

Widgets Reutilizaveis
  |-- InstallmentProgressCard        <- Card expansivel inline para parcelas
  |-- PaymentTimelineItem            <- Item compacto do extrato (2 linhas)
  |-- CategoryPickerGrid             <- Grid de categorias com icones
  +-- BalanceHeader                  <- Header com saldo + eye toggle

State (MobX Stores)
  |-- FinancialAccountStore          <- CRUD contas, totalBalance, reconciliacao
  |-- FinancialEntryStore            <- CRUD entries, parcelas, sync OS
  +-- FinancialPaymentStore          <- Stream extrato, KPIs, transferencias, estornos

Data (Repositories)
  |-- TenantFinancialAccountRepository  + FinancialAccountRepositoryV2
  |-- TenantFinancialEntryRepository    + FinancialEntryRepositoryV2
  +-- TenantFinancialPaymentRepository  + FinancialPaymentRepositoryV2

Models
  |-- FinancialAccount      + FinancialAccountAggr
  |-- FinancialEntry        + FinancialEntryAggr
  +-- FinancialPayment
```

> **Nota sobre arquitetura de telas:** O modulo usa **3 telas + 2 half-sheets + widgets expansiveis** em vez de 5+ telas separadas. Isso reduz navegacao e mantem o usuario no contexto. Half-sheets sao usados para acoes rapidas (pagar, transferir) que nao justificam uma tela inteira.

---

## Decisoes Tecnicas: Firestore (NoSQL)

O modulo financeiro roda inteiramente no Firestore, seguindo os mesmos padroes do resto do app (TenantRepository, client-side aggregation, WriteBatch). Esta secao documenta as decisoes tecnicas, limites conhecidos e estrategias de contorno.

### Por que Firestore (e nao SQL)

| Criterio | Firestore | PostgreSQL |
|----------|-----------|------------|
| JOINs / GROUP BY | Client-side | Nativo |
| Agregacoes (SUM, AVG) | Client-side | Nativo |
| Transacoes multi-doc | WriteBatch (500 ops) / Transaction | ACID completo |
| Hosting/Ops | Zero (Firebase managed) | Cloud SQL ~$30+/mes |
| Realtime streams | Nativo (snapshots) | Precisa de websockets |
| Offline-first (mobile) | Nativo | Complexo |
| Custo (volume do publico-alvo) | ~$0-5/mes | ~$30-100/mes |
| Migracao | N/A | Reescrever repositories + perder offline-first |

**Veredicto:** Para o publico-alvo (pequenos negocios, <500 transacoes/mes), o custo de migrar para SQL (reescrever camada de dados, perder offline-first, adicionar backend de API) e desproporcional ao ganho. Os workarounds de agregacao client-side funcionam bem nesse volume.

**Reconsiderar SQL se:** O PraticOS escalar para empresas com milhares de transacoes/mes ou precisar de relatorios contabeis certificados (balancetes, livro razao). Nesse cenario, um servico de relatorios separado com SQL seria mais adequado que migrar tudo.

### Volume estimado por empresa

| Periodo | Entries | Payments | Accounts |
|---------|---------|----------|----------|
| Mensal | 50-200 | 50-200 | 2-5 |
| Anual | 600-2.400 | 600-2.400 | 2-5 |
| 3 anos | 2.000-7.200 | 2.000-7.200 | 2-5 |

Carregar 200 docs para calcular KPIs de um mes = ~50-100KB de dados. Trivial para mobile.

### Indices Compostos Necessarios

Adicionar ao `firebase/firestore.indexes.json`:

```json
{
  "indexes": [
    // === financialPayments ===
    {
      "collectionGroup": "financialPayments",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "type", "order": "ASCENDING" },
        { "fieldPath": "paymentDate", "order": "DESCENDING" }
      ]
    },
    {
      "collectionGroup": "financialPayments",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "status", "order": "ASCENDING" },
        { "fieldPath": "paymentDate", "order": "DESCENDING" }
      ]
    },
    {
      "collectionGroup": "financialPayments",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "accountId", "order": "ASCENDING" },
        { "fieldPath": "paymentDate", "order": "DESCENDING" }
      ]
    },
    {
      "collectionGroup": "financialPayments",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "entryId", "order": "ASCENDING" },
        { "fieldPath": "paymentDate", "order": "DESCENDING" }
      ]
    },
    {
      "collectionGroup": "financialPayments",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "orderId", "order": "ASCENDING" },
        { "fieldPath": "paymentDate", "order": "DESCENDING" }
      ]
    },
    {
      "collectionGroup": "financialPayments",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "category", "order": "ASCENDING" },
        { "fieldPath": "paymentDate", "order": "DESCENDING" }
      ]
    },
    {
      "collectionGroup": "financialPayments",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "transferGroupId", "order": "ASCENDING" },
        { "fieldPath": "paymentDate", "order": "DESCENDING" }
      ]
    },

    // === financialEntries ===
    {
      "collectionGroup": "financialEntries",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "direction", "order": "ASCENDING" },
        { "fieldPath": "status", "order": "ASCENDING" },
        { "fieldPath": "dueDate", "order": "ASCENDING" }
      ]
    },
    {
      "collectionGroup": "financialEntries",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "direction", "order": "ASCENDING" },
        { "fieldPath": "dueDate", "order": "ASCENDING" }
      ]
    },
    {
      "collectionGroup": "financialEntries",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "installmentGroupId", "order": "ASCENDING" },
        { "fieldPath": "installmentNumber", "order": "ASCENDING" }
      ]
    },
    {
      "collectionGroup": "financialEntries",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "status", "order": "ASCENDING" },
        { "fieldPath": "dueDate", "order": "ASCENDING" }
      ]
    },
    {
      "collectionGroup": "financialEntries",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "direction", "order": "ASCENDING" },
        { "fieldPath": "createdAt", "order": "DESCENDING" }
      ]
    }
  ]
}
```

Total: ~12 novos indices. O projeto ja tem 34, entao e consistente com o padrao.

> **Nota:** Como as colecoes ficam sob `/companies/{companyId}/`, o filtro por empresa e implicito (subcollection). Os indices acima nao precisam de `company.id` como campo.

### Estrategia de Queries

**Regra geral:** Base query = date range + maximo 1 equality filter. Combinacoes mais complexas sao filtradas client-side apos o fetch.

```dart
// OK: periodo + tipo (1 equality + 1 range = indice composto simples)
query.where('type', isEqualTo: 'income')
     .orderBy('paymentDate', descending: true)
     .where('paymentDate', isGreaterThanOrEqualTo: startDate)
     .where('paymentDate', isLessThanOrEqualTo: endDate);

// OK: periodo + conta (1 equality + 1 range)
query.where('accountId', isEqualTo: accountId)
     .orderBy('paymentDate', descending: true)
     .where('paymentDate', isGreaterThanOrEqualTo: startDate)
     .where('paymentDate', isLessThanOrEqualTo: endDate);

// EVITAR no Firestore: periodo + tipo + conta + categoria (4 filtros)
// Em vez disso: carregar por periodo + tipo, filtrar client-side por conta/categoria
```

**Paginacao do extrato:**

```dart
// Cursor-based pagination (mesmo padrao do OrderRepositoryV2)
final query = paymentsCollection
    .orderBy('paymentDate', descending: true)
    .where('paymentDate', isGreaterThanOrEqualTo: startDate)
    .where('paymentDate', isLessThanOrEqualTo: endDate)
    .limit(20);

if (lastDocument != null) {
  query = query.startAfterDocument(lastDocument);
}
```

### Agregacoes Client-Side

Todas as agregacoes seguem o mesmo padrao do dashboard existente (`FinancialDashboardSimple`): carregar documentos do periodo e calcular em memoria.

```dart
// KPIs do extrato -- mesmo padrao do OrderStore.loadOrdersForDashboardCustomRange
Future<void> loadKPIs(DateTime start, DateTime end) async {
  final payments = await paymentRepo.getByDateRange(start, end);
  final active = payments.where((p) => p.status == FinancialPaymentStatus.completed);

  totalIncome = active
      .where((p) => p.type == FinancialPaymentType.income)
      .fold<double>(0, (sum, p) => sum + (p.amount ?? 0));

  totalExpense = active
      .where((p) => p.type == FinancialPaymentType.expense)
      .fold<double>(0, (sum, p) => sum + (p.amount ?? 0));

  profit = totalIncome - totalExpense;
  margin = totalIncome > 0 ? (profit / totalIncome) * 100 : 0;
}

// DRE por categoria -- agrupamento client-side
Map<String, double> expenseByCategory = {};
for (final p in activeExpenses) {
  expenseByCategory[p.category ?? 'other'] =
      (expenseByCategory[p.category ?? 'other'] ?? 0) + (p.amount ?? 0);
}
```

**Performance esperada:** ~200 docs/mes = ~50-100KB. Em dispositivos modernos, processar isso leva <100ms. Nao ha necessidade de server-side aggregation para esse volume.

### WriteBatch vs Transaction

| Operacao | Precisa ler antes? | Usar |
|----------|-------------------|------|
| Pagar entry | Nao (valores conhecidos) | `WriteBatch` |
| Transferencia | Nao (valores conhecidos) | `WriteBatch` |
| Estorno | Nao (dados do payment original disponiveis) | `WriteBatch` |
| Criar parcelamento | Nao (valores calculados) | `WriteBatch` |
| Recalcular paidAmount | Sim (query payments ativos) | `Transaction` |
| Reconciliar saldo | Sim (query todos payments) | Calcular fora, `WriteBatch` para corrigir |

**Regra pratica:**
- `WriteBatch` quando todos os valores sao conhecidos antes de escrever
- `Transaction` quando precisa ler o estado atual para decidir o que escrever
- Nunca misturar os dois (Transaction ja inclui capacidade de batch)

### Snapshots Mensais (estrategia de longo prazo)

Para evitar que reconciliacao e relatorios cross-periodo fiquem lentos com o crescimento dos dados, implementar snapshots mensais por conta.

**Colecao:**

```
/companies/{companyId}/financialAccounts/{accountId}/snapshots/{yearMonth}
{
  "yearMonth": "2026-03",
  "balance": 12500.00,
  "totalIncome": 8200.00,
  "totalExpense": 5300.00,
  "totalTransferIn": 1000.00,
  "totalTransferOut": 500.00,
  "paymentCount": 47,
  "calculatedAt": Timestamp
}
```

**Geracao:** Cloud Function disparada no primeiro dia de cada mes (ou sob demanda via botao "Fechar mes").

**Uso:**
- **Reconciliacao:** Carregar ultimo snapshot + payments do mes atual (em vez de todos os payments da conta)
- **Relatorios anuais:** Carregar 12 snapshots (em vez de ~2.400 payments)
- **Comparativo de periodos:** Snapshots tornam a comparacao trivial

**Quando implementar:** Fase 4, ou quando uma conta ultrapassar ~1.000 payments. Nao e necessario no MVP.

### Firestore Security Rules

Adicionar ao `firebase/firestore.rules`:

```javascript
// === Financial Module ===
match /companies/{companyId}/financialAccounts/{accountId} {
  allow read: if belongsToCompany(companyId)
    && hasAnyRole(companyId, ['admin', 'manager']);
  allow write: if belongsToCompany(companyId)
    && hasAnyRole(companyId, ['admin', 'manager']);

  // Snapshots mensais (subcollection)
  match /snapshots/{snapshotId} {
    allow read: if belongsToCompany(companyId)
      && hasAnyRole(companyId, ['admin', 'manager']);
    allow write: if false; // Apenas Cloud Functions
  }
}

match /companies/{companyId}/financialEntries/{entryId} {
  allow read: if belongsToCompany(companyId)
    && hasAnyRole(companyId, ['admin', 'manager']);
  allow create, update: if belongsToCompany(companyId)
    && hasAnyRole(companyId, ['admin', 'manager']);
  allow delete: if false; // Soft delete apenas
}

match /companies/{companyId}/financialPayments/{paymentId} {
  allow read: if belongsToCompany(companyId)
    && hasAnyRole(companyId, ['admin', 'manager']);
  allow create: if belongsToCompany(companyId)
    && hasAnyRole(companyId, ['admin', 'manager']);
  allow update: if belongsToCompany(companyId)
    && hasAnyRole(companyId, ['admin', 'manager']);
  allow delete: if false; // Soft delete apenas
}
```

> **Nota:** `viewFinancialStatement` (somente leitura) pode ser implementada com uma funcao adicional `canViewFinancial()` que verifica essa permission especifica, separada de `admin`/`manager`.

### Storage Paths

Adicionar ao `firebase/storage.rules`:

```javascript
// Financial attachments
match /tenants/{companyId}/financial/entries/{entryId}/attachments/{fileName} {
  allow read: if isAuthenticated() && isTenantMember(companyId);
  allow write: if isAuthenticated() && isTenantMember(companyId)
    && isValidImage() || isValidDocument();
}

match /tenants/{companyId}/financial/payments/{paymentId}/attachments/{fileName} {
  allow read: if isAuthenticated() && isTenantMember(companyId);
  allow write: if isAuthenticated() && isTenantMember(companyId)
    && isValidImage() || isValidDocument();
}
```

### Limites do Firestore a monitorar

| Limite | Valor | Impacto no modulo | Risco |
|--------|-------|-------------------|-------|
| Documento max | 1 MB | Entries/payments sao pequenos (~1-2KB) | Nenhum |
| WriteBatch max | 500 ops | Pior caso: parcelamento 12x = 12 ops | Nenhum |
| Transaction reads | 25 docs | Recalcular paidAmount le N payments | Baixo (monitorar) |
| Indices compostos max | 200 por database | +12 novos (total ~46) | Nenhum |
| Writes/segundo | 10.000 por database | Volume do publico-alvo e irrisorio | Nenhum |
| Subcollection depth | 100 niveis | Usamos 2 niveis (company > collection) | Nenhum |

---

## Integridade de Dados

### Operacoes Atomicas (WriteBatch)

Toda operacao que modifica multiplos documentos DEVE usar `WriteBatch` do Firestore. Isso garante que ou todas as operacoes completam com sucesso, ou nenhuma e aplicada.

**Operacoes que EXIGEM WriteBatch:**

| Operacao | Documentos envolvidos |
|----------|----------------------|
| Pagar entry | Entry (status/paidAmount) + Payment (criar) + Account (saldo) |
| Transferencia | 2 Payments (criar) + 2 Accounts (saldo) |
| Estorno | Payment original (status) + Payment reverso (criar) + Entry (paidAmount) + Account (saldo) |
| Excluir parcela paga | Entry (deletedAt) + Payment (status) + Account (saldo reverso) |

**Exemplo de implementacao:**

```dart
Future<void> payEntry(FinancialEntry entry, PaymentData data) async {
  final batch = FirebaseFirestore.instance.batch();

  // 1. Criar payment
  final paymentRef = paymentsCollection.doc();
  batch.set(paymentRef, payment.toJson());

  // 2. Atualizar entry
  batch.update(entryRef, {
    'status': 'paid',
    'paidAmount': FieldValue.increment(data.amount),
    'paidDate': data.paymentDate,
  });

  // 3. Atualizar saldo da conta
  batch.update(accountRef, {
    'currentBalance': FieldValue.increment(
      entry.direction == 'payable' ? -data.amount : data.amount,
    ),
  });

  // Atomico: tudo ou nada
  await batch.commit();
}
```

### Reconciliacao de Saldo

O `currentBalance` denormalizado pode divergir do saldo real por falhas de rede, bugs ou operacoes parciais. O sistema implementa reconciliacao para detectar e corrigir drift.

**Mecanismo:**

1. **Calculo sob demanda:** Ao abrir a tela de contas bancarias, recalcular o saldo somando `initialBalance` + todos os payments da conta
2. **Comparacao:** Se `calculatedBalance != currentBalance`, exibir alerta para o admin
3. **Correcao:** Acao manual "Reconciliar saldo" que corrige `currentBalance` com o valor calculado
4. **Log:** Registrar reconciliacoes em `updatedAt` / `updatedBy` da conta

```dart
Future<double> calculateRealBalance(String accountId) async {
  final account = await accountRepo.get(accountId);
  final payments = await paymentRepo.queryByAccount(accountId);

  double balance = account.initialBalance ?? 0;
  for (final p in payments) {
    if (p.status == FinancialPaymentStatus.reversed) continue;
    if (p.type == FinancialPaymentType.income) balance += p.amount ?? 0;
    if (p.type == FinancialPaymentType.expense) balance -= p.amount ?? 0;
    if (p.type == FinancialPaymentType.transfer) {
      if (p.accountId == accountId) balance -= p.amount ?? 0;
      if (p.targetAccountId == accountId) balance += p.amount ?? 0;
    }
  }
  return balance;
}
```

### Soft Delete

Entries e payments usam soft delete para manter trilha de auditoria:

```dart
DateTime? deletedAt;    // Null = ativo, Timestamp = excluido
UserAggr? deletedBy;    // Quem excluiu
```

**Regras:**
- Queries de listagem filtram `deletedAt == null` por padrao
- Payments excluidos nao contam no calculo de saldo/KPIs
- Admin pode visualizar itens excluidos via filtro especial
- Exclusao fisica so ocorre em cleanup periodico (90+ dias)

---

## Modelos de Dados

### FinancialAccount

Representa uma conta bancaria, caixa, cartao ou carteira digital.

```dart
class FinancialAccount extends BaseAuditCompany {
  String? name;                    // "Conta Corrente Itau"
  FinancialAccountType? type;      // bank, cash, creditCard, digitalWallet
  double? initialBalance;          // Saldo inicial ao cadastrar
  double? currentBalance;          // Saldo atual (denormalizado, atualizado atomicamente)
  String? currency;                // "BRL" (ISO 4217)
  String? color;                   // "#1E88E5" (hex para UI)
  String? icon;                    // "bank" (chave de icone)
  bool? active;                    // Conta ativa/inativa
  bool? isDefault;                 // Conta padrao para operacoes
  DateTime? lastReconciledAt;      // Ultima reconciliacao de saldo
}

class FinancialAccountAggr {
  String? id;
  String? name;
  FinancialAccountType? type;
}
```

**Enum `FinancialAccountType`:**

| Valor | Descricao | Icone sugerido | Cor sugerida |
|-------|-----------|----------------|--------------|
| `bank` | Conta bancaria | bank | Azul |
| `cash` | Dinheiro/Caixa | cash | Verde |
| `creditCard` | Cartao de credito | creditCard | Laranja |
| `digitalWallet` | Carteira digital (Pix, PicPay...) | digitalWallet | Roxo |

**Saldo:**
- `currentBalance` e denormalizado e atualizado via `FieldValue.increment()` dentro de `WriteBatch` para garantir atomicidade
- Ao criar payment de saida: `FieldValue.increment(-amount)`
- Ao criar payment de entrada: `FieldValue.increment(amount)`
- Reconciliacao periodica compara `currentBalance` com soma real dos payments (ver [Reconciliacao de Saldo](#reconciliacao-de-saldo))

#### Estrutura no Firestore

```
/companies/{companyId}/financialAccounts/{accountId}
{
  "name": "Conta Corrente Itau",
  "type": "bank",
  "initialBalance": 5000.00,
  "currentBalance": 12500.00,
  "currency": "BRL",
  "color": "#1E88E5",
  "icon": "bank",
  "active": true,
  "isDefault": true,
  "lastReconciledAt": null,
  "company": { "id": "...", "name": "..." },
  "createdAt": Timestamp,
  "createdBy": { "id": "...", "name": "..." },
  "updatedAt": Timestamp,
  "updatedBy": { "id": "...", "name": "..." }
}
```

---

### FinancialEntry

Representa uma conta a pagar ou a receber (planejamento financeiro).

```dart
class FinancialEntry extends BaseAuditCompany {
  // Classificacao
  FinancialEntryDirection? direction;  // payable | receivable
  FinancialEntryStatus? status;        // pending | paid | overdue | cancelled

  // Valores
  String? description;                 // "Aluguel escritorio marco"
  double? amount;                      // Valor total
  double? paidAmount;                  // Quanto ja foi pago (parcial) - recalculado via payments
  DateTime? dueDate;                   // Data de vencimento
  DateTime? paidDate;                  // Data do pagamento efetivo

  // Categorizacao
  String? category;                    // Chave da categoria (predefinida ou custom)
  List<String>? tags;                  // Tags livres para filtros

  // Conta bancaria destino
  String? accountId;                   // ID da conta (para debito/credito)
  FinancialAccountAggr? account;       // Aggr denormalizado

  // Contraparte
  CustomerAggr? customer;              // Para receivables (cliente)
  String? supplier;                    // Para payables (fornecedor, texto livre)

  // Vinculo com OS
  String? orderId;                     // Se gerado automaticamente a partir de OS
  int? orderNumber;                    // Numero da OS (denormalizado para display)

  // Observacoes e anexos
  String? notes;                       // Notas internas
  List<String>? attachments;           // URLs de comprovantes no Storage

  // Recorrencia
  FinancialRecurrence? recurrence;     // Null = lancamento unico

  // Parcelas
  String? installmentGroupId;          // Agrupa parcelas do mesmo parcelamento
  int? installmentNumber;              // Ex: 3 (parcela 3 de 6). Null = nao e parcela
  int? installmentTotal;               // Ex: 6 (total de parcelas). Null = nao e parcela

  // Soft delete
  DateTime? deletedAt;
  UserAggr? deletedBy;

  // Computed
  double get remainingBalance => (amount ?? 0) - (paidAmount ?? 0);
  bool get isFullyPaid => remainingBalance <= 0;
  bool get isOverdue => status == FinancialEntryStatus.pending
      && dueDate != null
      && dueDate!.isBefore(DateTime.now());
  bool get isInstallment => installmentNumber != null && installmentTotal != null;
}

class FinancialEntryAggr {
  String? id;
  FinancialEntryDirection? direction;
  String? description;
  double? amount;
  DateTime? dueDate;
  FinancialEntryStatus? status;
}
```

**Enums:**

```dart
enum FinancialEntryDirection {
  @JsonValue('payable')   payable,    // Conta a pagar (despesa)
  @JsonValue('receivable') receivable, // Conta a receber (receita)
}

enum FinancialEntryStatus {
  @JsonValue('pending')   pending,    // Pendente
  @JsonValue('paid')      paid,       // Pago
  @JsonValue('overdue')   overdue,    // Vencido
  @JsonValue('cancelled') cancelled,  // Cancelado
}
```

**`paidAmount` - Recalculo via Payments:**

O `paidAmount` e um valor denormalizado para performance, mas a **fonte da verdade** sao os `FinancialPayment` vinculados (via `entryId`). Ao estornar ou excluir um payment, recalcular:

```dart
Future<void> recalculatePaidAmount(String entryId) async {
  final payments = await paymentRepo.queryByEntry(entryId);
  final activePaidAmount = payments
      .where((p) => p.status == FinancialPaymentStatus.completed)
      .fold<double>(0, (sum, p) => sum + (p.amount ?? 0));

  await entryRepo.update(entryId, {
    'paidAmount': activePaidAmount,
    'status': activePaidAmount >= entry.amount
        ? 'paid'
        : activePaidAmount > 0 ? 'pending' : 'pending',
    'paidDate': activePaidAmount >= entry.amount ? DateTime.now() : null,
  });
}
```

#### Estrutura no Firestore

```
/companies/{companyId}/financialEntries/{entryId}
{
  "direction": "payable",
  "status": "pending",
  "description": "Aluguel escritorio marco",
  "amount": 2500.00,
  "paidAmount": 0.00,
  "dueDate": "2026-04-10T00:00:00Z",
  "paidDate": null,
  "category": "rent",
  "accountId": "abc123",
  "account": { "id": "abc123", "name": "Conta Corrente", "type": "bank" },
  "customer": null,
  "supplier": "Imobiliaria XYZ",
  "orderId": null,
  "orderNumber": null,
  "notes": "Ref: contrato 2024",
  "attachments": [],
  "tags": ["fixed", "monthly"],
  "recurrence": null,
  "installmentGroupId": null,
  "installmentNumber": null,
  "installmentTotal": null,
  "deletedAt": null,
  "deletedBy": null,
  "company": { "id": "...", "name": "..." },
  "createdAt": Timestamp,
  "createdBy": { "id": "...", "name": "..." }
}
```

---

### FinancialPayment

Representa uma movimentacao real de dinheiro. E a base do extrato.

```dart
class FinancialPayment extends BaseAuditCompany {
  // Tipo da movimentacao
  FinancialPaymentType? type;          // income | expense | transfer

  // Status
  FinancialPaymentStatus? status;      // completed | reversed

  // Valores
  double? amount;                      // Valor (sempre positivo)
  DateTime? paymentDate;               // Data da movimentacao
  PaymentMethod? paymentMethod;        // pix, cash, creditCard, etc.
  String? description;                 // Descricao curta
  String? notes;                       // Observacoes

  // Comprovantes
  List<String>? attachments;           // URLs de comprovantes no Storage

  // Vinculo com entry
  String? entryId;                     // Ref a FinancialEntry que originou

  // Conta bancaria (origem)
  String? accountId;                   // Conta que movimentou
  FinancialAccountAggr? account;       // Aggr denormalizado

  // Transferencia (destino - apenas para type == transfer)
  String? targetAccountId;             // Conta destino
  FinancialAccountAggr? targetAccount; // Aggr denormalizado
  String? transferGroupId;             // Vincula os 2 payments de uma transferencia

  // Estorno
  String? reversedPaymentId;           // Se este payment e um estorno, ref ao payment original
  String? reversedByPaymentId;         // Se este payment foi estornado, ref ao payment de estorno
  DateTime? reversedAt;                // Quando foi estornado
  String? reversalReason;              // Motivo do estorno

  // Vinculo com OS
  String? orderId;                     // Se veio de pagamento de OS
  int? orderNumber;                    // Denormalizado para display

  // Contraparte
  CustomerAggr? customer;              // Cliente (se receivable/OS)
  String? supplier;                    // Fornecedor (se payable)

  // Categorizacao
  String? category;                    // Categoria da entry (denormalizado)

  // Soft delete
  DateTime? deletedAt;
  UserAggr? deletedBy;
}
```

**Enums:**

```dart
enum FinancialPaymentType {
  @JsonValue('income')   income,    // Entrada (recebimento)
  @JsonValue('expense')  expense,   // Saida (pagamento de despesa)
  @JsonValue('transfer') transfer,  // Transferencia entre contas
}

enum FinancialPaymentStatus {
  @JsonValue('completed') completed,  // Movimentacao efetivada
  @JsonValue('reversed')  reversed,   // Estornado (nao conta em saldos/KPIs)
}

// Reutiliza o PaymentMethod ja existente no sistema de OS
// Importar de lib/models/payment_method.dart
enum PaymentMethod {
  @JsonValue('pix')        pix,
  @JsonValue('cash')       cash,
  @JsonValue('creditCard') creditCard,
  @JsonValue('debitCard')  debitCard,
  @JsonValue('transfer')   transfer,
  @JsonValue('check')      check,
  @JsonValue('other')      other,
}
```

> **Nota:** Verificar se `PaymentMethod` ja existe no modelo atual de OS (`PaymentTransaction`). Se sim, reutilizar o mesmo enum para evitar divergencia. Caso contrario, criar compartilhado em `lib/models/payment_method.dart`.

#### Estrutura no Firestore

```
/companies/{companyId}/financialPayments/{paymentId}
{
  "type": "expense",
  "status": "completed",
  "amount": 2500.00,
  "paymentDate": "2026-03-27T14:30:00Z",
  "paymentMethod": "pix",
  "description": "Aluguel escritorio marco",
  "notes": null,
  "attachments": [],
  "entryId": "entry123",
  "accountId": "acc456",
  "account": { "id": "acc456", "name": "Conta Corrente", "type": "bank" },
  "targetAccountId": null,
  "targetAccount": null,
  "transferGroupId": null,
  "reversedPaymentId": null,
  "reversedByPaymentId": null,
  "reversedAt": null,
  "reversalReason": null,
  "orderId": null,
  "orderNumber": null,
  "customer": null,
  "supplier": "Imobiliaria XYZ",
  "category": "rent",
  "deletedAt": null,
  "deletedBy": null,
  "company": { "id": "...", "name": "..." },
  "createdAt": Timestamp,
  "createdBy": { "id": "...", "name": "..." }
}
```

---

### FinancialRecurrence

Sub-documento embutido em `FinancialEntry` para lancamentos recorrentes.

```dart
class FinancialRecurrence {
  String? frequency;           // daily | weekly | monthly | yearly
  int? interval;               // A cada N periodos (1 = todo mes, 2 = bimestral)
  DateTime? endDate;           // Null = sem fim
  DateTime? nextDueDate;       // Proxima data de geracao
  DateTime? lastGeneratedDate; // Ultima data gerada (previne duplicacao)
  bool? active;                // Ativa/pausada
}
```

**Prevencao de duplicacao:**

Antes de gerar uma nova entry recorrente, verificar:

```dart
// Verifica se ja existe entry com este dueDate para esta recorrencia
final existing = await entryRepo.query([
  QueryArgs('recurrence.nextDueDate', nextDueDate),
  QueryArgs('direction', entry.direction),
  QueryArgs('description', entry.description),
]);
if (existing.isNotEmpty) return; // Ja gerada, pular

// Apos gerar, atualizar lastGeneratedDate
await entryRepo.update(entryId, {
  'recurrence.lastGeneratedDate': nextDueDate,
  'recurrence.nextDueDate': calculateNextDueDate(nextDueDate, frequency, interval),
});
```

Segue o mesmo padrao do `OrderContract` ja existente no sistema.

---

### FinancialCategory

Categorias predefinidas separadas por direction + custom via AccumulatedValue.

```dart
class FinancialCategory {
  // === Categorias de Despesa (direction: payable) ===
  static const expenseCategories = [
    'rent',              // Aluguel
    'utilities',         // Agua, luz, internet
    'salaries',          // Salarios
    'supplies',          // Material/Suprimentos
    'maintenance',       // Manutencao
    'marketing',         // Marketing/Publicidade
    'taxes',             // Impostos/Taxas
    'insurance',         // Seguros
    'transport',         // Transporte/Combustivel
    'other',             // Outros
  ];

  // === Categorias de Receita (direction: receivable) ===
  static const incomeCategories = [
    'serviceRevenue',    // Receita de servicos
    'productSale',       // Venda de produtos
    'contractRevenue',   // Receita de contratos
    'otherIncome',       // Outras receitas
  ];

  /// Retorna categorias por direction para uso no picker
  static List<String> byDirection(FinancialEntryDirection direction) {
    return direction == FinancialEntryDirection.payable
        ? expenseCategories
        : incomeCategories;
  }
}
```

**Categorias customizadas** usam o sistema `AccumulatedValue` existente:
- Path despesas: `/companies/{companyId}/accumulatedFields/expenseCategory/values/`
- Path receitas: `/companies/{companyId}/accumulatedFields/incomeCategory/values/`

O picker de categorias mostra as predefinidas (filtradas por direction) + custom, com autocomplete.

---

## Estornos (Reversals)

### Conceito

Estorno e a reversao de um pagamento ja efetivado. Diferente de exclusao, o estorno mantem trilha de auditoria completa -- ambos os payments (original e reverso) ficam visiveis no extrato.

### Fluxo de Estorno

1. Usuario seleciona um payment no extrato e clica "Estornar"
2. Informa motivo do estorno (obrigatorio)
3. Sistema cria **WriteBatch atomico**:

```dart
Future<void> reversePayment(FinancialPayment original, String reason) async {
  final batch = FirebaseFirestore.instance.batch();
  final now = DateTime.now();

  // 1. Criar payment reverso
  final reversalRef = paymentsCollection.doc();
  batch.set(reversalRef, {
    ...original.toJson(),
    'id': reversalRef.id,
    'status': 'completed',
    'reversedPaymentId': original.id,  // Aponta para o original
    'reversalReason': reason,
    'paymentDate': now,
    'description': 'Estorno: ${original.description}',
    'createdAt': now,
  });

  // 2. Marcar payment original como estornado
  batch.update(originalRef, {
    'status': 'reversed',
    'reversedByPaymentId': reversalRef.id,
    'reversedAt': now,
  });

  // 3. Reverter saldo da conta
  final balanceChange = original.type == FinancialPaymentType.expense
      ? original.amount   // Devolver dinheiro (expense estornado)
      : -original.amount; // Retirar dinheiro (income estornado)
  batch.update(accountRef, {
    'currentBalance': FieldValue.increment(balanceChange),
  });

  // 4. Recalcular paidAmount da entry (se vinculada)
  if (original.entryId != null) {
    // Recalcular via query apos commit
  }

  await batch.commit();

  // 5. Recalcular paidAmount da entry vinculada
  if (original.entryId != null) {
    await recalculatePaidAmount(original.entryId!);
  }
}
```

### Visualizacao no Extrato

```
27/03  v  Aluguel marco          -R$2.500   [ESTORNADO]
27/03  ^  Estorno: Aluguel marco +R$2.500   (motivo: pagamento duplicado)
```

- Payment original: riscado ou com badge "ESTORNADO", cor cinza
- Payment reverso: cor amarela/laranja, com motivo visivel

### Regras

| Regra | Descricao |
|-------|-----------|
| Somente `completed` | Apenas payments com status `completed` podem ser estornados |
| Motivo obrigatorio | O campo `reversalReason` e obrigatorio |
| Sem estorno de estorno | Payment reverso nao pode ser estornado novamente |
| Transferencias | Estornar transferencia reverte ambos os payments (via `transferGroupId`) |
| Entry vinculada | Reabre entry (recalcula `paidAmount`, volta para `pending` se necessario) |
| OS vinculada | Se payment tem `orderId`, reverter tambem na OS (via sync) |

---

## Comprovantes (Attachments)

### Storage Path

```
tenants/{companyId}/financial/entries/{entryId}/attachments/
tenants/{companyId}/financial/payments/{paymentId}/attachments/
```

### Uso

- Entries podem ter comprovantes (boletos, contratos, notas)
- Payments podem ter comprovantes (recibos, comprovantes de transferencia)
- Usa o mesmo `PhotoService` existente, com path adaptado
- Limite sugerido: 5 anexos por documento
- Formatos aceitos: imagem (jpg, png) e PDF

### UI

- Botao de anexar no form de entry e no momento do pagamento
- Visualizacao inline (thumbnail) no detalhe da entry/payment
- Galeria com zoom ao tocar

---

## Parcelas (Installments)

### Criacao

Quando o usuario cria um lancamento parcelado (ex: "Equipamento R$6.000 em 6x"):

Gera **6 entries** (parcelas individuais) com `installmentGroupId` compartilhado:

- `installmentGroupId: <uuid>` (mesmo para todas as parcelas)
- `installmentNumber: 1..6`
- `installmentTotal: 6`
- `amount: 1000` (6000 / 6)
- `dueDate: incrementando 1 mes a partir da data base`
- `description: "Equipamento 1/6", "Equipamento 2/6"...`

> **Nota:** Nao existe "entry mae" separada. O agrupamento e feito exclusivamente pelo `installmentGroupId`. Isso evita duplicacao de valores em queries e simplifica filtros.

### Estrutura Visual

```
Parcelamento: "Equipamento R$6.000 (6x R$1.000)"
[agrupado por installmentGroupId]
  |
  |-- Parcela 1/6  R$1.000  venc 27/03  paga
  |-- Parcela 2/6  R$1.000  venc 27/04  pendente
  |-- Parcela 3/6  R$1.000  venc 27/05  pendente
  |-- Parcela 4/6  R$1.000  venc 27/06  pendente
  |-- Parcela 5/6  R$1.000  venc 27/07  pendente
  +-- Parcela 6/6  R$1.000  venc 27/08  pendente
```

### Acoes em Lote (via installmentGroupId)

| Acao | Comportamento |
|------|---------------|
| Editar grupo (descricao, categoria) | Propaga para parcelas pendentes |
| Excluir grupo | Soft-delete de todas as parcelas pendentes. Parcelas ja pagas: confirmacao extra |
| Visualizar grupo | Mostra resumo + lista de todas as parcelas com status |

### Pagamento de Parcelas

- Cada parcela e paga individualmente (cria `FinancialPayment` normal)
- A tela de detalhes do parcelamento mostra o progresso: "2/6 pagas - R$2.000 de R$6.000"

### Queries

```dart
// Buscar todas as parcelas de um parcelamento
final installments = await entryRepo.query([
  QueryArgs('installmentGroupId', groupId),
  QueryArgs('deletedAt', null),
], orderBy: 'installmentNumber');

// Resumo do parcelamento
final total = installments.first.installmentTotal;
final paid = installments.where((e) => e.status == 'paid').length;
final totalAmount = installments.fold<double>(0, (sum, e) => sum + (e.amount ?? 0));
final paidAmount = installments
    .where((e) => e.status == 'paid')
    .fold<double>(0, (sum, e) => sum + (e.amount ?? 0));
```

---

## Transferencias entre Contas

Transferencias nao usam `financialEntries` (nao sao planejamento). Criam diretamente 2 `financialPayments` vinculados.

### Fluxo

1. Usuario seleciona: Conta Origem, Conta Destino, Valor
2. **WriteBatch atomico** cria 2 payments + atualiza 2 contas:

```dart
Future<void> transfer(String fromId, String toId, double amount) async {
  final batch = FirebaseFirestore.instance.batch();
  final groupId = Uuid().v4();

  // Payment 1: saida da origem
  final p1Ref = paymentsCollection.doc();
  batch.set(p1Ref, {
    'type': 'transfer',
    'status': 'completed',
    'amount': amount,
    'accountId': fromId,
    'targetAccountId': toId,
    'transferGroupId': groupId,
    // ...
  });

  // Payment 2: entrada no destino
  final p2Ref = paymentsCollection.doc();
  batch.set(p2Ref, {
    'type': 'transfer',
    'status': 'completed',
    'amount': amount,
    'accountId': toId,
    'targetAccountId': fromId,
    'transferGroupId': groupId,
    // ...
  });

  // Atualizar saldos
  batch.update(fromAccountRef, {
    'currentBalance': FieldValue.increment(-amount),
  });
  batch.update(toAccountRef, {
    'currentBalance': FieldValue.increment(amount),
  });

  await batch.commit();
}
```

### No Extrato

```
27/03  ->  Transferencia Caixa -> Banco    R$1.000
```

Exibido como item unico (agrupado por `transferGroupId`), com icone de transferencia (azul).

---

## Sincronizacao Bidirecional: OS <-> Financeiro

### OS -> Financeiro

| Evento na OS | Acao no Financeiro |
|--------------|--------------------|
| OS aprovada (total > 0) | Cria `FinancialEntry(direction: receivable, orderId: order.id)` |
| Pagamento registrado na OS | Cria `FinancialPayment(type: income)` + atualiza entry `paidAmount` + credita conta |
| OS totalmente paga | Atualiza entry `status: paid` |
| OS cancelada | Atualiza entry `status: cancelled` |

**Local:** metodo `_syncFinancialEntry()` no `OrderStore`

### Financeiro -> OS

| Evento no Financeiro | Acao na OS |
|----------------------|------------|
| Receivable marcado como pago (com orderId) | Cria `PaymentTransaction` na OS + atualiza `paidAmount` + `payment` |
| Pagamento parcial no financeiro | Cria `PaymentTransaction` parcial na OS |

**Local:** metodo `_syncOrderPayment()` no `FinancialEntryStore`

### Prevencao de Loop: syncSource

Em vez de flag booleano em memoria (fragil, nao sobrevive a crash ou multi-device), cada documento sincronizado carrega um campo `syncSource` que indica a origem da ultima alteracao:

```dart
// No documento (entry ou payment)
String? syncSource;  // 'financial' | 'order' | null

// No OrderStore
Future<void> _syncFinancialEntry(Order order) async {
  // Verifica se a alteracao veio do financeiro (evita loop)
  if (order.syncSource == 'financial') {
    // Limpa o flag e retorna
    await orderRepo.update(order.id, {'syncSource': null});
    return;
  }

  // Sync para o financeiro, marcando a origem
  await entryRepo.createOrUpdate({
    ...entryData,
    'syncSource': 'order',  // Marca que veio da OS
  });
}

// No FinancialEntryStore
Future<void> _syncOrderPayment(FinancialEntry entry) async {
  if (entry.syncSource == 'order') {
    await entryRepo.update(entry.id, {'syncSource': null});
    return;
  }

  await orderRepo.addPayment(entry.orderId, {
    ...paymentData,
    'syncSource': 'financial',
  });
}
```

**Vantagens sobre flag booleano:**
- Persiste no Firestore (sobrevive a crash/restart)
- Funciona com multiplos dispositivos simultaneos
- Debugavel (pode ver no Firestore console qual foi a origem)
- Limpo automaticamente apos processamento

---

## Telas e Fluxos UX

> **Principio de design:** O publico-alvo sao donos de pequenos negocios de servico (mecanicas, eletricistas, etc.) que pensam em "quanto gastei" e "quanto recebi", nao em conceitos contabeis. A interface deve ser simples apesar da complexidade interna. Usar linguagem do usuario, nao termos tecnicos.

### Terminologia na UI

| Termo tecnico (codigo) | Termo na UI (pt-BR) |
|-------------------------|---------------------|
| Financial Statement | Financeiro (titulo da tab) |
| Entry (payable) | Despesa / Conta a pagar |
| Entry (receivable) | Recebimento / Conta a receber |
| Financial Payment | Movimentacao (no extrato) |
| Balance | Saldo |
| Installment | Parcela |
| Reversal | Estorno |
| Overdue | Vencida |
| Category | Categoria |
| Account | Conta |

---

### Tela 1: Extrato Financeiro (tela principal)

Layout estilo app de banco com **progressive disclosure** -- mostra o minimo necessario, detalhes acessiveis por scroll ou toque. Substitui o dashboard antigo como tela principal da tab Financeiro.

#### Wireframe

```
+----------------------------------+
|  Financeiro          [filter] [bank] |
+----------------------------------+
|                                  |
|  Saldo Total              [eye] |
|  R$ 15.420,00                    |
|                                  |
|  < Marco 2026 >                  |
|                                  |
|  Entradas +R$12.200   Saidas -R$8.150 |
|                                  |
|  --- Hoje --------------------   |
|  [v]  OS #142 - Joao    +R$350  |
|       Pix . Conta Corrente       |
|  [^]  Aluguel marco    -R$2.500 |
|       Pix . Conta Corrente       |
|                                  |
|  --- Ontem -------------------   |
|  [v]  OS #141 - Maria    +R$800 |
|       Dinheiro . Caixa           |
|  [<>] Caixa -> Banco    R$1.000 |
|  [^]  Material eletrico  -R$450 |
|       Pix . Conta Corrente       |
|                                  |
|  --- 25/03 -------------------   |
|  [v]  OS #140 - Pedro  +R$1.200 |
|       Cartao . Conta Corrente    |
|  ...                             |
|                                  |
+----------------------------------+
|                            [+]   |
+----------------------------------+
```

#### Decisoes de design

**Header simplificado (vs versao anterior):**
- Removido card de "Lucro" do topo -- lucro e indicador de relatorio, nao do extrato diario
- Entradas/Saidas como texto inline compacto, nao como cards separados
- Seletor de periodo simplificado: apenas navegacao por mes (`< Marco 2026 >`)

**Eye toggle para ocultar valores:**
- Icone de olho ao lado do saldo (padrao Nubank/Inter)
- Ao ocultar: todos os valores monetarios na tela viram `* * * *`
- Preferencia salva localmente (SharedPreferences)

**Filtros escondidos (progressive disclosure):**
- Icone de filtro (`CupertinoIcons.line_3_horizontal_decrease`) na nav bar
- Abre `CupertinoActionSheet` com: Tudo, Entradas, Saidas, Transferencias, Periodo custom
- A maioria dos usuarios nunca filtra -- quem precisa, encontra

**Nav bar trailing icons:**
- `[filter]` -- abre filtros (CupertinoActionSheet)
- `[bank]` -- navega para lista de contas bancarias

**FAB simplificado (2 opcoes, nao 3):**
- "Nova Despesa" (icone vermelho)
- "Novo Recebimento" (icone verde)
- Transferencia removida do FAB -- fica na tela de contas (acao rara)
- FAB posicionado na **bottom-right** (thumb zone)

**Badge de vencidas na tab:**
- Badge vermelho no icone da tab "Financeiro" quando houver entries vencidas
- Numero indica quantidade de entries overdue
- Incentiva o usuario a agir sem precisar lembrar

#### Componentes

| Secao | Dados de | Descricao |
|-------|----------|-----------|
| Saldo Total | `financialAccounts` | Soma de `currentBalance` de contas ativas, com eye toggle |
| Resumo inline | `financialPayments` | Texto compacto: "Entradas +R$X  Saidas -R$Y" (status: completed) |
| Navegacao mes | -- | `< Marco 2026 >` com areas de toque generosas (44pt min) |
| Timeline | `financialPayments` | Stream por `paymentDate` desc, `deletedAt == null`, `status != reversed` como cinza |
| FAB | -- | CupertinoActionSheet: Nova Despesa, Novo Recebimento |

#### Icones no Extrato (SF Symbols)

| Tipo | CupertinoIcon | Cor | Sinal |
|------|---------------|-----|-------|
| Income (entrada) | `arrow_down_left` | `CupertinoColors.systemGreen` | + |
| Expense (saida) | `arrow_up_right` | `CupertinoColors.systemRed` | - |
| Transfer | `arrow_right_arrow_left` | `CupertinoColors.activeBlue` | (sem sinal) |
| Reversed (estornado) | texto riscado | `CupertinoColors.systemGrey` | -- |
| Reversal (estorno) | `arrow_uturn_left` | `CupertinoColors.systemYellow` | sinal oposto |

> As setas `arrow_down_left` (dinheiro entrando) e `arrow_up_right` (dinheiro saindo) seguem a convencao de apps bancarios brasileiros (Nubank, Inter).

#### Item do Extrato (padrao compacto 2 linhas)

Cada item da timeline deve ter no maximo 2 linhas para escaneamento rapido:

```dart
// Linha 1: Descricao (bold, truncado) + Valor (alinhado a direita, colorido)
// Linha 2: Forma de pagamento + Conta (secondary label)

Widget _buildPaymentItem(FinancialPayment payment) {
  final isReversed = payment.status == FinancialPaymentStatus.reversed;

  return Padding(
    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    child: Row(
      children: [
        // Icone de direcao (32x32, com background colorido sutil)
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            color: _typeColor(payment.type).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(_typeIcon(payment.type), size: 16, color: _typeColor(payment.type)),
        ),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(child: Text(
                  payment.description ?? '',
                  style: TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w500,
                    color: isReversed
                        ? CupertinoColors.systemGrey.resolveFrom(context)
                        : CupertinoColors.label.resolveFrom(context),
                    decoration: isReversed ? TextDecoration.lineThrough : null,
                  ),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                )),
                SizedBox(width: 8),
                Text(_formatAmount(payment), style: TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w600,
                  color: _typeColor(payment.type),
                )),
              ]),
              SizedBox(height: 2),
              Text(
                '${_paymentMethodLabel(payment.paymentMethod)} . ${payment.account?.name ?? ''}',
                style: TextStyle(fontSize: 15, color: CupertinoColors.secondaryLabel.resolveFrom(context)),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
```

**Swipe actions no item do extrato:**
- Swipe right (azul): Ver detalhes / Editar
- Swipe left (vermelho): Estornar (com confirmacao)

**Tap no item:** Abre detalhe da movimentacao (informacoes completas + acoes)

**OS como link:** Itens vinculados a OS mostram `OS #142` como texto clicavel que navega para a OS.

---

### Tela 2: Formulario de Lancamento (push modal)

Formulario com **2 niveis** -- campos essenciais visiveis, campos opcionais colapsados. A `direction` (despesa/recebimento) e definida pela acao que originou (botao do FAB), nao aparece como campo no formulario.

#### Wireframe

```
+----------------------------------+
|  Cancelar   Nova Despesa  Salvar |
+----------------------------------+
|                                  |
|  +----------------------------+  |
|  | Descricao                  |  |
|  | Ex: Material eletrico      |  |
|  |                            |  |
|  | Valor                      |  |
|  | R$ 0,00              [big] |  |
|  |                            |  |
|  | Vencimento                 |  |
|  | Hoje, 28/03/2026        >  |  |
|  +----------------------------+  |
|                                  |
|  CLASSIFICACAO                   |
|  +----------------------------+  |
|  | Categoria                  |  |
|  | [grid de icones 4x3]      |  |
|  |  Aluguel  Contas  Salarios |  |
|  |  Material Manut.  Market.  |  |
|  |  Impostos Seguros Transp.  |  |
|  |  Outros                    |  |
|  |                            |  |
|  | Conta                      |  |
|  | Conta Corrente           > |  |
|  +----------------------------+  |
|                                  |
|  [ Parcelar em vezes ]           |
|                                  |
|  [ + Adicionar detalhes ]        |
|  (fornecedor, notas, tags,      |
|   anexos -- colapsado)           |
|                                  |
+----------------------------------+
```

#### Decisoes de design

**Campos essenciais (sempre visiveis):**

| Campo | Tipo | Default | Notas |
|-------|------|---------|-------|
| Descricao | Texto livre | -- | Placeholder: "Ex: Material eletrico" |
| Valor | Currency input (FormatService) | R$ 0,00 | Fonte grande (24pt), foco automatico |
| Vencimento | Date picker (CupertinoDatePicker) | Hoje | Modal bottom sheet |

**Classificacao (sempre visivel, com defaults):**

| Campo | Tipo | Default | Notas |
|-------|------|---------|-------|
| Categoria | Grid de icones (4 colunas) | Nenhuma | Filtrada por direction. Icone + label curto |
| Conta | Picker | Conta padrao (`isDefault: true`) | Pre-selecionada para agilizar |

**Parcelamento (toggle inline):**
- Botao "Parcelar em vezes" que expande:
  - Numero de parcelas (stepper: 2x, 3x, 4x... 12x)
  - Valor por parcela (calculado automaticamente)
  - Primeira parcela = vencimento informado
- So aparece se valor > 0

**Detalhes adicionais (colapsado por padrao):**
- Botao "+ Adicionar detalhes" expande secao com:
  - Fornecedor (payable) ou Cliente (receivable) -- texto livre / picker
  - Notas (texto multilinha)
  - Tags (chips editaveis)
  - Anexos (botao de anexar comprovante)

**Recorrencia simplificada:**
- Em vez de formulario completo de recorrencia, oferecer toggle: "Repetir todo mes?"
- Se ativado, cria entry com `recurrence.frequency: monthly, interval: 1`
- Configuracao avancada (semanal, bimestral, etc.) acessivel via "Personalizar" dentro do toggle

**Tempo estimado para caso comum:** 10-15 segundos (descricao + valor + salvar).

#### Picker de Categoria (grid com icones)

```dart
// Grid 4 colunas com icones -- mais rapido que lista
Widget _buildCategoryPicker(FinancialEntryDirection direction) {
  final categories = FinancialCategory.byDirection(direction);

  return Wrap(
    spacing: 12, runSpacing: 12,
    children: categories.map((cat) => GestureDetector(
      onTap: () => setState(() => _selectedCategory = cat),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
              color: _selectedCategory == cat
                  ? CupertinoColors.activeBlue.withOpacity(0.1)
                  : CupertinoColors.systemGrey5.resolveFrom(context),
              borderRadius: BorderRadius.circular(12),
              border: _selectedCategory == cat
                  ? Border.all(color: CupertinoColors.activeBlue, width: 2) : null,
            ),
            child: Icon(_categoryIcon(cat), color: _selectedCategory == cat
                ? CupertinoColors.activeBlue
                : CupertinoColors.secondaryLabel.resolveFrom(context)),
          ),
          SizedBox(height: 4),
          Text(_categoryLabel(cat, context), style: TextStyle(
            fontSize: 11,
            color: CupertinoColors.secondaryLabel.resolveFrom(context),
          )),
        ],
      ),
    )).toList(),
  );
}
```

---

### Half-Sheet: Confirmar Pagamento

Quando o usuario marca uma entry pendente como paga. Usa `showCupertinoModalPopup` com half-sheet em vez de tela nova -- acao rapida que nao justifica navegacao completa.

#### Wireframe

```
+----------------------------------+
|        Confirmar Pagamento       |
+----------------------------------+
|                                  |
|  Aluguel escritorio              |
|  Vencimento: 10/04/2026         |
|                                  |
|  Valor  [R$ 2.500,00]     edit  |
|  Conta  [Conta Corrente]     >  |
|  Forma  [Pix]                >  |
|  Data   [Hoje, 28/03]       >  |
|                                  |
|  [ Anexar comprovante ]          |
|                                  |
|  [====== Confirmar ======]       |
|                                  |
+----------------------------------+
```

#### Decisoes de design

**Pre-fill inteligente (zero edicao no caso comum):**
- Valor: pre-preenchido com `entry.remainingBalance`
- Conta: ultima conta usada pelo usuario (ou conta padrao)
- Forma de pagamento: ultima forma usada pelo usuario
- Data: hoje
- O caso mais comum (pagar tudo, da mesma forma) exige **2 toques**: "Pagar" + "Confirmar"

**Pagamento parcial:**
- Usuario edita o valor para pagar menos que o total
- Sistema atualiza `paidAmount` e mantem entry como `pending`

**Entry points (como chegar aqui):**
1. Toque na entry pendente na lista > detalhe > botao "Pagar" (verde, full-width)
2. Swipe-right na entry pendente na lista > abre direto o half-sheet
3. Dentro do card de parcelas > botao "Pagar" na proxima parcela pendente

**Comprovante opcional:**
- Botao "Anexar comprovante" abre `CupertinoActionSheet` com camera/galeria
- Thumbnail do comprovante aparece apos anexar

---

### Half-Sheet: Transferencia entre Contas

Acessivel a partir da **tela de contas bancarias** (nao do FAB do extrato). A conta de origem ja esta selecionada pelo contexto.

#### Wireframe

```
+----------------------------------+
|            Transferir            |
+----------------------------------+
|                                  |
|  De: Caixa (R$ 3.200,00)        |
|                                  |
|  Para  [Selecionar conta]    >  |
|  Valor [R$ ______]              |
|                                  |
|  [====== Transferir ======]      |
|                                  |
+----------------------------------+
```

Apenas 2 campos para preencher (destino e valor). A origem ja esta selecionada pelo contexto de onde o usuario veio.

---

### Tela 3: Lista de Contas Bancarias

Acessivel pelo icone de banco na nav bar do extrato.

#### Wireframe

```
+----------------------------------+
|  <- Contas                  [+]  |
+----------------------------------+
|                                  |
|  SALDO TOTAL                     |
|  R$ 15.420,00                    |
|                                  |
|  +----------------------------+  |
|  | [bank] Conta Corrente Itau |  |
|  |        R$ 12.500,00        |  |
|  +----------------------------+  |
|  | [cash] Caixa               |  |
|  |        R$ 2.420,00         |  |
|  +----------------------------+  |
|  | [pix]  Pix PicPay          |  |
|  |        R$ 500,00           |  |
|  +----------------------------+  |
|                                  |
+----------------------------------+
```

**Interacoes:**
- Tap na conta: abre detalhe com extrato filtrado por conta + acoes
- Swipe right (azul): transferir a partir desta conta (abre half-sheet)
- Swipe left (vermelho): editar conta
- Botao [+] na nav bar: criar nova conta

---

### Widget: Card de Parcelas (expansivel inline)

Substitui a `InstallmentDetailScreen` dedicada. Quando uma entry pertence a um parcelamento (`installmentGroupId != null`), ela e exibida como card expansivel na lista de entries.

#### Wireframe (colapsado)

```
+----------------------------------+
| Equipamento novo                 |
| 6x de R$1.000  [2/6 pagas]      |
| [========----------] 33%        |
+----------------------------------+
```

#### Wireframe (expandido)

```
+----------------------------------+
| Equipamento novo                 |
| 6x de R$1.000  [2/6 pagas]      |
| [========----------] 33%        |
|                                  |
| ok  1/6  R$1.000  10/03  [paga] |
| ok  2/6  R$1.000  10/04  [paga] |
| >>  3/6  R$1.000  10/05 [PAGAR] |
|     4/6  R$1.000  10/06 pendente |
|     5/6  R$1.000  10/07 pendente |
|     6/6  R$1.000  10/08 pendente |
+----------------------------------+
```

**Decisoes de design:**
- Barra de progresso visual (colorida) mostra % pago
- Proxima parcela pendente tem botao "PAGAR" destacado (verde) que abre direto o half-sheet
- Parcelas pagas mostram checkmark verde
- Parcelas vencidas mostram dot vermelho
- Tap no card expande/colapsa a lista de parcelas

---

### Empty States e Onboarding

#### Primeira visita ao modulo (sem contas bancarias)

```
+----------------------------------+
|  Financeiro                      |
+----------------------------------+
|                                  |
|         [briefcase icon]         |
|                                  |
|     Controle suas financas       |
|                                  |
|  Registre despesas e recebimentos|
|  para saber exatamente quanto    |
|  entra e quanto sai do seu       |
|  negocio.                        |
|                                  |
|      [=== Comecar ===]           |
|      Leva menos de 1 minuto      |
|                                  |
+----------------------------------+
```

#### Fluxo de onboarding (3 passos rapidos)

1. **Criar primeira conta:** "Como voce recebe seus pagamentos?"
   - Cards pre-definidos: "Dinheiro/Caixa", "Conta bancaria", "Pix/Carteira digital"
   - Criar conta com **um toque** no card
2. **Saldo inicial:** "Quanto tem nessa conta hoje?"
   - Input de valor simples
3. **Pronto:** "Tudo certo! Registre sua primeira despesa ou recebimento."
   - CTA direto para o FAB

#### Empty state do extrato (mes sem movimentacoes)

```
Nenhuma movimentacao em marco.
[Registrar despesa]  [Registrar recebimento]
```

Dois botoes inline para acao imediata, sem precisar usar o FAB.

---

### Quick Actions (atalhos de alto impacto)

| Acao | Como funciona | Impacto |
|------|---------------|---------|
| Swipe-right para pagar | Na lista de entries pendentes, swipe-right abre direto o half-sheet de pagamento | Reduz de 3 toques para 1 |
| Pre-fill inteligente | Valor, conta e forma pre-preenchidos no half-sheet | Zero edicao no caso comum |
| Badge de vencidas | Badge vermelho na tab Financeiro com count de entries overdue | Visibilidade sem abrir |
| "Repetir todo mes?" | Toggle simples no form em vez de formulario de recorrencia | Cobre 90% dos casos |
| Link da OS | `OS #142` clicavel no extrato navega direto para a OS | Rastreabilidade |
| Parcela rapida | Botao "Pagar" direto na proxima parcela do card expansivel | Sem navegacao extra |

---

### Consideracoes Mobile-First

**Zona do polegar (thumb zone):**
- FAB na **bottom-right**, acessivel com polegar direito
- Seletor de periodo (`< Marco 2026 >`) com areas de toque de 44pt minimo (HIG)
- Todas as acoes primarias (criar, pagar, navegar) na metade inferior da tela
- Filtros e configuracoes no topo (nav bar) -- alcance intencional

**Densidade de informacao:**
- Cada item do extrato tem no maximo **2 linhas** (descricao + metadado)
- Valores monetarios alinhados a direita para escaneamento vertical rapido
- Separadores por data como sticky headers

**Performance:**
- Timeline usa stream paginado (Firestore `limit` + `startAfter`)
- KPIs calculados no store (nao na UI)
- Eye toggle e preferencia local (SharedPreferences), nao requer fetch

---

### Transicao do Dashboard Existente

**Fase 1-2:** A tab Financeiro vira o **Extrato** (nova tela principal). O dashboard antigo (`FinancialDashboardSimple`) fica acessivel via botao "Relatorios" (icone de grafico) na nav bar do extrato.

**Fase 4:** Quando DRE e fluxo projetado forem implementados, o botao "Relatorios" navega para uma tela dedicada com todos os graficos e indicadores avancados.

**Justificativa:** A acao diaria do usuario e ver o que entrou e saiu (extrato). Graficos sao para reflexao semanal/mensal. O extrato e o dia-a-dia.

---

## Permissoes (RBAC)

### Novas Permissions

| Permission | Descricao |
|------------|-----------|
| `manageFinancialEntries` | CRUD contas a pagar/receber |
| `manageFinancialAccounts` | CRUD contas bancarias |
| `viewFinancialStatement` | Visualizar extrato (somente leitura) |

### Acesso por Perfil

| Perfil | Ver Extrato | Gerenciar Entries | Gerenciar Contas | Dashboard |
|--------|-------------|-------------------|------------------|-----------|
| Admin | sim | sim | sim | sim |
| Gerente | sim | sim | sim | sim |
| Supervisor | nao | nao | nao | nao |
| Consultor | nao | nao | nao | nao |
| Tecnico | nao | nao | nao | nao |

As permissoes existentes (`viewPrices`, `viewBilling`, `viewFinancialReports`) continuam controlando o acesso ao dashboard de faturamento da OS.

---

## Indicadores Financeiros

### KPIs do Extrato (por periodo)

| Indicador | Calculo | Fonte |
|-----------|---------|-------|
| Entradas | Soma de payments `type: income, status: completed` | `financialPayments` |
| Saidas | Soma de payments `type: expense, status: completed` | `financialPayments` |
| Lucro | Entradas - Saidas | Calculado |
| Margem | (Lucro / Entradas) x 100 | Calculado |

> **Importante:** KPIs filtram apenas payments com `status: completed`. Payments com `status: reversed` sao ignorados.

### KPIs de Saldo

| Indicador | Calculo | Fonte |
|-----------|---------|-------|
| Saldo Total | Soma de `currentBalance` de contas ativas | `financialAccounts` |
| Saldo por Conta | `currentBalance` individual | `financialAccounts` |

### KPIs de Planejamento

| Indicador | Calculo | Fonte |
|-----------|---------|-------|
| A Pagar (pendente) | Soma de entries payable pending (excluindo parcelas com installmentGroupId para evitar duplicacao) | `financialEntries` |
| A Receber (pendente) | Soma de entries receivable pending | `financialEntries` |
| Vencidas | Entries com status pending + dueDate < hoje | `financialEntries` |
| Despesa por Categoria | Agrupamento de expenses (completed) por category | `financialPayments` |

### Fluxo de Caixa Projetado

Visao do futuro financeiro baseado nas entries pendentes:

```
Fluxo de Caixa Projetado (proximos 3 meses)

Saldo Atual:                    R$ 15.420,00

Abril/2026:
  (+) A Receber:                R$  8.200,00
  (-) A Pagar:                  R$ -5.300,00
  (=) Saldo Projetado:          R$ 18.320,00

Maio/2026:
  (+) A Receber:                R$  6.500,00
  (-) A Pagar:                  R$ -4.800,00
  (=) Saldo Projetado:          R$ 20.020,00

Junho/2026:
  (+) A Receber:                R$  7.100,00
  (-) A Pagar:                  R$ -5.100,00
  (=) Saldo Projetado:          R$ 22.020,00
```

**Calculo:**

```dart
Map<String, ProjectedCashFlow> calculateProjectedCashFlow(int months) {
  final now = DateTime.now();
  final projections = <String, ProjectedCashFlow>{};
  double runningBalance = totalBalance; // Saldo atual das contas

  for (var i = 1; i <= months; i++) {
    final monthStart = DateTime(now.year, now.month + i, 1);
    final monthEnd = DateTime(now.year, now.month + i + 1, 0);

    final receivables = pendingEntries
        .where((e) => e.direction == 'receivable'
            && e.dueDate.isAfter(monthStart)
            && e.dueDate.isBefore(monthEnd))
        .fold<double>(0, (sum, e) => sum + e.remainingBalance);

    final payables = pendingEntries
        .where((e) => e.direction == 'payable'
            && e.dueDate.isAfter(monthStart)
            && e.dueDate.isBefore(monthEnd))
        .fold<double>(0, (sum, e) => sum + e.remainingBalance);

    runningBalance += receivables - payables;
    projections[monthKey] = ProjectedCashFlow(
      receivables: receivables,
      payables: payables,
      projectedBalance: runningBalance,
    );
  }
  return projections;
}
```

### DRE Simplificado (por periodo)

Demonstrativo de Resultado do Exercicio simplificado:

```
DRE - Marco/2026

RECEITAS
  Receita de servicos (OS)       R$ 8.500,00
  Venda de produtos              R$ 1.200,00
  Receita de contratos           R$ 2.500,00
  -------------------------------------------
  Total Receitas                 R$ 12.200,00

DESPESAS
  Aluguel                        R$ 2.500,00
  Salarios                       R$ 4.200,00
  Agua, luz, internet            R$   380,00
  Material/Suprimentos           R$   650,00
  Impostos                       R$   420,00
  -------------------------------------------
  Total Despesas                 R$  8.150,00

  -------------------------------------------
  RESULTADO                      R$  4.050,00
  MARGEM                         33,2%
```

**Calculo:** Agrupa payments `completed` do periodo por `category`, separados por `type` (income/expense).

### Dashboard Financeiro Aprimorado

O dashboard existente (`FinancialDashboardSimple`) sera expandido com:

1. **Secao de Lucro** - Receita (OS) vs Despesas (entries) = Lucro
2. **Saldo em Contas** - Cards por conta bancaria
3. **Fluxo de Caixa** - Grafico de barras: entradas vs saidas por mes
4. **Fluxo de Caixa Projetado** - Linha projetada baseada nas entries pendentes
5. **Despesas por Categoria** - Grafico pizza com breakdown
6. **DRE Simplificado** - Receitas vs Despesas por categoria
7. **Contas Vencidas** - Alerta com lista de entries overdue

---

## Fases de Implementacao

### Fase 1 - Foundation + Contas a Pagar + Extrato

**Escopo:** Toda a infraestrutura base + capacidade de registrar e pagar despesas.

**Arquivos a criar:**
- `lib/models/financial_account.dart`
- `lib/models/financial_entry.dart`
- `lib/models/financial_payment.dart`
- `lib/repositories/tenant/tenant_financial_account_repository.dart`
- `lib/repositories/tenant/tenant_financial_entry_repository.dart`
- `lib/repositories/tenant/tenant_financial_payment_repository.dart`
- `lib/repositories/v2/financial_account_repository_v2.dart`
- `lib/repositories/v2/financial_entry_repository_v2.dart`
- `lib/repositories/v2/financial_payment_repository_v2.dart`
- `lib/mobx/financial_account_store.dart`
- `lib/mobx/financial_entry_store.dart`
- `lib/mobx/financial_payment_store.dart`
- `lib/screens/financial/financial_statement_screen.dart` -- extrato principal
- `lib/screens/financial/financial_entry_form_screen.dart` -- formulario 2 niveis
- `lib/screens/financial/widgets/payment_confirmation_sheet.dart` -- half-sheet de pagamento
- `lib/screens/financial/widgets/payment_timeline_item.dart` -- item compacto do extrato
- `lib/screens/financial/widgets/balance_header.dart` -- header com eye toggle
- `lib/screens/financial/widgets/category_picker_grid.dart` -- grid de categorias com icones
- `lib/screens/financial/widgets/installment_progress_card.dart` -- card expansivel de parcelas

**Arquivos a modificar:**
- `lib/models/permission.dart` - novas permissions
- `lib/l10n/app_pt.arb`, `app_en.arb`, `app_es.arb` - i18n
- `lib/routes.dart` - novas rotas
- `lib/screens/menu_navigation/navigation_controller.dart` - tab Financeiro aponta para extrato

**Requisitos criticos:**
- Todas as operacoes de pagamento usam `WriteBatch`
- Soft delete implementado desde o inicio
- Status do payment (`completed`/`reversed`) presente desde o inicio
- Eye toggle para ocultar valores (SharedPreferences)
- Empty state + onboarding de 3 passos na primeira visita
- Formulario com campos essenciais visiveis + detalhes colapsados
- Half-sheet de pagamento com pre-fill inteligente

**Resultado:** Usuario registra despesas (simples e parceladas), paga com 2 toques, e ve no extrato.

### Fase 2 - Contas Bancarias + Saldo + Transferencias

**Escopo:** Gestao de contas, transferencias e reconciliacao.

**Arquivos a criar:**
- `lib/screens/financial/financial_account_list_screen.dart` -- lista com saldo por conta
- `lib/screens/financial/financial_account_form_screen.dart` -- form criar/editar conta
- `lib/screens/financial/widgets/transfer_sheet.dart` -- half-sheet de transferencia

**Arquivos a modificar:**
- `lib/screens/financial/financial_statement_screen.dart` - header com saldo total, icone de contas na nav bar
- `lib/mobx/financial_payment_store.dart` - logica de transferencia atomica (WriteBatch)
- `lib/mobx/financial_account_store.dart` - reconciliacao de saldo
- `lib/screens/financial/financial_entry_form_screen.dart` - account picker pre-selecionado

**Resultado:** Controle de saldo, transferencias atomicas via half-sheet, reconciliacao.

### Fase 3 - Recebiveis + Sync Bidirecional com OS + Estornos

**Escopo:** Contas a receber + integracao com OS + estornos.

**Arquivos a modificar:**
- `lib/mobx/order_store.dart` - `_syncFinancialEntry()` com `syncSource`
- `lib/mobx/financial_entry_store.dart` - `_syncOrderPayment()` com `syncSource`
- `lib/mobx/financial_payment_store.dart` - `reversePayment()` + `recalculatePaidAmount()`
- `lib/screens/financial/financial_statement_screen.dart` - filtros via ActionSheet, badge de vencidas, link OS clicavel, visualizacao de estornos
- `lib/screens/financial/financial_entry_form_screen.dart` - modo receivable (customer picker), comprovantes
- `lib/screens/financial/widgets/payment_timeline_item.dart` - swipe-right para pagar, estilo estornado

**Resultado:** Visao completa de recebiveis, pagamento por qualquer tela (OS ou financeiro), estornos com auditoria, OS como link no extrato.

### Fase 4 - Recorrencia + Relatorios Avancados

**Escopo:** Automatizacao, projecoes e insights visuais.

**Arquivos a criar:**
- `lib/screens/financial/financial_reports_screen.dart` -- tela de relatorios (DRE, fluxo projetado, graficos)

**Arquivos a modificar:**
- `lib/mobx/financial_entry_store.dart` - geracao de recorrencia com `lastGeneratedDate`
- `lib/screens/financial/financial_entry_form_screen.dart` - toggle "Repetir todo mes?" simplificado
- `lib/screens/financial/financial_statement_screen.dart` - botao "Relatorios" na nav bar

**Novos componentes na tela de Relatorios:**
- Fluxo de Caixa Projetado (proximos 3-6 meses)
- DRE Simplificado (por periodo)
- Grafico de fluxo de caixa (entradas vs saidas por mes)
- Grafico pizza despesas por categoria
- Dashboard antigo (`FinancialDashboardSimple`) integrado

**Resultado:** Lancamentos recorrentes com toggle simples, projecao financeira, DRE simplificado, tela de relatorios dedicada.

---

## Retrocompatibilidade

### Sistema Atual de Pagamentos na OS

O sistema atual (`PaymentTransaction` na OS) **nao e alterado**. Continua funcionando como hoje:
- Pagamentos na OS ficam em `order.transactions[]`
- Dashboard de faturamento continua lendo de `orders`
- Nenhuma migracao de dados e necessaria na Fase 1

### PaymentMethod Compartilhado

Se `PaymentMethod` ja existe no modelo de OS, reutilizar o mesmo enum (mover para arquivo compartilhado se necessario). Evita divergencia entre os dois sistemas.

### Dados Existentes

- OS existentes nao terao `FinancialEntry` associada automaticamente
- Apenas novas OS (aprovadas apos a ativacao do modulo) gerarao entries automaticamente (Fase 3)
- Backfill de OS antigas e opcional e pode ser feito via script se desejado

---

## Changelog

### Marco 2026

#### Analise tecnica Firestore e decisoes de infraestrutura (30/03/2026)

**Conclusao:** Firestore da conta do modulo financeiro para o publico-alvo (<500 transacoes/mes).

**Adicionado ao documento:**
- Secao completa "Decisoes Tecnicas: Firestore (NoSQL)" com justificativa SQL vs NoSQL
- Estimativa de volume por empresa (mensal, anual, 3 anos)
- 12 indices compostos necessarios (JSON pronto para `firestore.indexes.json`)
- Estrategia de queries (1 equality + date range, excesso filtrado client-side)
- Padroes de agregacao client-side (mesmo padrao do dashboard existente)
- Tabela WriteBatch vs Transaction por operacao
- Snapshots mensais por conta para reconciliacao/relatorios de longo prazo
- Security rules para as 3 colecoes + storage paths para comprovantes
- Tabela de limites do Firestore a monitorar

#### Revisao de UX e usabilidade das telas (28/03/2026)

**Reescrita completa da secao de telas com foco em usabilidade:**

Arquitetura de telas:
- Reduzido de 5 telas para 3 telas + 2 half-sheets + widgets expansiveis
- `InstallmentDetailScreen` substituida por card expansivel inline (`InstallmentProgressCard`)
- Transferencia movida do FAB para contexto de contas (half-sheet `TransferSheet`)
- Pagamento via half-sheet (`PaymentConfirmationSheet`) com pre-fill inteligente

Tela principal (Extrato) simplificada:
- Removido card de "Lucro" do header (pertence a Relatorios)
- Removidos chips de filtro do estado inicial (movidos para ActionSheet na nav bar)
- Seletor de periodo simplificado para navegacao por mes apenas
- Adicionado eye toggle para ocultar valores (padrao Nubank)
- FAB reduzido para 2 opcoes (Nova Despesa, Novo Recebimento)
- Item do extrato com padrao compacto de 2 linhas
- Icones SF Symbols seguindo convencao de apps bancarios brasileiros

Formulario de lancamento redesenhado:
- Dividido em 2 niveis (campos essenciais + detalhes colapsados)
- Categoria como grid de icones (4 colunas) em vez de lista
- Parcelamento como toggle inline
- Recorrencia simplificada ("Repetir todo mes?")
- Conta pre-selecionada (default)

Novos elementos de UX:
- Empty state e onboarding de 3 passos para primeira visita
- Swipe-right para pagar entry pendente
- Badge de vencidas na tab Financeiro
- Link da OS clicavel no extrato
- Botao "Pagar" direto na proxima parcela do card expansivel
- Tabela de terminologia (termos tecnicos vs linguagem do usuario)
- Consideracoes mobile-first (thumb zone, densidade, performance)
- Plano de transicao do dashboard existente para extrato como tela principal

#### Revisao tecnica e otimizacao (28/03/2026)

**Melhorias incorporadas:**
- Operacoes atomicas obrigatorias (`WriteBatch`) para todas as operacoes multi-documento
- Reconciliacao de saldo (deteccao e correcao de drift no `currentBalance`)
- Sync bidirecional via `syncSource` no documento (substitui flag booleano em memoria)
- Sistema de estornos com trilha de auditoria completa (`FinancialPaymentStatus`)
- `paidAmount` recalculado via payments ativos (fonte da verdade sao os payments)
- Parcelas sem entry mae (agrupamento via `installmentGroupId` apenas)
- Categorias separadas por direction (`expenseCategories` / `incomeCategories`)
- Soft delete (`deletedAt`/`deletedBy`) para entries e payments
- Campo `attachments` para comprovantes em entries e payments
- `lastGeneratedDate` em recorrencia para prevenir duplicacao
- `lastReconciledAt` em contas para rastrear reconciliacoes
- Fluxo de Caixa Projetado (baseado em entries pendentes)
- DRE Simplificado (receitas vs despesas por categoria)
- Permission `viewFinancialStatement` para acesso somente leitura
- Nota sobre reutilizacao do `PaymentMethod` existente
- KPIs filtram apenas payments com `status: completed`

#### Criacao da especificacao do Modulo Financeiro (27/03/2026)

**Decisoes arquiteturais:**
- Colecao unica `financialEntries` para pagar/receber (com enum `direction`)
- Colecao `financialPayments` como base do extrato (movimentacoes reais)
- Transferencias como 2 payments vinculados (sem colecao separada)
- Parcelas como N entries filhas vinculadas via `installmentGroupId`
- Sync bidirecional OS <-> Financeiro
- Tela principal estilo extrato bancario com filtros
- Categorias predefinidas + custom via AccumulatedValue
- Balance tracking simples (sem contabilidade dupla)
