# Modulo Financeiro Completo - PraticOS

## Indice

1. [Visao Geral](#visao-geral)
2. [Conceito Central: Entries vs Payments](#conceito-central-entries-vs-payments)
3. [Arquitetura](#arquitetura)
4. [Decisoes Tecnicas: Firestore](#decisoes-tecnicas-firestore-nosql)
5. [Integridade de Dados](#integridade-de-dados)
6. [Modelos de Dados](#modelos-de-dados)
7. [Estornos](#estornos-reversals)
8. [Comprovantes](#comprovantes-attachments)
9. [Parcelas](#parcelas-installments)
10. [Transferencias](#transferencias-entre-contas)
11. [Sincronizacao OS <-> Financeiro](#sincronizacao-bidirecional-os---financeiro)
12. [Telas e Fluxos UX](#telas-e-fluxos-ux)
13. [Permissoes (RBAC)](#permissoes-rbac)
14. [Indicadores Financeiros](#indicadores-financeiros)
15. [API Cloud Functions](#api-endpoints-cloud-functions)
16. [Bot WhatsApp](#bot-comandos-financeiros)
17. [Site: Documentacao Publica](#site-documentacao-publica)
18. [Documentacao: Checklist](#documentacao-checklist)
19. [Fases de Implementacao (Sprints)](#fases-de-implementacao)
20. [Retrocompatibilidade](#retrocompatibilidade)
21. [Revisao UX Mobile-First](#revisao-ux-mobile-first)
22. [Changelog](#changelog)

---

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
| Recalcular paidAmount | Sim (query payments ativos) | `Transaction` (obrigatorio -- evita race condition) |
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

**Quando implementar:** Fase 2 (geracao manual via botao "Fechar mes" na tela de contas). Cloud Function automatica (primeiro dia do mes) pode ser adicionada na Fase 4.

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
    if (p.deletedAt != null) continue;  // Ignorar soft-deleted
    if (p.status == FinancialPaymentStatus.reversed) continue;
    if (p.type == FinancialPaymentType.income) balance += p.amount ?? 0;
    if (p.type == FinancialPaymentType.expense) balance -= p.amount ?? 0;
    if (p.type == FinancialPaymentType.transfer) {
      if (p.transferDirection == 'out') balance -= p.amount ?? 0;
      if (p.transferDirection == 'in') balance += p.amount ?? 0;
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

### Comportamento Offline

O Firestore possui cache offline nativo. Comportamento esperado:

- **Criar entry offline:** Salvo localmente, sincronizado quando reconectar. Funciona normalmente.
- **WriteBatch offline:** O batch e enfileirado localmente e executado no servidor ao reconectar. Atomicidade e mantida.
- **Conflito de sync:** Se dois dispositivos editam o mesmo documento offline, o ultimo a sincronizar vence (last-write-wins). Para pagamentos, isso e aceitavel pois cada pagamento cria um novo documento.
- **Saldo offline:** O `currentBalance` pode ficar temporariamente desatualizado. A reconciliacao (manual ou automatica) corrige ao reconectar.

### Conta Bancaria Desativada

Quando uma conta e desativada (`active: false`):

- **Entries pendentes vinculadas:** Permanecem pendentes. O usuario deve reatribuir a outra conta ou pagar antes de desativar.
- **Validacao no form:** Ao desativar, exibir alerta se houver entries pendentes vinculadas.
- **Novas entries:** Contas inativas nao aparecem no picker de conta.
- **Extrato:** Payments historicos da conta inativa continuam visiveis (conta desativada nao apaga historico).

### Validacao de Valores

| Campo | Regra | Onde aplicar |
|-------|-------|-------------|
| `amount` | Min: 0.01, Max: 999.999.999,99 | Form + API (Zod) |
| `description` | Min: 1 char, Max: 500 | Form + API |
| `dueDate` | Obrigatorio | Form + API |
| `accountId` | Deve existir e estar ativa | Service layer |
| `installments.count` | Min: 2, Max: 60 | Form + API |
| `paymentDate` | Nao pode ser no futuro (exceto agendamento) | Service layer |

### Validacao de Saldo Negativo

Algumas contas nao devem ficar com saldo negativo (nao existe dinheiro negativo no caixa fisico). A validacao e um **alerta com confirmacao**, nao um bloqueio -- o usuario pode forcar a operacao se necessario.

| Tipo de Conta | Permite saldo negativo? | Comportamento |
|---------------|------------------------|---------------|
| `cash` | Nao (alerta + confirmacao) | "Caixa ficara com saldo negativo (R$ -200). Continuar?" |
| `bank` | Sim | Sem alerta (cheque especial e comum) |
| `creditCard` | Sim | Sem alerta (comportamento normal do cartao) |
| `digitalWallet` | Nao (alerta + confirmacao) | "Carteira ficara com saldo negativo. Continuar?" |

**Onde aplicar:** No `FinancialPaymentStore`, antes de confirmar o `WriteBatch` de pagamento ou transferencia. Verificar `account.currentBalance - amount < 0` e exibir `CupertinoAlertDialog` se a conta nao permite negativo.

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
  FinancialEntryStatus? status;        // pending | paid | cancelled (overdue e computado via isOverdue)

  // Valores
  String? description;                 // "Aluguel escritorio marco"
  double? amount;                      // Valor total
  double? paidAmount;                  // Quanto ja foi pago (parcial) - recalculado via payments
  double? discountAmount;              // Desconto concedido (ex: abatimento ao pagar menos que o total)
  DateTime? dueDate;                   // Data de vencimento
  DateTime? competenceDate;            // Data de competencia (para DRE). Default = dueDate
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
  String? orderId;                     // Receivable: gerado automaticamente da OS. Payable: custo direto da OS (uso futuro)
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

  // Sync bidirecional com OS
  String? syncSource;                    // 'financial' | 'order' | null (previne loop de sync)

  // Soft delete
  DateTime? deletedAt;
  UserAggr? deletedBy;

  // Computed
  double get remainingBalance => (amount ?? 0) - (paidAmount ?? 0) - (discountAmount ?? 0);
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
  @JsonValue('pending')   pending,    // Pendente (inclui vencidas -- usar getter isOverdue)
  @JsonValue('paid')      paid,       // Pago
  @JsonValue('cancelled') cancelled,  // Cancelado
}

// NOTA: "Vencida" NAO e um status armazenado. E um estado computado via getter:
//   bool get isOverdue => status == pending && dueDate < now
// Queries de vencidas: where('status', '==', 'pending').where('dueDate', '<', now)
// Isso evita a necessidade de scheduled job para atualizar status.
```

**`paidAmount` - Recalculo via Payments:**

O `paidAmount` e um valor denormalizado para performance, mas a **fonte da verdade** sao os `FinancialPayment` vinculados (via `entryId`). Ao estornar ou excluir um payment, recalcular usando `Transaction` para evitar race conditions (ex: dois estornos simultaneos em multi-device):

```dart
Future<void> recalculatePaidAmount(String entryId) async {
  await FirebaseFirestore.instance.runTransaction((transaction) async {
    // 1. Ler entry e payments dentro da transaction (garante consistencia)
    final entryDoc = await transaction.get(entryRef(entryId));
    final entry = FinancialEntry.fromJson(entryDoc.data()!);
    final paymentsSnapshot = await transaction.get(
      paymentsCollection.where('entryId', isEqualTo: entryId),
    );

    // 2. Calcular paidAmount real
    final payments = paymentsSnapshot.docs.map((d) => FinancialPayment.fromJson(d.data()));
    final activePaidAmount = payments
        .where((p) => p.status == FinancialPaymentStatus.completed && p.deletedAt == null)
        .fold<double>(0, (sum, p) => sum + (p.amount ?? 0));

    final totalWithDiscount = activePaidAmount + (entry.discountAmount ?? 0);
    final isFullyPaid = totalWithDiscount >= (entry.amount ?? 0);

    // 3. Atualizar entry atomicamente
    transaction.update(entryRef(entryId), {
      'paidAmount': activePaidAmount,
      'status': isFullyPaid ? 'paid' : 'pending',
      'paidDate': isFullyPaid ? DateTime.now() : null,
    });
  });
}
```

> **Nota:** A `Transaction` garante que a leitura dos payments e a escrita do `paidAmount` sejam atomicas. Se outro processo modificar os payments durante a transaction, o Firestore faz retry automaticamente.

#### Estrutura no Firestore

```
/companies/{companyId}/financialEntries/{entryId}
{
  "direction": "payable",
  "status": "pending",
  "description": "Aluguel escritorio marco",
  "amount": 2500.00,
  "paidAmount": 0.00,
  "discountAmount": 0.00,
  "dueDate": "2026-04-10T00:00:00Z",
  "competenceDate": "2026-04-01T00:00:00Z",
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
  double? discount;                    // Desconto concedido neste pagamento (ex: abatimento)
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
  String? transferDirection;           // 'out' | 'in' (explicita direcao da transferencia)

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

  // Sync bidirecional com OS
  String? syncSource;                  // 'financial' | 'order' | null

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
  "discount": 0.00,
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
  "transferDirection": null,
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

**Prevencao de duplicacao e catch-up:**

A geracao de recorrencia acontece **client-side no app** (nao via Cloud Function). Se o usuario nao abrir o app por semanas, as entries pendentes nao sao geradas ate a proxima abertura. O loop de catch-up abaixo gera todas as entries atrasadas de uma vez:

```dart
// Loop de catch-up: gera todas as entries atrasadas desde a ultima abertura
Future<void> processRecurrence(FinancialEntry entry) async {
  var nextDueDate = entry.recurrence!.nextDueDate!;

  while (nextDueDate.isBefore(DateTime.now()) || nextDueDate.isAtSameMomentAs(DateTime.now())) {
    // Verifica se ja existe entry com este dueDate para esta recorrencia
    final existing = await entryRepo.query([
      QueryArgs('recurrence.nextDueDate', nextDueDate),
      QueryArgs('direction', entry.direction),
      QueryArgs('description', entry.description),
    ]);

    if (existing.isEmpty) {
      // Gerar nova entry com dueDate = nextDueDate
      await _createRecurringEntry(entry, nextDueDate);
    }

    // Avancar para proxima data
    nextDueDate = calculateNextDueDate(nextDueDate, entry.recurrence!.frequency, entry.recurrence!.interval);
  }

  // Atualizar lastGeneratedDate e nextDueDate na entry original
  await entryRepo.update(entry.id, {
    'recurrence.lastGeneratedDate': DateTime.now(),
    'recurrence.nextDueDate': nextDueDate,
  });
}
```

> **Limitacao conhecida:** Como a geracao e client-side, entries recorrentes so sao criadas quando o app e aberto. Para o publico-alvo (donos de pequenos negocios que usam o app diariamente), isso e aceitavel. Se necessario no futuro, uma Cloud Function scheduled pode ser adicionada sem alterar a estrutura.

Segue o mesmo padrao do `OrderContract` ja existente no sistema.

---

### Categorias Financeiras

Categorias sao **100% dinamicas**, gerenciadas pelo sistema `AccumulatedValue` existente no app. Nao ha categorias hardcoded no codigo -- apenas categorias iniciais sugeridas via bootstrap.

#### Firestore Structure

```
/companies/{companyId}/accumulatedFields/
  expenseCategory/
    values/
      {valueId}: { "value": "Aluguel", "searchKey": "aluguel", "usageCount": 12 }
      {valueId}: { "value": "Material", "searchKey": "material", "usageCount": 8 }
      ...
  incomeCategory/
    values/
      {valueId}: { "value": "Servicos", "searchKey": "servicos", "usageCount": 25 }
      ...
```

Usa o mesmo `AccumulatedValueRepository` e `AccumulatedValueListScreen` que ja existem para `deviceCategory`, `deviceBrand`, etc. O usuario pode:
- Selecionar categorias existentes (ordenadas por uso)
- Criar novas categorias on-the-fly (digitando no autocomplete)
- Excluir categorias nao usadas (swipe-left)

#### Bootstrap: Categorias Iniciais

Quando o modulo financeiro e ativado pela primeira vez (ou durante onboarding), o `BootstrapService` cria categorias iniciais sugeridas por direction.

**Adicionar ao bootstrap do segmento** (`segments/{segmentId}/bootstrap/`):

```javascript
// firebase/functions/seed/financial-bootstrap.js
const { t } = require('./helpers');

module.exports = {
  financialCategories: {
    expense: [
      { value: t('Aluguel', 'Rent', 'Alquiler'), icon: 'house' },
      { value: t('Agua, luz, internet', 'Utilities', 'Servicios'), icon: 'bolt' },
      { value: t('Salarios', 'Salaries', 'Salarios'), icon: 'person_2' },
      { value: t('Material/Suprimentos', 'Supplies', 'Suministros'), icon: 'cube_box' },
      { value: t('Manutencao', 'Maintenance', 'Mantenimiento'), icon: 'wrench' },
      { value: t('Marketing', 'Marketing', 'Marketing'), icon: 'megaphone' },
      { value: t('Impostos/Taxas', 'Taxes', 'Impuestos'), icon: 'doc_text' },
      { value: t('Seguros', 'Insurance', 'Seguros'), icon: 'shield' },
      { value: t('Transporte', 'Transport', 'Transporte'), icon: 'car' },
      { value: t('Outros', 'Other', 'Otros'), icon: 'ellipsis' },
    ],
    income: [
      { value: t('Servicos', 'Services', 'Servicios'), icon: 'wrench' },
      { value: t('Venda de produtos', 'Product Sales', 'Venta de productos'), icon: 'cube_box' },
      { value: t('Contratos', 'Contracts', 'Contratos'), icon: 'doc_on_doc' },
      { value: t('Outras receitas', 'Other Income', 'Otros ingresos'), icon: 'ellipsis' },
    ],
  },
};
```

**Execucao no `BootstrapService`:**

```dart
Future<void> bootstrapFinancialCategories(String companyId, String locale) async {
  final bootstrapData = await getFinancialBootstrapData(locale);

  // Criar categorias de despesa
  for (final cat in bootstrapData.expenseCategories) {
    await accumulatedValueRepo.use(
      companyId,
      'expenseCategory',  // fieldType
      cat.value,          // valor localizado
    );
  }

  // Criar categorias de receita
  for (final cat in bootstrapData.incomeCategories) {
    await accumulatedValueRepo.use(
      companyId,
      'incomeCategory',
      cat.value,
    );
  }
}
```

> **Nota:** O bootstrap cria as categorias com `usageCount: 1`. Conforme o usuario vai usando, as mais frequentes sobem no ranking automaticamente. Se o usuario nunca usar "Seguros", essa categoria fica no fim da lista. Se criar "Combustivel" e usar 20 vezes, ela sobe para o topo.

#### UI: Picker de Categoria

O picker usa o `AccumulatedValueListScreen` existente, filtrado por `fieldType`:

```dart
// No formulario de entry
Future<void> _selectCategory(BuildContext context) async {
  final fieldType = entry.direction == FinancialEntryDirection.payable
      ? 'expenseCategory'
      : 'incomeCategory';

  final value = await Navigator.pushNamed(
    context,
    '/accumulated_value_list',
    arguments: {
      'fieldType': fieldType,
      'title': context.l10n.category,
      'currentValue': entry.category,
      'allowClear': true,
    },
  );
  if (value != null) {
    setState(() => entry.category = value as String);
  }
}
```

**Alternativa visual (grid de icones):**

Para o MVP, o picker pode usar o `AccumulatedValueListScreen` padrao (lista com busca). Na Fase 2+, pode evoluir para um grid de icones (como descrito na secao de UX) que carrega as categorias do AccumulatedValue + icone mapeado:

```dart
// Mapeamento de icone por categoria (fallback para icone generico)
static const _categoryIcons = <String, IconData>{
  'Aluguel': CupertinoIcons.house,
  'Material/Suprimentos': CupertinoIcons.cube_box,
  'Salarios': CupertinoIcons.person_2,
  // ... fallback
};

IconData getCategoryIcon(String category) {
  return _categoryIcons[category] ?? CupertinoIcons.tag;
}
```

#### Vantagens sobre categorias hardcoded

| Aspecto | Hardcoded | AccumulatedValue |
|---------|-----------|-----------------|
| Personalizar | Nao (codigo fixo) | Sim (usuario cria/exclui) |
| Localizar | Precisa de i18n no enum | Ja localizado no bootstrap |
| Ranking | Ordem fixa | Ordenado por uso real |
| Segmento | Mesmo para todos | Bootstrap customizado por segmento |
| Migrar | Requer deploy | Apenas Firestore |
| Relatórios | Group by enum fixo | Group by valor texto |

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

// Estorno de transferencia: reverte ambos os payments do grupo
Future<void> reverseTransfer(FinancialPayment original, String reason) async {
  final groupPayments = await paymentRepo.query([
    QueryArgs('transferGroupId', original.transferGroupId),
    QueryArgs('status', 'completed'),
  ]);

  final batch = FirebaseFirestore.instance.batch();
  final now = DateTime.now();

  for (final payment in groupPayments) {
    // Criar payment reverso para cada lado
    final reversalRef = paymentsCollection.doc();
    batch.set(reversalRef, {
      ...payment.toJson(),
      'id': reversalRef.id,
      'status': 'completed',
      'reversedPaymentId': payment.id,
      'reversalReason': reason,
      'paymentDate': now,
      'description': 'Estorno: ${payment.description}',
      'transferDirection': payment.transferDirection == 'out' ? 'in' : 'out',
      'createdAt': now,
    });

    // Marcar original como estornado
    batch.update(paymentRef(payment.id), {
      'status': 'reversed',
      'reversedByPaymentId': reversalRef.id,
      'reversedAt': now,
    });

    // Reverter saldo da conta
    final balanceChange = payment.transferDirection == 'out'
        ? payment.amount   // Devolver ao remetente
        : -payment.amount; // Retirar do destinatario
    batch.update(accountRef(payment.accountId), {
      'currentBalance': FieldValue.increment(balanceChange),
    });
  }

  await batch.commit();
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
    'transferDirection': 'out',
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
    'transferDirection': 'in',
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

#### Picker de Categoria

**MVP (Fase 1):** Usa o `AccumulatedValueListScreen` existente -- lista com busca e autocomplete. O usuario pode selecionar categorias do bootstrap ou criar novas digitando.

```dart
// Abre o picker de categorias (AccumulatedValue)
final fieldType = entry.direction == FinancialEntryDirection.payable
    ? 'expenseCategory'
    : 'incomeCategory';

final value = await Navigator.pushNamed(context, '/accumulated_value_list', arguments: {
  'fieldType': fieldType,
  'title': context.l10n.category,
  'currentValue': entry.category,
  'allowClear': true,
});
```

**Evolucao (Fase 2+):** Grid de icones que carrega categorias do AccumulatedValue + mapeamento de icone. As mais usadas aparecem primeiro (ordenadas por `usageCount`). Botao "+ Nova" no final do grid para criar categoria custom.

```dart
// Grid carregado dinamicamente do AccumulatedValue
Widget _buildCategoryGrid(FinancialEntryDirection direction) {
  final fieldType = direction == FinancialEntryDirection.payable
      ? 'expenseCategory' : 'incomeCategory';

  return StreamBuilder<List<AccumulatedValue>>(
    stream: accRepo.streamAll(companyId, fieldType),
    builder: (context, snapshot) {
      final categories = snapshot.data ?? [];
      return Wrap(
        spacing: 12, runSpacing: 12,
        children: [
          ...categories.map((cat) => _buildCategoryChip(cat)),
          _buildAddNewChip(),  // "+ Nova categoria"
        ],
      );
    },
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

**Desconto:**
- Toggle "Conceder desconto" no half-sheet (colapsado por padrao)
- Ao ativar, campo de valor do desconto aparece
- O desconto e registrado no payment (`discount`) e na entry (`discountAmount`)
- Entry e marcada como `paid` se `paidAmount + discountAmount >= amount` (evita saldo residual eterno)

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

## Feature Flag: `useFinancialManagement`

O modulo financeiro completo e **opcional** e controlado por um feature flag no modelo Company, seguindo o mesmo padrao de `useContracts`, `useDeviceManagement`, etc.

### Flag no Company Model

```dart
class Company extends BaseAudit {
  // ... flags existentes
  bool? fieldService;
  bool? useScheduling;
  bool? useDeviceManagement;
  bool? useContracts;
  bool? useFinancialManagement;  // NOVO -- default: false
}
```

### Inicializacao

Em `auth_wrapper.dart` (`_SegmentLoader`), resolver o flag com default `false`:

```dart
final bool useFinancialManagement = companyData?['useFinancialManagement'] as bool? ?? false;

segmentProvider.setCompanyConfig(
  // ... flags existentes
  useFinancialManagement: useFinancialManagement,
);
```

Em `segment_config_service.dart` e `segment_config_provider.dart`, adicionar:

```dart
bool _useFinancialManagement = false;
bool get useFinancialManagement => _useFinancialManagement;
```

### O que muda com o flag

| Aspecto | `false` (padrao -- modo simples) | `true` (modulo completo) |
|---------|----------------------------------|--------------------------|
| **Tab Financeiro** | Dashboard de faturamento OS (como hoje) | Extrato financeiro (nova tela principal) |
| **Pagamento na OS** | `PaymentTransaction` direto na OS | Mesmo + sync bidirecional com entries |
| **Contas a pagar** | Nao disponivel | Disponivel |
| **Contas bancarias** | Nao disponivel | Disponivel |
| **Parcelas** | Nao disponivel | Disponivel |
| **Estornos** | Nao disponivel | Disponivel |
| **Transferencias** | Nao disponivel | Disponivel |
| **Relatorios** | Dashboard simples OS (como hoje) | DRE, fluxo projetado, despesas por categoria |
| **FAB na tab** | Nao tem | Nova Despesa / Novo Recebimento |
| **API /financial/** | Nao disponivel | Disponivel |
| **Bot financeiro** | Nao disponivel | Disponivel |
| **Dados Firestore** | Nenhuma colecao financeira | 3 colecoes (accounts, entries, payments) |
| **Onboarding** | Nao aparece | Fluxo de 3 passos na primeira visita |
| **Badge vencidas** | Nao aparece | Badge vermelho na tab |

### O que NAO muda

- Permissoes RBAC continuam funcionando (admin/gerente veem financas, tecnico nao)
- Dashboard de faturamento OS continua acessivel (via botao "Relatorios" no extrato, ou como tela principal se flag desligado)
- `PaymentTransaction` na OS continua funcionando normalmente
- Nenhuma migracao de dados necessaria
- **Zero impacto para quem nao ativa** -- o app continua exatamente como hoje

### Aplicacao no Codigo

**Tab Financeiro (navigation_controller.dart):**

```dart
// Conteudo da tab muda baseado no flag
Widget _buildFinancialTab(BuildContext context) {
  final config = Provider.of<SegmentConfigProvider>(context);

  if (config.useFinancialManagement) {
    return FinancialStatementScreen();  // Extrato completo
  } else {
    return FinancialDashboardSimple();  // Dashboard OS (como hoje)
  }
}
```

**Order Store -- sync condicional:**

```dart
// Sync com financeiro so acontece se o modulo estiver ativo
Future<void> _onOrderStatusChanged(Order order) async {
  // ... logica existente de status

  if (SegmentConfigService().useFinancialManagement) {
    await _syncFinancialEntry(order);  // Cria/atualiza entry no financeiro
  }
}
```

**Formulario de OS -- indicador de sync:**

```dart
// Na tela de pagamento da OS, mostrar link para o financeiro se ativo
if (config.useFinancialManagement && entry != null)
  CupertinoButton(
    child: Text(context.l10n.viewInFinancial),
    onPressed: () => Navigator.pushNamed(context, '/financial/entry', arguments: entry),
  ),
```

**API -- guard no endpoint:**

```typescript
// No financial.routes.ts -- verificar se modulo esta ativo
router.use(async (req, res, next) => {
  const company = await getCompanyDoc(req.auth.companyId);
  if (!company.useFinancialManagement) {
    return res.status(403).json({
      success: false,
      error: { code: 'MODULE_DISABLED', message: 'Financial management module is not enabled' }
    });
  }
  next();
});
```

### Ativacao pelo Usuario

O admin ativa o modulo em **Configuracoes da Empresa** (`company_form_screen.dart`):

```dart
// Secao de Features no formulario da empresa
CupertinoListSection.insetGrouped(
  header: Text(context.l10n.features.toUpperCase()),
  children: [
    // ... toggles existentes (fieldService, scheduling, etc.)
    _buildFeatureToggle(
      title: context.l10n.financialManagement,
      subtitle: context.l10n.financialManagementDescription,
      // "Gestao completa de despesas, receitas, contas e relatorios"
      value: _company!.useFinancialManagement ?? false,
      onChanged: (value) {
        setState(() => _company!.useFinancialManagement = value);
        if (value) {
          // Primeira ativacao: executar bootstrap de categorias
          _bootstrapFinancialIfNeeded();
        }
      },
    ),
  ],
),
```

### Bootstrap na Primeira Ativacao

Quando o admin ativa o flag pela primeira vez:

1. **Criar categorias iniciais** via `bootstrapFinancialCategories()` (AccumulatedValue)
2. **Mostrar onboarding** na proxima vez que abrir a tab Financeiro (criar conta, saldo inicial)
3. **NAO criar dados retroativos** -- OS existentes nao geram entries automaticamente

Para importar OS antigas: botao opcional "Importar OS anteriores" na tela de configuracoes (gera entries receivable para OS aprovadas sem entry vinculada).

### Firestore

```
/companies/{companyId}/
{
  "useFinancialManagement": false,  // default
  // ... outros campos
}
```

Nenhum indice adicional necessario para o flag (campo simples no documento da empresa).

---

## Permissoes (RBAC)

> **Nota:** Permissions controlam **quem** pode ver/editar. O feature flag controla **se** o modulo esta disponivel. Ambos devem ser satisfeitos: `useFinancialManagement == true` E usuario tem permission adequada.

### Novas Permissions

| Permission | Descricao | Requer flag ativo? |
|------------|-----------|-------------------|
| `manageFinancialEntries` | CRUD contas a pagar/receber | Sim |
| `manageFinancialAccounts` | CRUD contas bancarias | Sim |
| `viewFinancialStatement` | Visualizar extrato (somente leitura) | Sim |
| `viewFinancialReports` | Dashboard de faturamento OS (existente) | Nao (funciona sem flag) |

### Acesso por Perfil

| Perfil | Dashboard OS (sem flag) | Extrato (com flag) | Gerenciar Entries | Gerenciar Contas |
|--------|------------------------|--------------------|--------------------|------------------|
| Admin | sim | sim | sim | sim |
| Gerente | sim | sim | sim | sim |
| Supervisor | nao | nao | nao | nao |
| Consultor | nao | nao | nao | nao |
| Tecnico | nao | nao | nao | nao |

As permissoes existentes (`viewPrices`, `viewBilling`, `viewFinancialReports`) continuam controlando o acesso ao dashboard de faturamento da OS independente do flag.

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
| Despesa por Categoria | Agrupamento de expenses (completed) por category (dinamico via AccumulatedValue) | `financialPayments` |

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

**Calculo:** Agrupa payments `completed` do periodo por `category`, separados por `type` (income/expense). Usa `entry.competenceDate` (default = `dueDate`) para determinar o periodo de competencia. Isso permite regime de competencia: aluguel de marco pago em abril aparece no DRE de marco.

> **Regime de caixa vs competencia:** O extrato sempre mostra por `paymentDate` (regime de caixa -- quando o dinheiro movimentou). O DRE agrupa por `competenceDate` (regime de competencia -- a qual periodo a despesa/receita pertence). Com um campo simples, o sistema suporta ambos.

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

## API: Endpoints Cloud Functions

O modulo financeiro expoe endpoints REST via Cloud Functions, seguindo os mesmos padroes do sistema atual (`orders.routes.ts`, `analytics.routes.ts`).

### Arquitetura

```
firebase/functions/src/
  |-- routes/
  |     |-- v1/financial.routes.ts      <- Rotas API Key + Bearer
  |     +-- bot/financial.routes.ts     <- Rotas Bot (Fase 4)
  |-- services/
  |     +-- financial.service.ts        <- Logica de negocio
  |-- models/
  |     +-- types.ts                    <- Tipos financeiros (adicionar)
  +-- utils/
        +-- validation.utils.ts         <- Schemas Zod (adicionar)
```

**Middleware reutilizado:**
- `apiKeyAuth` / `bearerAuth` -- autenticacao (existente)
- `resolveCompanyContext` -- contexto multi-tenant (existente)
- `apiCoreLimiter` / `appLimiter` -- rate limiting (existente)

**Servicos reutilizados:**
- `firestore.service.ts` -- `getTenantCollection()`, `paginatedQuery()`, `getDocument()`
- `analytics.service.ts` -- calculo de periodos, formatacao de datas

**Registro em `index.ts`:**

```typescript
import financialRoutes from './routes/v1/financial.routes';
import botFinancialRoutes from './routes/bot/financial.routes';

// API Key (integracoes externas)
app.use('/v1/financial', apiCoreLimiter, apiKeyAuth, resolveCompanyContext, financialRoutes);

// Bearer (Flutter app)
app.use('/v1/app/financial', appLimiter, bearerAuth, resolveCompanyContext, financialRoutes);

// Bot (Fase 4)
app.use('/bot/financial', botLimiter, botAuth, resolveCompanyContext, botFinancialRoutes);
```

### Rotas v1 -- Contas Bancarias

| Metodo | Rota | Descricao | Fase |
|--------|------|-----------|------|
| GET | /v1/financial/accounts | Listar contas ativas | 2 |
| GET | /v1/financial/accounts/:id | Detalhe da conta com saldo | 2 |
| POST | /v1/financial/accounts | Criar conta | 2 |
| PATCH | /v1/financial/accounts/:id | Atualizar conta | 2 |

**GET /v1/financial/accounts**

```typescript
// Request
GET /v1/financial/accounts?active=true

// Response
{
  "success": true,
  "data": [
    {
      "id": "acc456",
      "name": "Conta Corrente Itau",
      "type": "bank",
      "currentBalance": 12500.00,
      "initialBalance": 5000.00,
      "currency": "BRL",
      "color": "#1E88E5",
      "icon": "bank",
      "active": true,
      "isDefault": true
    }
  ],
  "summary": {
    "totalBalance": 15420.00,
    "accountCount": 3
  }
}
```

**POST /v1/financial/accounts**

```typescript
// Zod Schema
const createAccountSchema = z.object({
  name: z.string().min(1).max(200),
  type: z.enum(['bank', 'cash', 'creditCard', 'digitalWallet']),
  initialBalance: z.number().default(0),
  currency: z.string().default('BRL'),
  color: z.string().optional(),
  icon: z.string().optional(),
  isDefault: z.boolean().default(false),
});
```

### Rotas v1 -- Entries (Contas a Pagar/Receber)

| Metodo | Rota | Descricao | Fase |
|--------|------|-----------|------|
| GET | /v1/financial/entries | Listar entries com filtros | 1 |
| GET | /v1/financial/entries/:id | Detalhe com payments vinculados | 1 |
| POST | /v1/financial/entries | Criar entry | 1 |
| PATCH | /v1/financial/entries/:id | Atualizar entry | 1 |
| DELETE | /v1/financial/entries/:id | Soft-delete | 1 |
| POST | /v1/financial/entries/:id/pay | Pagar entry (WriteBatch) | 1 |

**GET /v1/financial/entries**

```typescript
// Request (cursor-based pagination -- mesmo padrao do OrderRepositoryV2)
GET /v1/financial/entries?direction=payable&status=pending&startDate=2026-03-01&endDate=2026-03-31&limit=20

// Zod Schema
const listEntriesSchema = z.object({
  direction: z.enum(['payable', 'receivable']).optional(),
  status: z.enum(['pending', 'paid', 'cancelled']).optional(),
  category: z.string().optional(),
  startDate: z.string().optional(),  // dueDate range
  endDate: z.string().optional(),
  accountId: z.string().optional(),
  installmentGroupId: z.string().optional(),
  limit: z.coerce.number().min(1).max(100).default(20),
  cursor: z.string().optional(),  // ID do ultimo documento (cursor-based, nao offset)
});

// Response
{
  "success": true,
  "data": [
    {
      "id": "entry123",
      "direction": "payable",
      "status": "pending",
      "description": "Aluguel escritorio marco",
      "amount": 2500.00,
      "paidAmount": 0.00,
      "dueDate": "2026-04-10T00:00:00Z",
      "category": "rent",
      "account": { "id": "acc456", "name": "Conta Corrente", "type": "bank" },
      "supplier": "Imobiliaria XYZ",
      "installmentNumber": null,
      "installmentTotal": null,
      "createdAt": "2026-03-27T10:00:00Z"
    }
  ],
  "pagination": { "limit": 20, "hasMore": true, "nextCursor": "entry456" }
}
```

**POST /v1/financial/entries**

```typescript
// Request
POST /v1/financial/entries
{
  "direction": "payable",
  "description": "Aluguel escritorio abril",
  "amount": 2500.00,
  "dueDate": "2026-04-10T00:00:00Z",
  "category": "rent",
  "accountId": "acc456",
  "supplier": "Imobiliaria XYZ",
  "notes": "Ref: contrato 2024",
  "installments": null
}

// Zod Schema
const createEntrySchema = z.object({
  direction: z.enum(['payable', 'receivable']),
  description: z.string().min(1).max(500),
  amount: z.number().min(0.01).max(999999999.99),
  dueDate: z.string(),  // ISO 8601
  category: z.string().max(200).optional(),  // Valor livre (AccumulatedValue, nao enum)
  accountId: z.string().optional(),
  customerId: z.string().optional(),   // para receivable
  supplier: z.string().max(500).optional(),  // para payable
  notes: z.string().max(2000).optional(),
  tags: z.array(z.string()).max(10).optional(),
  installments: z.object({
    count: z.number().min(2).max(60),
  }).optional(),
  recurrence: z.object({
    frequency: z.enum(['daily', 'weekly', 'monthly', 'yearly']),
    interval: z.number().min(1).max(12).default(1),
    endDate: z.string().optional(),
  }).optional(),
});
```

**POST /v1/financial/entries/:id/pay**

```typescript
// Request
POST /v1/financial/entries/entry123/pay
{
  "amount": 2500.00,
  "accountId": "acc456",
  "paymentMethod": "pix",
  "paymentDate": "2026-03-28T14:30:00Z",
  "description": "Pagamento aluguel",
  "notes": null
}

// Zod Schema
const payEntrySchema = z.object({
  amount: z.number().min(0.01),
  accountId: z.string().min(1),
  paymentMethod: z.enum(['pix', 'cash', 'creditCard', 'debitCard', 'transfer', 'check', 'other']),
  paymentDate: z.string().optional(),  // default: now
  description: z.string().max(500).optional(),
  notes: z.string().max(2000).optional(),
});

// Response
{
  "success": true,
  "data": {
    "payment": { "id": "pay789", "type": "expense", "amount": 2500.00, ... },
    "entry": { "id": "entry123", "status": "paid", "paidAmount": 2500.00, ... },
    "account": { "id": "acc456", "currentBalance": 10000.00 }
  }
}

// Internamente: WriteBatch atomico (entry + payment + account)
```

### Rotas v1 -- Payments (Extrato)

| Metodo | Rota | Descricao | Fase |
|--------|------|-----------|------|
| GET | /v1/financial/payments | Listar payments (extrato) | 1 |
| GET | /v1/financial/payments/:id | Detalhe do payment | 1 |
| POST | /v1/financial/payments/:id/reverse | Estornar payment | 3 |

**GET /v1/financial/payments**

```typescript
// Request
GET /v1/financial/payments?startDate=2026-03-01&endDate=2026-03-31&type=expense&limit=20

// Zod Schema
const listPaymentsSchema = z.object({
  type: z.enum(['income', 'expense', 'transfer']).optional(),
  status: z.enum(['completed', 'reversed']).optional(),
  accountId: z.string().optional(),
  startDate: z.string().optional(),
  endDate: z.string().optional(),
  limit: z.coerce.number().min(1).max(100).default(20),
  cursor: z.string().optional(),  // cursor-based pagination
});

// Response
{
  "success": true,
  "data": [ /* payments ordered by paymentDate desc */ ],
  "pagination": { "limit": 20, "hasMore": true, "nextCursor": "pay456" }
}
```

### Rotas v1 -- Resumo e Transferencias

| Metodo | Rota | Descricao | Fase |
|--------|------|-----------|------|
| GET | /v1/financial/summary | KPIs do periodo | 1 |
| GET | /v1/financial/overdue | Entries vencidas | 1 |
| POST | /v1/financial/transfers | Transferencia entre contas | 2 |

**GET /v1/financial/summary**

```typescript
// Request
GET /v1/financial/summary?startDate=2026-03-01&endDate=2026-03-31

// Response
{
  "success": true,
  "data": {
    "period": { "start": "2026-03-01", "end": "2026-03-31", "label": "Marco 2026" },
    "balance": {
      "total": 15420.00,
      "byAccount": [
        { "id": "acc456", "name": "Conta Corrente", "balance": 12500.00 },
        { "id": "acc789", "name": "Caixa", "balance": 2920.00 }
      ]
    },
    "income": { "total": 12200.00, "count": 28 },
    "expense": { "total": 8150.00, "count": 19 },
    "profit": 4050.00,
    "margin": 33.2,
    "pending": {
      "payable": { "total": 5300.00, "count": 8 },
      "receivable": { "total": 3200.00, "count": 5 },
      "overdue": { "total": 1200.00, "count": 2 }
    }
  }
}
```

**POST /v1/financial/transfers**

```typescript
// Request
POST /v1/financial/transfers
{
  "fromAccountId": "acc789",
  "toAccountId": "acc456",
  "amount": 1000.00,
  "description": "Deposito caixa para banco",
  "paymentDate": "2026-03-28T10:00:00Z"
}

// Internamente: WriteBatch atomico (2 payments + 2 accounts)
```

### Rotas Bot (Fase 4)

| Metodo | Rota | Descricao |
|--------|------|-----------|
| GET | /bot/financial/summary | Resumo financeiro formatado para WhatsApp |
| GET | /bot/financial/overdue | Lista de contas vencidas |

**GET /bot/financial/summary**

```typescript
// Request
GET /bot/financial/summary?startDate=2026-03-28&endDate=2026-03-28

// Response (formatado para contexto do bot)
{
  "success": true,
  "data": {
    "period": "Hoje, 28/03/2026",
    "balance": 15420.00,
    "income": 2150.00,
    "expense": 450.00,
    "profit": 1700.00,
    "overdueCount": 2,
    "overdueTotal": 1200.00,
    "formatContext": { "locale": "pt-BR", "currency": "BRL" }
  }
}
```

### Permissoes nos Endpoints

| Rota | Roles permitidos |
|------|-----------------|
| GET (leitura) | admin, manager (ou quem tiver `viewFinancialStatement`) |
| POST/PATCH/DELETE (escrita) | admin, manager (ou quem tiver `manageFinancialEntries`) |
| Accounts (escrita) | admin, manager (ou quem tiver `manageFinancialAccounts`) |

---

## Bot: Comandos Financeiros

> **Fase de implementacao:** Apenas Fase 4 (apos modulo completo com relatorios e API pronta).

O bot Pratico (WhatsApp) ganha acesso a dados financeiros via endpoints `GET /bot/financial/*`. O bot **nao acessa Firestore direto** -- tudo passa pela API.

### Comandos Naturais

O bot interpreta linguagem natural e mapeia para endpoints:

| Comando do usuario | Endpoint | Resposta |
|--------------------|----------|----------|
| "quanto ganhei hoje?" | `GET /bot/financial/summary?startDate=HOJE&endDate=HOJE` | Entradas + Saidas + Lucro do dia |
| "quanto ganhei este mes?" | `GET /bot/financial/summary?startDate=INICIO_MES&endDate=FIM_MES` | Resumo mensal |
| "tem conta vencida?" | `GET /bot/financial/overdue` | Lista de entries overdue com valores |
| "resumo financeiro" | `GET /bot/financial/summary` | Resumo completo: saldo + entradas + saidas + vencidas |
| "qual meu saldo?" | `GET /bot/financial/summary` | Saldo total + saldo por conta |

### Automacoes CRON

Configurar em `backend/bot/workspace/cron/jobs.json`:

```json
[
  {
    "name": "daily_financial_summary",
    "schedule": "0 18 * * 1-6",
    "description": "Resumo financeiro diario as 18h (seg-sab)",
    "enabled": false,
    "action": "Envie o resumo financeiro do dia para o dono"
  },
  {
    "name": "overdue_alert",
    "schedule": "0 9 * * 1-5",
    "description": "Alerta de contas vencendo hoje/amanha as 9h (seg-sex)",
    "enabled": false,
    "action": "Verifique se tem contas vencendo hoje ou amanha e avise o dono"
  },
  {
    "name": "weekly_financial_report",
    "schedule": "0 10 * * 1",
    "description": "Resumo financeiro semanal toda segunda as 10h",
    "enabled": false,
    "action": "Envie o resumo financeiro da semana passada"
  }
]
```

> **Nota:** Todas as automacoes comecam desabilitadas (`enabled: false`). O usuario ativa via configuracao do bot.

### Integracao com Cobranca

O bot ja tem logica de cobranca amigavel (SOUL.md). Com o modulo financeiro, a cobranca pode ser mais inteligente:

1. Bot consulta `GET /bot/financial/overdue`
2. Identifica entries receivable vencidas com `customer` vinculado
3. Sugere ao dono: "Joao tem R$350 pendente da OS #142 (venceu em 25/03). Quer que eu envie uma mensagem?"
4. Se autorizado, envia mensagem amigavel ao cliente

**Arquivos a modificar (Fase 4):**
- `backend/bot/workspace/skills/praticos/references/api-endpoints.md` -- adicionar endpoints financeiros
- `backend/bot/workspace/cron/jobs.json` -- configurar automacoes
- `firebase/functions/src/routes/bot/financial.routes.ts` -- criar rotas bot

---

## Site: Documentacao Publica

### Estrategia

Criar artigo **separado** `gestao-financeira` no site Eleventy. O artigo `financeiro` existente continua documentando o sistema de pagamento na OS (sistema atual). O novo artigo cobre o modulo financeiro completo.

### Arquivos a Criar

| Arquivo | Descricao |
|---------|-----------|
| `firebase/hosting/src/_data/docs/gestao-financeira.json` | Conteudo trilingual (pt/en/es) |
| `firebase/hosting/src/docs/gestao-financeira.njk` | Template portugues |
| `firebase/hosting/src/docs/gestao-financeira-en.njk` | Template ingles |
| `firebase/hosting/src/docs/gestao-financeira-es.njk` | Template espanhol |

### Arquivo a Modificar

- `firebase/hosting/src/_data/docs.json` -- registrar no hub com badge "Novo"

### Secoes do Artigo

| # | Secao | Conteudo | Fase |
|---|-------|----------|------|
| 1 | Visao geral | O que o modulo faz, diferenca do sistema de pagamento na OS | 1 |
| 2 | Extrato financeiro | Como ver o que entrou e saiu, navegacao por mes, filtros | 1 |
| 3 | Registrar despesas | Passo a passo: criar despesa, pagar, ver no extrato | 1 |
| 4 | Contas bancarias | Como criar contas, saldo, reconciliacao | 2 |
| 5 | Transferencias | Como mover dinheiro entre contas | 2 |
| 6 | Recebimentos | Manual + automatico via OS, link com OS | 3 |
| 7 | Parcelas | Como parcelar, progresso, pagar parcelas | 3 |
| 8 | Relatorios | DRE, fluxo projetado, graficos | 4 |
| 9 | Permissoes | Quem pode ver, quem pode editar (tabela) | 1 |
| 10 | Perguntas frequentes | FAQ com duvidas comuns | 1+ |

### Padrao a Seguir

Usar o mesmo formato de `firebase/hosting/src/_data/docs/procedimentos.json`:
- Secoes com `id`, `title`, `intro`
- Componentes: `features`, `infoCard`, `subsections`, `statusCards`, `table`, `faq`
- Trilingual: `pt`, `en`, `es` no mesmo JSON

### Registro no Hub

```json
// Adicionar em firebase/hosting/src/_data/docs.json > categories
{
  "title": "Gestao Financeira",
  "description": "Controle completo de despesas, recebimentos, contas bancarias e relatorios financeiros",
  "href": "gestao-financeira.html",
  "linkText": "Ver documentacao ->",
  "badge": "Novo",
  "icon": "<svg>...</svg>"
}
```

---

## Documentacao: Checklist

### Atualizar Existentes

| Arquivo | Alteracao |
|---------|----------|
| `docs/FINANCEIRO.md` | Adicionar nota no topo: "Para o novo modulo financeiro completo (contas a pagar/receber, extrato, parcelas, relatorios), ver `docs/FINANCIAL_MODULE.md`" |
| `CLAUDE.md` | Adicionar na secao "Documentacao Adicional": `docs/FINANCIAL_MODULE.md - Modulo financeiro completo (contas, extrato, parcelas, relatorios)` |

### Criar Durante Implementacao

| Arquivo | Quando | Conteudo |
|---------|--------|----------|
| Endpoints inline no FINANCIAL_MODULE.md | Fase 1+ | Referencia de API (ja documentada acima) |
| `api-endpoints.md` (bot) | Fase 4 | Endpoints financeiros para o bot |

### Gerar Apos Build

```bash
cd firebase/hosting && npm run build  # Gerar site apos alterar docs publicos
```

---

## Fases de Implementacao

### Visao Geral

O modulo esta organizado em **4 milestones de produto** (o que o usuario ganha) e **sprints tecnicos** dentro de cada milestone (como a IA implementa). Cada sprint e uma unidade de trabalho independente, otimizada para execucao em uma unica sessao de IA.

**Principios dos sprints:**

- **1 stack por sprint** -- nao misturar Flutter com TypeScript com Nunjucks
- **Max ~8 arquivos por sprint** -- cabe no contexto sem compressao
- **1 padrao repetivel** -- todos os arquivos do sprint seguem a mesma estrutura
- **Ponto de validacao ao final** -- comando concreto que confirma sucesso
- **Independencia** -- cada sprint pode rodar em sessao separada
- **Ordem por dependencia tecnica** -- camada de dados antes de UI

**Requisitos criticos (aplicar desde o Sprint 1):**

- Todas as operacoes multi-documento usam `WriteBatch`
- Soft delete (`deletedAt`/`deletedBy`) implementado desde o inicio
- Status do payment (`completed`/`reversed`) presente desde o inicio
- Nomenclatura em ingles no codigo, portugues na UI (`context.l10n`)
- `FormatService` para toda formatacao de moeda/data
- Cores dinamicas com `.resolveFrom(context)` para dark mode

```
Milestone 1: Despesas + Extrato         Sprints 1-8      "Registra despesa, paga, ve no extrato"
Milestone 2: Contas Bancarias           Sprints 9-10     "Controla saldo, transfere entre contas"
Milestone 3: Recebiveis + Sync + Estornos  Sprints 11-13 "Recebe da OS, estorna, tudo sincronizado"
Milestone 4: Recorrencia + Relatorios   Sprints 14-15    "Despesa fixa repete, relatorios visuais"
Separados: API, Bot, Docs, Infra        Sprints API/Bot/Docs  "Outro stack, roda em paralelo"
```

---

### Milestone 1 - Despesas + Extrato

**Resultado:** Usuario registra despesas (simples e parceladas), paga com 2 toques, e ve no extrato.

#### Sprint 1 - Models + Enums + Build Runner -- CONCLUIDO (31/03/2026)

**Objetivo:** Criar toda a camada de dados. Zero logica, zero UI.

**Criar:**
- `lib/models/financial_account.dart` -- `FinancialAccount` + `FinancialAccountAggr` + enum `FinancialAccountType`
- `lib/models/financial_entry.dart` -- `FinancialEntry` + `FinancialEntryAggr` + enums `FinancialEntryDirection`, `FinancialEntryStatus` + classe `FinancialRecurrence`
- `lib/models/financial_payment.dart` -- `FinancialPayment` + enums `FinancialPaymentType`, `FinancialPaymentStatus`

**Padrao a copiar:** `lib/models/customer.dart` (BaseAuditCompany + @JsonSerializable + toAggr + toJson/fromJson)

**Decisoes:**
- Verificar se `PaymentMethod` ja existe em `lib/models/` -- se sim, reutilizar; se nao, criar em `lib/models/payment_method.dart` compartilhado
- `FinancialRecurrence` e sub-documento embutido (nao precisa de Aggr nem de collection propria)
- Getters computados (`remainingBalance`, `isFullyPaid`, `isOverdue`, `isInstallment`) no model, nao no store

**Validacao:**
```bash
fvm flutter pub run build_runner build --delete-conflicting-outputs  # Gera .g.dart
fvm flutter analyze  # Zero erros
```

**Arquivos:** ~3-4 | **Complexidade:** M

---

#### Sprint 2 - Repositories -- CONCLUIDO (31/03/2026)

**Objetivo:** Camada de acesso a dados. Boilerplate puro.

**Criar:**
- `lib/repositories/tenant/tenant_financial_account_repository.dart`
- `lib/repositories/tenant/tenant_financial_entry_repository.dart`
- `lib/repositories/tenant/tenant_financial_payment_repository.dart`
- `lib/repositories/v2/financial_account_repository_v2.dart`
- `lib/repositories/v2/financial_entry_repository_v2.dart`
- `lib/repositories/v2/financial_payment_repository_v2.dart`

**Padrao a copiar:** `lib/repositories/tenant/tenant_customer_repository.dart` + `lib/repositories/v2/customer_repository_v2.dart`

**Decisoes:**
- `TenantRepository<FinancialEntry>` herda tudo -- so precisa definir `collectionName` e `fromJson`
- `RepositoryV2` segue mesmo padrao do `CustomerRepositoryV2` -- queries customizadas como metodos

**Validacao:**
```bash
fvm flutter analyze  # Zero erros
```

**Arquivos:** 6 | **Complexidade:** S (boilerplate)

---

#### Sprint 3 - Stores MobX -- CONCLUIDO (31/03/2026)

**Objetivo:** Estado reativo. Apenas actions necessarias para o Milestone 1 (despesas + extrato). NAO implementar transferencia, estorno, sync ou recorrencia.

**Criar:**
- `lib/mobx/financial_account_store.dart` -- `load()`, `totalBalance` (soma de contas ativas), CRUD basico
- `lib/mobx/financial_entry_store.dart` -- `load()`, stream por direction/status/dueDate, `createEntry()`, `createInstallments()`, filtros
- `lib/mobx/financial_payment_store.dart` -- stream por paymentDate (extrato), `payEntry()` com WriteBatch atomico (entry + payment + account), KPIs do periodo (totalIncome, totalExpense, profit, margin), KPIs do dia (todayIncome, todayExpense)

**Padrao a copiar:** `lib/mobx/order_store.dart` (estrutura de streams, actions, observables)

**Decisoes:**
- `payEntry()` usa `WriteBatch` -- criar payment + atualizar entry status/paidAmount + atualizar account currentBalance
- KPIs calculados client-side no store (nao na UI) -- mesmo padrao do `FinancialDashboardSimple`
- Adicionar KPIs do dia (`todayIncome`, `todayExpense`, `todayProfit`) para o header "Hoje: +X -Y = Z"
- Stubs para metodos de fases futuras NAO devem ser criados

**Validacao:**
```bash
fvm flutter pub run build_runner build --delete-conflicting-outputs  # Gera .g.dart do MobX
fvm flutter analyze  # Zero erros
```

**Arquivos:** 3 | **Complexidade:** L

---

#### Sprint 4 - Feature Flag + Integracao -- CONCLUIDO (31/03/2026)

**Objetivo:** Ligar o modulo ao app existente. Trabalho cirurgico em arquivos existentes.

**Modificar:**
- `lib/models/company.dart` -- adicionar `bool? useFinancialManagement`
- `lib/services/segment_config_service.dart` -- adicionar getter `useFinancialManagement`
- `lib/providers/segment_config_provider.dart` -- adicionar field + setter
- `lib/screens/auth_wrapper.dart` -- resolver flag com default `false` no `_SegmentLoader`
- `lib/models/permission.dart` -- adicionar `manageFinancialEntries`, `manageFinancialAccounts`, `viewFinancialStatement`
- `lib/routes.dart` -- registrar novas rotas financeiras
- `lib/screens/menu_navigation/navigation_controller.dart` -- tab Financeiro condicional: `if (config.useFinancialManagement) FinancialStatementScreen() else FinancialDashboardSimple()`
- `lib/screens/menu_navigation/company_form_screen.dart` -- toggle na secao Features

**Padrao a copiar:** Buscar como `useContracts` ou `useDeviceManagement` sao implementados nesses mesmos arquivos e replicar o padrao exato.

**Decisoes:**
- O toggle chama `_bootstrapFinancialIfNeeded()` na primeira ativacao (Sprint 5)
- A tab condicional e o unico ponto de entrada -- nao criar menu lateral separado
- As telas financeiras ainda nao existem neste sprint -- usar placeholder temporario (`Center(child: Text('Financial'))`) para validar que o flag funciona

**Validacao:**
```bash
fvm flutter analyze  # Zero erros
# Teste manual: ligar/desligar flag em Configuracoes da Empresa, verificar que a tab muda
```

**Arquivos:** ~8 modificacoes | **Complexidade:** M (cirurgico, risco de quebrar existente)

---

#### Sprint 5 - i18n + Bootstrap de Categorias -- CONCLUIDO (31/03/2026)

**Objetivo:** Todas as strings traduzidas + categorias iniciais criadas na ativacao do modulo.

**Modificar:**
- `lib/l10n/app_pt.arb` -- adicionar todas as strings financeiras (titulos, labels, botoes, mensagens, categorias)
- `lib/l10n/app_en.arb` -- traducoes ingles
- `lib/l10n/app_es.arb` -- traducoes espanhol
- `lib/services/bootstrap_service.dart` -- adicionar `bootstrapFinancialCategories()` usando `AccumulatedValueRepository` existente

**Padrao a copiar:**
- Strings: buscar como `app_pt.arb` organiza strings de OS/customer e seguir mesma convencao de prefixo (ex: `financial_`, `financialEntry_`, etc.)
- Bootstrap: buscar como categorias de `deviceCategory`/`deviceBrand` sao criadas no bootstrap existente

**Decisoes:**
- Categorias usam `AccumulatedValue` existente -- zero codigo novo para o sistema de categorias
- Criar `expenseCategory` e `incomeCategory` como `fieldType` no AccumulatedValue
- Categorias iniciais localizadas: 10 de despesa + 4 de receita (conforme spec)
- Icones mapeados estaticamente (fallback para `CupertinoIcons.tag`)

**Validacao:**
```bash
fvm flutter gen-l10n  # Gera arquivos de traducao
fvm flutter analyze  # Zero erros
# Verificar que context.l10n.financialXxx resolve em todos os 3 idiomas
```

**Arquivos:** ~4 | **Complexidade:** M (volume de strings, precisa consistencia nos 3 idiomas)

---

#### Sprint 6 - Widgets Reutilizaveis -- CONCLUIDO (31/03/2026)

**Objetivo:** Componentes visuais isolados, sem dependencia de tela. Testavel individualmente.

**Criar:**
- `lib/screens/financial/widgets/balance_header.dart` -- saldo total + eye toggle (SharedPreferences) + resumo do dia ("Hoje: +X -Y = Z") + navegacao de mes (`< Marco 2026 >`)
- `lib/screens/financial/widgets/payment_timeline_item.dart` -- item compacto 2 linhas (descricao + valor na L1, forma + conta na L2) + icones SF Symbols por tipo
- `lib/screens/financial/widgets/payment_confirmation_sheet.dart` -- half-sheet one-tap: botao `Confirmar R$X via Pix na Conta Y` + link "Editar detalhes" para expandir campos
- `lib/screens/financial/widgets/category_picker_grid.dart` -- grid 4 colunas carregado do AccumulatedValue, ordenado por `usageCount`, botao "+ Nova" no final
- `lib/screens/financial/widgets/installment_progress_card.dart` -- card expansivel: colapsado (titulo + barra progresso), expandido (lista de parcelas com botao "Pagar" na proxima pendente)

**Padrao a copiar:** Buscar widgets existentes em `lib/screens/` que usam `CupertinoListSection.insetGrouped`, `showCupertinoModalPopup`, etc. Seguir mesma estrutura.

**Decisoes:**
- Eye toggle salva preferencia em `SharedPreferences` com chave `financial_hide_values`
- `PaymentConfirmationSheet` no modo one-tap: pre-fill de valor (remainingBalance), conta (ultima usada ou default), forma (ultima usada), data (hoje). Todos os campos pre-preenchidos aparecem como resumo texto, nao como inputs editaveis. Expandir com "Editar detalhes" mostra os inputs.
- `PaymentTimelineItem` deve suportar estado `reversed` (texto riscado, cor cinza) desde o inicio, mesmo que estorno so venha no Milestone 3
- Areas de toque minimo 44pt (HIG) em todos os botoes e alvos de toque
- Numpad com teclas grandes (48pt+) no campo de valor do half-sheet

**Validacao:**
```bash
fvm flutter analyze  # Zero erros
# Widgets compilam isoladamente (sem dependencia de tela)
```

**Arquivos:** 5 | **Complexidade:** L (criativo, precisa dos wireframes do doc como referencia)

---

#### Sprint 7 - Telas Principais -- CONCLUIDO (31/03/2026)

**Objetivo:** Montar as 2 telas finais conectando stores + widgets. Fluxo funcional end-to-end.

**Criar:**
- `lib/screens/financial/financial_statement_screen.dart` -- extrato principal: BalanceHeader + timeline de payments agrupados por data + FAB (Nova Despesa / Novo Recebimento via CupertinoActionSheet) + empty state + badges
- `lib/screens/financial/financial_entry_form_screen.dart` -- formulario 2 niveis: campos essenciais (descricao, valor grande, vencimento, grid categoria, conta default) + secao colapsada "+ Detalhes" (fornecedor, notas, anexos) + toggle "Parcelar em vezes" (stepper inline) + botao Salvar na bottom (thumb zone) + botao Salvar no nav bar

**Conectar:**
- Statement usa `FinancialPaymentStore` (stream extrato) + `FinancialAccountStore` (saldo total) + `PaymentTimelineItem` + `BalanceHeader`
- EntryForm usa `FinancialEntryStore` (createEntry/createInstallments) + `CategoryPickerGrid` + `PaymentConfirmationSheet` (ao marcar "ja paguei" ou via swipe na lista)
- Remover placeholder do Sprint 4 e apontar para telas reais

**Decisoes:**
- Direction (payable/receivable) definida pelo botao do FAB, nao por campo no form
- Titulo do form muda: "Nova Despesa" (payable) / "Novo Recebimento" (receivable)
- `competenceDate` e `tags` nao aparecem no form (automatico/invisivel)
- Timeline usa stream paginado (Firestore `limit` + `startAfterDocument`)
- Separadores por data como sticky headers

**Validacao:**
```bash
fvm flutter analyze  # Zero erros
# Teste manual: abrir app > ativar flag > tab Financeiro > criar despesa > pagar > ver no extrato
```

**Arquivos:** 2 | **Complexidade:** XL (conecta tudo, mais criativo, mais risco)

---

#### Sprint 8 - Onboarding + Polish -- CONCLUIDO (31/03/2026)

**Objetivo:** Primeira experiencia do usuario + refinamentos finais do Milestone 1.

**Modificar:**
- `lib/screens/financial/financial_statement_screen.dart` -- empty state com onboarding de 3 passos (criar conta > saldo inicial > CTA para primeira despesa), badge de vencidas na tab, swipe actions nos items
- `lib/screens/financial/financial_entry_form_screen.dart` -- recorrencia simplificada (toggle "Repetir todo mes?" que cria `recurrence.frequency: monthly, interval: 1`), link "Personalizar" para opcoes avancadas colapsadas

**Decisoes:**
- Onboarding: 3 passos rapidos conforme wireframe do doc. Cards pre-definidos para tipo de conta ("Dinheiro/Caixa", "Conta bancaria", "Pix/Carteira digital"). Criar conta com 1 toque no card.
- Badge de vencidas: contar entries com `status == pending && dueDate < now`, exibir numero no icone da tab
- Swipe-right no item do extrato: abre detalhe (neste milestone, apenas visualizacao -- swipe para pagar entry pendente vem no Sprint 11)

**Validacao:**
```bash
fvm flutter analyze  # Zero erros
# Teste manual end-to-end completo:
# 1. Ativar flag > ver onboarding > criar conta
# 2. Criar despesa simples > pagar > ver no extrato
# 3. Criar despesa parcelada > ver card expansivel > pagar parcela
# 4. Criar despesa com vencimento passado > ver badge de vencida
# 5. Testar eye toggle > valores ocultados
# 6. Verificar "Hoje: +X -Y = Z" no header
```

**Arquivos:** ~2-3 modificacoes | **Complexidade:** M

---

### Milestone 2 - Contas Bancarias

**Resultado:** Controle de saldo por conta, transferencias entre contas.

#### Sprint 9 - Telas de Contas Bancarias (CRUD)

**Objetivo:** Lista de contas com saldo + formulario de criar/editar conta.

**Criar:**
- `lib/screens/financial/financial_account_list_screen.dart` -- lista com saldo total no topo + cards por conta (icone + nome + saldo) + swipe right (transferir) + swipe left (editar) + botao [+] na nav bar
- `lib/screens/financial/financial_account_form_screen.dart` -- form simples: nome, tipo (picker com 4 opcoes), saldo inicial, cor, icone, default toggle

**Modificar:**
- `lib/screens/financial/financial_statement_screen.dart` -- adicionar icone de banco na nav bar trailing que navega para `FinancialAccountListScreen`, saldo total no header usa `FinancialAccountStore.totalBalance`

**Padrao a copiar:** Buscar tela de listagem existente no app (ex: lista de clientes ou colaboradores) para replicar estrutura de CupertinoPageScaffold + SliverList.

**Validacao:**
```bash
fvm flutter analyze
# Teste manual: criar conta > ver na lista > editar > ver saldo no extrato
```

**Arquivos:** 3 (2 criar + 1 modificar) | **Complexidade:** M

---

#### Sprint 10 - Transferencias + Account Picker

**Objetivo:** Mover dinheiro entre contas + pre-selecionar conta no form de entry.

**Criar:**
- `lib/screens/financial/widgets/transfer_sheet.dart` -- half-sheet: conta origem (pre-selecionada pelo contexto), picker conta destino, campo valor, botao "Transferir"

**Modificar:**
- `lib/mobx/financial_payment_store.dart` -- adicionar `transfer()` com WriteBatch atomico (2 payments + 2 accounts)
- `lib/screens/financial/financial_entry_form_screen.dart` -- account picker pre-selecionado com conta default (`isDefault: true`)
- `lib/mobx/financial_account_store.dart` -- reconciliacao basica: `calculateRealBalance()` compara currentBalance com soma real dos payments, alerta se divergir, botao "Corrigir saldo" (UI: "Verificar saldo")

**Validacao:**
```bash
fvm flutter analyze
# Teste manual: transferir Caixa > Banco > ver 2 payments no extrato > saldos atualizados
# Teste: forcar divergencia de saldo > ver alerta > corrigir
```

**Arquivos:** 4 (1 criar + 3 modificar) | **Complexidade:** L (WriteBatch atomico, reconciliacao)

---

### Milestone 3 - Recebiveis + Sync + Estornos

**Resultado:** Visao completa de recebiveis, pagamento por qualquer tela (OS ou financeiro), estornos com auditoria.

#### Sprint 11 - Modo Recebimento + Filtros

**Objetivo:** Form de entry em modo receivable + filtros no extrato.

**Modificar:**
- `lib/screens/financial/financial_entry_form_screen.dart` -- modo receivable: titulo "Novo Recebimento", customer picker (reutilizar picker existente de Customer), categoria de `incomeCategory`
- `lib/screens/financial/financial_statement_screen.dart` -- filtros via `CupertinoActionSheet`: Tudo, Entradas, Saidas, Transferencias. Icone de filtro na nav bar.
- `lib/screens/financial/widgets/payment_timeline_item.dart` -- swipe-right abre `PaymentConfirmationSheet` direto para entries pendentes, link `OS #142` clicavel (navega para OS)

**Validacao:**
```bash
fvm flutter analyze
# Teste manual: criar recebimento > pagar via swipe > filtrar extrato por tipo
```

**Arquivos:** 3 modificacoes | **Complexidade:** M

---

#### Sprint 12 - Sync Bidirecional OS <-> Financeiro

> **ALTO RISCO** -- Toca `OrderStore` existente. Testar exaustivamente.

**Objetivo:** OS aprovada gera entry receivable. Pagamento na OS reflete no financeiro e vice-versa.

**Modificar:**
- `lib/mobx/order_store.dart` -- adicionar `_syncFinancialEntry()` com guard `if (!useFinancialManagement) return` + `syncSource` para prevenir loop. Eventos: OS aprovada (total > 0) cria entry receivable; pagamento na OS cria payment income; OS cancelada cancela entry.
- `lib/mobx/financial_entry_store.dart` -- adicionar `_syncOrderPayment()` com `syncSource`. Evento: receivable com orderId marcado como pago cria PaymentTransaction na OS.

**Decisoes:**
- `syncSource` persistido no documento Firestore (nao flag em memoria) -- sobrevive a crash/multi-device
- Guard condicional no OrderStore: sync so executa se `SegmentConfigService().useFinancialManagement == true`
- Sync nao retroativo: OS existentes (antes da ativacao) nao geram entries automaticamente

**Validacao:**
```bash
fvm flutter analyze
# Teste manual critico (cada cenario):
# 1. Aprovar OS > verificar entry receivable criada
# 2. Pagar OS pela tela da OS > verificar payment no extrato financeiro
# 3. Pagar entry receivable pelo financeiro > verificar PaymentTransaction na OS
# 4. Cancelar OS > verificar entry cancelada
# 5. Verificar que nao ha loop (pagar pela OS nao dispara sync de volta)
# 6. Testar com flag desligado > nenhum sync acontece
```

**Arquivos:** 2 modificacoes | **Complexidade:** XL (risco alto, tocar OrderStore)

---

#### Sprint 13 - Estornos

> **ALTO RISCO** -- Atomicidade critica. Testar multi-cenario.

**Objetivo:** Reverter pagamentos com trilha de auditoria completa.

**Modificar:**
- `lib/mobx/financial_payment_store.dart` -- adicionar `reversePayment()` (WriteBatch: payment original -> reversed, criar payment reverso, reverter saldo conta, recalcular paidAmount entry) + `reverseTransfer()` (reverte ambos payments do transferGroupId)
- `lib/mobx/financial_entry_store.dart` -- adicionar `recalculatePaidAmount()` via `Transaction` do Firestore (evita race condition multi-device)
- `lib/screens/financial/widgets/payment_timeline_item.dart` -- swipe-left (vermelho) para estornar com confirmacao (motivo obrigatorio via `CupertinoAlertDialog`), estilo visual de item estornado (riscado, cinza)
- `lib/screens/financial/financial_statement_screen.dart` -- visualizacao de estornos no extrato (payment original riscado + payment reverso com badge amarelo)

**Validacao:**
```bash
fvm flutter analyze
# Teste manual critico:
# 1. Estornar pagamento de despesa > saldo da conta restaurado > entry volta para pendente
# 2. Estornar pagamento de recebimento > saldo reduzido > entry volta para pendente
# 3. Estornar transferencia > ambas contas revertidas
# 4. Tentar estornar um estorno > bloqueado (regra: sem estorno de estorno)
# 5. Estornar payment com orderId > verificar sync reverso na OS
# 6. Verificar extrato: original riscado + reverso com motivo visivel
```

**Arquivos:** 4 modificacoes | **Complexidade:** XL (atomicidade, multi-cenario)

---

### Milestone 4 - Recorrencia + Relatorios

**Resultado:** Despesas fixas repetem automaticamente, relatorios visuais.

#### Sprint 14 - Recorrencia

**Objetivo:** Lancamentos recorrentes com toggle simples + catch-up ao reabrir app.

**Modificar:**
- `lib/mobx/financial_entry_store.dart` -- adicionar `processRecurrence()` com loop de catch-up (gera entries atrasadas desde ultima abertura), prevencao de duplicacao via `lastGeneratedDate`
- `lib/screens/financial/financial_entry_form_screen.dart` -- toggle "Repetir todo mes?" visivel + link "Personalizar" que expande opcoes avancadas (frequencia, intervalo, data fim) -- colapsado por padrao

**Decisoes:**
- Geracao client-side (nao Cloud Function) -- conforme spec, aceitavel para publico-alvo que usa app diariamente
- Toggle "Repetir todo mes?" e o caso 90% -- cria `recurrence: { frequency: monthly, interval: 1, active: true }`
- Opcoes avancadas (semanal, bimestral, anual) acessiveis via "Personalizar" dentro do toggle
- `processRecurrence()` chamado no `load()` do store (ao abrir a tab financeira)

**Validacao:**
```bash
fvm flutter analyze
# Teste manual:
# 1. Criar despesa recorrente mensal > fechar app > mudar data do dispositivo +2 meses > reabrir > 2 entries geradas
# 2. Verificar que nao duplica se reabrir novamente
# 3. Pausar recorrencia > verificar que para de gerar
```

**Arquivos:** 2 modificacoes | **Complexidade:** L (logica de catch-up)

---

#### Sprint 15 - Tela de Relatorios

**Objetivo:** DRE simplificado + fluxo de caixa projetado + graficos.

**Criar:**
- `lib/screens/financial/financial_reports_screen.dart` -- tela dedicada com: DRE simplificado por periodo (receitas vs despesas por categoria, usando `competenceDate`), fluxo de caixa projetado (proximos 3 meses baseado em entries pendentes), grafico de barras entradas vs saidas por mes, grafico pizza despesas por categoria, integracao com dashboard antigo (`FinancialDashboardSimple`)

**Modificar:**
- `lib/screens/financial/financial_statement_screen.dart` -- adicionar botao "Relatorios" (icone grafico) na nav bar trailing que navega para `FinancialReportsScreen`

**Decisoes:**
- Na UI mobile, exibir como "Resumo do mes" e "Projecao" -- nunca usar termo "DRE" ou "regime de competencia"
- Fluxo projetado simplificado no mobile: apenas "Proximos 30 dias: a receber X, a pagar Y"
- Graficos podem usar `fl_chart` ou equivalente (verificar dependencia existente no pubspec)
- Dashboard antigo acessivel dentro da tela de relatorios como secao "Faturamento OS"

**Validacao:**
```bash
fvm flutter analyze
# Teste manual: extrato > botao Relatorios > ver DRE do mes > ver projecao > ver graficos
```

**Arquivos:** 2 (1 criar + 1 modificar) | **Complexidade:** L (criativo, graficos)

---

### Sprints Separados (outro stack -- rodam em paralelo)

> Estes sprints sao independentes do app Flutter e podem ser executados em sessoes/worktrees separadas. Recomenda-se rodar em paralelo com os milestones do app apos o Sprint 3 (quando os models estao definidos).

#### Sprint API-1 - Cloud Functions: Entries + Payments + Summary

**Stack:** TypeScript (Firebase Cloud Functions)

**Criar:**
- `firebase/functions/src/routes/v1/financial.routes.ts` -- rotas REST: GET/POST entries, GET payments, POST entries/:id/pay, GET summary, GET overdue
- `firebase/functions/src/services/financial.service.ts` -- logica de negocio (queries, WriteBatch, validacao)

**Modificar:**
- `firebase/functions/src/models/types.ts` -- tipos FinancialEntry, FinancialPayment, FinancialAccount
- `firebase/functions/src/utils/validation.utils.ts` -- schemas Zod (createEntrySchema, payEntrySchema, listEntriesSchema, etc.)
- `firebase/functions/src/index.ts` -- registrar rotas: `/v1/financial` (apiKey) + `/v1/app/financial` (bearer)

**Padrao a copiar:** `firebase/functions/src/routes/v1/orders.routes.ts` + `analytics.routes.ts`

**Validacao:**
```bash
cd firebase/functions && npm run build  # Compila sem erros
# Testar endpoints via curl ou Postman
```

**Arquivos:** ~5 | **Complexidade:** L

---

#### Sprint API-2 - Cloud Functions: Accounts + Transfers + Reverse

**Stack:** TypeScript

**Modificar:**
- `financial.routes.ts` -- adicionar CRUD accounts, POST transfers, POST payments/:id/reverse
- `financial.service.ts` -- logica de contas, transferencia atomica, estorno, reconciliacao

**Validacao:**
```bash
cd firebase/functions && npm run build
```

**Arquivos:** 2 modificacoes | **Complexidade:** M

---

#### Sprint Bot-1 - Endpoints Bot + CRON (Milestone 4)

**Stack:** TypeScript + Bot workspace

**Criar:**
- `firebase/functions/src/routes/bot/financial.routes.ts` -- GET summary (formatado para WhatsApp), GET overdue

**Modificar:**
- `firebase/functions/src/index.ts` -- registrar rotas bot
- `backend/bot/workspace/skills/praticos/references/api-endpoints.md` -- adicionar endpoints financeiros
- `backend/bot/workspace/cron/jobs.json` -- configurar automacoes (resumo diario 18h, alerta vencidas 9h, resumo semanal segunda 10h) -- todas `enabled: false` por padrao

**Validacao:**
```bash
cd firebase/functions && npm run build
# Testar via curl: GET /bot/financial/summary
```

**Arquivos:** ~4 | **Complexidade:** M

---

#### Sprint Docs-1 - Site Eleventy

**Stack:** Nunjucks + JSON

**Criar:**
- `firebase/hosting/src/_data/docs/gestao-financeira.json` -- conteudo trilingual (pt/en/es), secoes conforme spec
- `firebase/hosting/src/docs/gestao-financeira.njk` -- template portugues
- `firebase/hosting/src/docs/gestao-financeira-en.njk` -- template ingles
- `firebase/hosting/src/docs/gestao-financeira-es.njk` -- template espanhol

**Modificar:**
- `firebase/hosting/src/_data/docs.json` -- registrar no hub com badge "Novo"

**Padrao a copiar:** `firebase/hosting/src/_data/docs/procedimentos.json` + `firebase/hosting/src/docs/procedimentos.njk`

**Validacao:**
```bash
cd firebase/hosting && npm run build  # Gera site sem erros
# Verificar pagina gerada em public/docs/gestao-financeira.html
```

**Arquivos:** ~5 | **Complexidade:** M (volume de conteudo trilingual)

---

#### Sprint Infra-1 - Firestore Indexes + Security Rules + Storage Rules

**Stack:** JSON + Firebase config

**Modificar:**
- `firebase/firestore.indexes.json` -- adicionar ~12 indices compostos (conforme spec, secao "Indices Compostos Necessarios")
- `firebase/firestore.rules` -- adicionar rules para financialAccounts, financialEntries, financialPayments (conforme spec)
- `firebase/storage.rules` -- adicionar paths para comprovantes financeiros

**Modificar (app):**
- `docs/FINANCEIRO.md` -- adicionar nota no topo apontando para FINANCIAL_MODULE.md
- `CLAUDE.md` -- adicionar referencia na secao "Documentacao Adicional"

**Validacao:**
```bash
# Indices e rules sao validados no deploy
firebase deploy --only firestore:indexes --dry-run
firebase deploy --only firestore:rules --dry-run
firebase deploy --only storage --dry-run
```

**Arquivos:** ~5 | **Complexidade:** S (copiar da spec)

---

### Mapa de Dependencias

```
Sprint 1 (Models)
  |
  v
Sprint 2 (Repos) ---------> Sprint API-1 (Cloud Functions)
  |                                |
  v                                v
Sprint 3 (Stores) ---------> Sprint API-2
  |
  +----------+----------+
  |          |          |
  v          v          v
Sprint 4   Sprint 5   Sprint Infra-1
(Flag)     (i18n)     (Indexes/Rules)
  |          |
  +----+-----+
       |
       v
  Sprint 6 (Widgets) -----> Sprint Docs-1 (Site)
       |
       v
  Sprint 7 (Telas)
       |
       v
  Sprint 8 (Polish)
       |
  === MILESTONE 1 COMPLETO === (pausa, testar, corrigir)
       |
  Sprint 9 (Contas CRUD)
       |
       v
  Sprint 10 (Transferencias)
       |
  === MILESTONE 2 COMPLETO ===
       |
  Sprint 11 (Receivables)
       |
       v
  Sprint 12 (Sync OS) --- ALTO RISCO
       |
       v
  Sprint 13 (Estornos) --- ALTO RISCO
       |
  === MILESTONE 3 COMPLETO ===
       |
  Sprint 14 (Recorrencia)
       |
       v
  Sprint 15 (Relatorios)
       |                     Sprint Bot-1
  === MILESTONE 4 COMPLETO ===
```

**Sprints paralelizaveis** (podem rodar em worktrees separadas):
- Sprint API-1 em paralelo com Sprints 4-8 (apos Sprint 3)
- Sprint Infra-1 em paralelo com Sprints 4-8 (apos Sprint 1)
- Sprint Docs-1 em paralelo com qualquer sprint (sem dependencia tecnica)
- Sprint Bot-1 apos Sprint API-1

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

## Revisao UX Mobile-First

> **Principio:** Funcionalidade completa nos dados, simplicidade radical na interface mobile. O mesmo backend que atende o dono da oficina no celular vai atender o contador no desktop depois. Nenhuma feature foi removida nesta revisao -- todas as recomendacoes sao sobre esconder, automatizar ou defaultar na interface mobile.

### 1. Contagem de Toques por Acao

| Acao | Toques | Digitacao | Veredicto | Notas |
|------|--------|-----------|-----------|-------|
| Registrar despesa rapida | 4 | 2 campos (desc + valor) | OK | FAB > Despesa > preencher > Salvar |
| Registrar despesa com categoria | 5 | 2 campos | OK | Idem + 1 toque na categoria (grid inline) |
| Pagar conta via swipe | 2 | 0 | EXCELENTE | Swipe-right > Confirmar (pre-fill resolve tudo) |
| Pagar conta via detalhe | 3 | 0 | BOM | Tap entry > Pagar > Confirmar |
| Pagar parcela (card expandido) | 2 | 0 | EXCELENTE | Pagar (no card) > Confirmar |
| Estornar pagamento | 3 | 1 campo (motivo) | OK | Swipe-left > motivo > Confirmar |
| Transferencia entre contas | 5+ | 1 campo (valor) | ALERTA | Nav bar banco > lista > swipe > valor > Transferir |
| Parcelar despesa | 6+ | 2 campos + stepper | ACEITAVEL | Acao rara, complexidade justificada |
| Ver "quanto fiz hoje" | 2+ | 0 | ALERTA | Precisa abrir tab + interpretar KPIs mensais |

**Recomendacoes:**

- **Transferencia**: Adicionar atalho "Transferir" no long-press de uma conta no header do extrato (se houver mais de 1 conta). Reduz de 5 para 3 toques.
- **"Quanto fiz hoje"**: Adicionar resumo do dia no header do extrato (abaixo do saldo total): `Hoje: +R$800 -R$450 = +R$350`. Zero toques extras -- ja esta visivel ao abrir.
- **Pagar com half-sheet simplificado**: O half-sheet atual mostra 4 campos editaveis (valor, conta, forma, data) mesmo quando o pre-fill resolve tudo. Sugerir modo "one-tap": exibir apenas um botao `Confirmar R$ 2.500 na Conta Corrente via Pix` com link `Editar detalhes` abaixo para quem precisa mudar algo. Reduz de 2 para 1 toque no caso comum (95% das vezes).

---

### 2. Classificacao de Campos: Progressive Disclosure

> Legenda: **Sempre visivel** = usuario precisa em >70% dos casos. **Colapsado** = util em <30% dos casos, esconder em "+ Detalhes". **Automatico** = calculado/herdado, nunca aparece no form mobile (disponivel via API/web futura).

#### Formulario de Entry (Despesa/Recebimento)

| Campo | Mobile v1 | Justificativa |
|-------|-----------|---------------|
| `description` | **Sempre visivel** | Obrigatorio em 100% dos casos |
| `amount` | **Sempre visivel** | Obrigatorio, fonte grande (24pt+) |
| `dueDate` | **Sempre visivel** (default: hoje) | >70% dos casos, default resolve maioria |
| `category` | **Sempre visivel** (grid inline) | Rapido com 1 toque, ajuda relatorios |
| `account` | **Sempre visivel** (default pre-selecionado) | Obrigatorio, pre-fill resolve |
| `competenceDate` | **Automatico** (= dueDate) | Usuario mobile nao sabe o que e. Nunca mostrar. Disponivel via API/web |
| `tags` | **Automatico** (nao aparece) | <5% dos usuarios usam tags no mobile. Disponivel via API/web |
| `supplier` / `customer` | **Colapsado** (em "+ Detalhes") | <30% dos casos quando nao vinculado a OS |
| `notes` | **Colapsado** | Esporadico |
| `attachments` | **Colapsado** | Esporadico |
| `recurrence` (avancada) | **Colapsado** | Toggle "Repetir todo mes?" visivel, config avancada (semanal, bimestral) escondida |

> **Nota:** O doc ja implementa a maioria dessas decisoes corretamente na secao "Tela 2: Formulario de Lancamento". As unicas mudancas recomendadas sao: (1) `competenceDate` marcado explicitamente como "nunca visivel no mobile", (2) `tags` removido do grupo colapsado e marcado como "API/web only no mobile v1".

#### Half-Sheet de Pagamento

| Campo | Mobile v1 | Justificativa |
|-------|-----------|---------------|
| `amount` | **Sempre visivel** (pre-fill com remainingBalance) | Obrigatorio |
| `account` | **Sempre visivel** (pre-fill ultima conta usada) | Obrigatorio |
| `paymentMethod` | **Sempre visivel** (pre-fill ultima forma usada) | Obrigatorio |
| `paymentDate` | **Automatico** (default: hoje, editavel via "Editar detalhes") | 95% dos pagamentos sao "agora" |
| `discount` | **Colapsado** | <5% dos pagamentos |
| `attachments` | **Colapsado** | Opcional |
| `notes` | **Colapsado** | Opcional |

> **Recomendacao**: Modo "one-tap" como estado padrao do half-sheet. Mostrar resumo + botao de confirmar. Campos editaveis acessiveis via "Editar detalhes". A `paymentDate` default "hoje" so aparece se o usuario expandir.

---

### 3. Terminologia: Expandir Mapeamento Tecnico -> Usuario

A tabela de terminologia na secao "Telas e Fluxos UX" cobre os conceitos principais. Expandir com os termos abaixo que aparecem no modelo mas **nao devem vazar para a UI mobile**:

| Termo tecnico (codigo) | Aparece no mobile? | Termo na UI (se aparecer) | Acao |
|-------------------------|-------------------|---------------------------|------|
| `direction` (payable/receivable) | Nunca como campo | Titulo do form: "Nova Despesa" / "Novo Recebimento" | OK (ja implementado) |
| `status` (pending/paid/cancelled) | Como badge visual | "Pendente", "Pago", "Cancelado" | **Adicionar a tabela** |
| `competenceDate` | **Nunca** | -- | Automatico (= dueDate) |
| `reconciliacao` / `reconcile` | Sim (botao na tela de contas) | **"Verificar saldo"** ou **"Corrigir saldo"** | **Renomear na UI** |
| `transferDirection` (out/in) | **Nunca** | Icones de seta resolvem visualmente | Interno |
| `syncSource` | **Nunca** | -- | Interno |
| `installmentGroupId` | **Nunca** | Usuario ve "Parcela 3/6" | Interno |
| `paidAmount` / `remainingBalance` | Sim (no detalhe da entry) | **"Pago: R$ X de R$ Y"** / **"Falta: R$ X"** | **Adicionar a tabela** |
| `DRE` | **Nunca no mobile** | **"Relatorio mensal"** ou **"Resumo do mes"** | Renomear na UI mobile |
| `regime de competencia` | **Nunca** | -- | Conceito interno, nao expor |
| `WriteBatch` / `Transaction` | **Nunca** | -- | Dev only |
| `overdue` | Sim (badge + dot) | "Vencida" (ja mapeado) | OK |
| `reversed` | Sim (no extrato) | "Estornado" (ja mapeado) | OK |

> **Regra de ouro para terminologia mobile:** Se o dono da oficina nao usaria a palavra numa conversa com um amigo, ela nao aparece na tela. "Gastei R$450 em pecas" = sim. "Registrei um payable entry com regime de competencia" = nunca.

---

### 4. Teste do "Mao Suja": Registrar R$450 em Pecas

**Cenario:** O Seu Carlos acabou de pagar R$450 em pecas no fornecedor. Esta com graxa nas maos. Precisa registrar antes de esquecer.

#### Fluxo atual (conforme doc)

```
1. Abrir app (Face ID / 1 toque)
2. Tab Financeiro (1 toque -- 0 se ja estiver na tab)
3. FAB [+] (1 toque -- bottom-right, thumb zone OK)
4. "Nova Despesa" (1 toque)
5. Digitar descricao "Pecas" (DIGITACAO -- problema com maos sujas)
6. Digitar valor "450" (DIGITACAO -- problema com maos sujas)
7. Toque em "Material" no grid de categorias (1 toque -- BOM, alvo grande)
8. Salvar (1 toque -- top-right)

Total: 6 toques + 2 campos de digitacao
Tempo estimado: 15-20 segundos
```

#### Problemas identificados

1. **Digitacao com maos sujas/molhadas** e o maior gargalo. Teclado padrao do iOS tem teclas de ~30pt, insuficiente para polegares grossos com graxa.
2. **Campo de descricao** exige pensar o que escrever. Com pressa, o usuario vai pular ou escrever "asd".
3. **Botao Salvar no top-right** esta fora da thumb zone. Com uma mao so (a outra segurando uma peca), e dificil alcancar.

#### Recomendacoes para o fluxo "mao suja"

**R1 - Templates de despesa recorrente (impacto alto, esforco medio):**
Ao abrir "Nova Despesa", mostrar 3-4 chips com as descricoes mais usadas (baseado em historico): `[Pecas] [Oleo] [Material eletrico] [+ Outra]`. Um toque preenche descricao + categoria automaticamente. Reduz digitacao a zero no caso recorrente.

**R2 - Numpad com teclas grandes (impacto alto, esforco baixo):**
O campo de valor deve abrir numpad customizado com teclas de **48pt+** (HIG recomenda 44pt minimo). Incluir botoes de valor rapido: `[+50] [+100] [+500]` para valores redondos comuns.

**R3 - Botao Salvar duplicado na bottom (impacto medio, esforco baixo):**
Alem do "Salvar" no nav bar (top-right), adicionar botao full-width fixo na bottom do form: `[Registrar Despesa]`. Segue padrao do half-sheet de pagamento e fica na thumb zone.

**R4 - Sugestao de descricao + valor (impacto medio, esforco medio):**
Se o usuario ja registrou "Pecas R$450" antes, ao digitar "Pe..." sugerir autocomplete com o ultimo valor. Usa o mesmo `AccumulatedValue` do sistema de categorias.

**R5 - Entrada por voz (impacto alto, esforco alto -- Fase futura):**
Botao de microfone no campo de descricao usando `SFSpeechRecognizer` nativo do iOS. "Quatrocentos e cinquenta reais em pecas" -> preenche valor + descricao. Excelente para maos ocupadas, mas complexidade de implementacao alta. Sugerir como Fase 3+.

#### Fluxo otimizado (com templates)

```
1. Abrir app (Face ID)
2. Tab Financeiro (1 toque)
3. FAB [+] > "Nova Despesa" (2 toques)
4. Toque no chip "Pecas" (1 toque -- preenche desc + categoria)
5. Digitar "450" no numpad grande (3 toques no numpad)
6. Botao "Registrar" na bottom (1 toque -- thumb zone)

Total: 7 toques, 0 digitacao de texto
Tempo estimado: 8-10 segundos
```

---

### 5. Consistencia com o App Atual

| Padrao UX do PraticOS | Usado no modulo financeiro? | Status |
|------------------------|-----------------------------|--------|
| `CupertinoPageScaffold` + `CupertinoSliverNavigationBar` | Sim (extrato, contas, form) | CONSISTENTE |
| `CupertinoListSection.insetGrouped` para formularios | Sim (form de entry e conta) | CONSISTENTE |
| `CupertinoAlertDialog` para confirmacoes | Sim (saldo negativo, excluir) | CONSISTENTE |
| `CupertinoActionSheet` para menus/opcoes | Sim (FAB, filtros) | CONSISTENTE |
| Swipe actions (right = acao primaria, left = destrutiva) | Sim (pagar = right, estornar = left) | CONSISTENTE |
| Half-sheets (`showCupertinoModalPopup`) | Sim (pagamento, transferencia) | CONSISTENTE |
| Status dots coloridos (8-10px) | Sim (parcelas pagas/vencidas) | CONSISTENTE |
| Dark mode com `.resolveFrom(context)` | Sim (codigo de exemplo usa) | CONSISTENTE |

**Elementos novos introduzidos:**

| Elemento | Precedente no app? | Risco de estranhamento | Acao |
|----------|--------------------|-----------------------|------|
| Grid de categorias (4 colunas) | Nao ha grid similar | Baixo (padrao de mercado) | OK -- familiar de apps de banco |
| Eye toggle para ocultar valores | Nao ha toggle similar | Baixo (Nubank/Inter) | OK -- usuarios de banco ja conhecem |
| Card expansivel de parcelas | Nao ha card expansivel | Medio | Garantir que animacao de expand/collapse seja suave e que o tap target seja generoso (todo o card, nao so um icone) |
| Badge numerico na tab | Verificar se ja existe | Baixo | OK -- padrao iOS nativo |
| Resumo inline "Entradas/Saidas" | Dashboard atual usa cards | Baixo | Transicao natural de cards para texto compacto |

> **Veredicto:** A spec esta muito bem alinhada com os padroes existentes. Os poucos elementos novos sao padroes de mercado que nao devem causar friccao.

---

### 6. Cenarios do Dia-a-Dia: Analise de Cobertura

#### Cenarios cobertos (sem friccao)

| Cenario | Como o doc resolve |
|---------|--------------------|
| Registrar despesa rapida | FAB > Despesa > form 2 niveis |
| Pagar conta com 2 toques | Swipe-right > half-sheet pre-preenchido |
| Conferir se cliente pagou OS | Extrato com link `OS #142` clicavel |
| Ver parcelas pendentes | Card expansivel com progresso visual |
| Despesa sem categoria | Categoria e opcional no schema |
| Estornar pagamento errado | Swipe-left + motivo obrigatorio |

#### Cenarios com friccao (precisam de ajuste UX)

**C1 - Split payment (metade dinheiro, metade Pix)**

O modelo suporta (pagamento parcial existe), mas o fluxo UX nao esta explicito. O usuario precisa:
1. Abrir half-sheet > pagar R$225 em dinheiro > Confirmar
2. Voltar para a entry (que agora mostra "Pago: R$225 de R$450") > pagar novamente > R$225 via Pix > Confirmar

**Recomendacao:** Adicionar ao half-sheet de pagamento, apos confirmar um pagamento parcial, um prompt: `"Faltam R$225. Registrar outro pagamento agora?"` com botoes `[Sim, agora]` `[Depois]`. Reduz de "saber que precisa voltar e pagar de novo" para "o sistema me pergunta". Tambem adicionar na secao do half-sheet o wireframe deste fluxo.

**C2 - Dono paga do proprio bolso (conta pessoal vs empresa)**

Seu Carlos paga uma peca com o cartao pessoal porque esqueceu o da empresa. Hoje nao ha como registrar isso de forma clara.

**Recomendacao (modelo -- sem mudanca):** O usuario pode criar uma conta do tipo `cash` chamada "Meu Bolso" ou "Pessoal". Ao registrar a despesa nessa conta, fica claro que saiu do bolso dele. Depois pode transferir da conta da empresa para "reembolsar" via transferencia. Documentar este fluxo como exemplo na secao de onboarding ou FAQ, sem adicionar campos ao modelo.

**C3 - "Quanto fiz hoje" sem navegacao**

O header do extrato mostra saldo total + entradas/saidas do **mes**. O dono da oficina quer saber "quanto fiz hoje" ao final do expediente sem pensar.

**Recomendacao:** Adicionar ao `BalanceHeader` uma segunda linha compacta com o resumo do dia atual:

```
Saldo Total              [eye]
R$ 15.420,00

Hoje: +R$1.150  -R$450  = +R$700
```

Sempre visivel, zero toques. Dados ja estao no stream de payments (filtrar por `paymentDate == hoje`). Impacto baixo na implementacao (filtro adicional no store).

**C4 - Tecnico no campo registra gasto de material**

O tecnico comprou um fusivel de R$15 no caminho para o cliente. RBAC atual so permite admin/gerente no modulo financeiro. O tecnico nao pode registrar.

**Recomendacao:** Adicionar permission granular `registerFieldExpense` que permite ao tecnico:
- Criar entries `payable` de valor limitado (ex: ate R$500, configuravel)
- **Nao** ver saldo total, extrato geral, contas bancarias ou relatorios
- A despesa aparece para o admin aprovar/revisar

Isso pode ser implementado como variacao do form de entry, acessivel via atalho na tela de OS ("Registrar gasto") em vez da tab Financeiro. Adicionar a tabela de RBAC:

| Perfil | registerFieldExpense |
|--------|---------------------|
| Admin | sim |
| Gerente | sim |
| Supervisor | configuravel |
| Tecnico | configuravel |

> **Nota para modelo:** Nao requer novos campos. A entry criada pelo tecnico e uma `payable` normal com `createdBy` do tecnico. O admin ve no extrato e pode editar/categorizar depois.

**C5 - Fornecedor recorrente (repetir ultimo lancamento)**

Seu Carlos paga o mesmo fornecedor de pecas toda semana, valores similares. Recorrencia formal (mensal) nao se aplica porque o valor varia.

**Recomendacao:** Adicionar na lista de "Despesas recentes" (ou nos chips de template sugeridos no R1) a opcao de "Repetir" um lancamento anterior. Tap em "Repetir" pre-preenche descricao, categoria, fornecedor e conta -- o usuario so ajusta o valor. Mesmo conceito de "repetir pedido" em apps de delivery.

---

### 7. Camadas de Complexidade: Mobile v1 vs API/Web Futura

> **Principio:** Toda funcionalidade existe no modelo de dados e na API. A interface mobile v1 expoe apenas o que o dono da oficina precisa no dia-a-dia. A web futura (para contadores, gestores de rede, franquias) expoe o restante.

| Funcionalidade | Mobile v1 | API/Web Futura | Justificativa |
|----------------|-----------|----------------|---------------|
| Registrar despesa/recebimento | Sim (form 2 niveis) | Sim (form completo) | Core do dia-a-dia |
| Pagar entry | Sim (half-sheet 1-2 toques) | Sim | Core |
| Extrato cronologico | Sim (scroll infinito por mes) | Sim + filtros multi-criterio | Core mobile, filtros avancados no desktop |
| Contas bancarias CRUD | Sim (lista + form simples) | Sim + reconciliacao detalhada | Core |
| Transferencias | Sim (half-sheet) | Sim | Core |
| Parcelas (visualizar + pagar) | Sim (card expansivel) | Sim + edicao em lote | Core mobile, edicao em lote no desktop |
| Estornos | Sim (swipe + motivo) | Sim + relatorio de estornos | Core |
| Categorias | Sim (grid simples ou AccumulatedValue) | Sim + hierarquia, merge, regras | Simplificado no mobile |
| Comprovantes | Sim (camera/galeria) | Sim + upload PDF multiplo, OCR | Simplificado no mobile |
| **DRE (regime competencia)** | **NAO** -- exibir como "Resumo do mes" simplificado (receitas vs despesas por categoria) | Sim (DRE completo com competenceDate editavel) | Termo "DRE" nunca aparece no mobile |
| **Fluxo de caixa projetado** | **SIMPLIFICADO** -- "Proximos 30 dias: a receber X, a pagar Y" (1 card) | Sim (3-12 meses, grafico de linha) | Mobile so precisa do curto prazo |
| **Reconciliacao manual** | **NAO** -- alerta automatico se saldo divergir + botao "Corrigir saldo" | Sim (tela dedicada com historico) | Reconciliacao detalhada e tarefa de escritorio |
| **Filtros avancados do extrato** | **NAO** -- apenas filtro por tipo (Tudo/Entradas/Saidas/Transferencias) | Sim (categoria, conta, periodo custom, fornecedor, tags) | Tela pequena, filtro simples basta |
| **Relatorios cross-periodo** | **NAO** | Sim (comparativo mes-a-mes, tendencias) | Analise e tarefa de escritorio |
| **Regime de competencia** | **AUTOMATICO** (competenceDate = dueDate, invisivel) | Sim (campo editavel) | Usuario mobile nao sabe o que e |
| **Tags** | **NAO** (campo existe no modelo, invisivel no mobile) | Sim (filtro e organizacao) | Ninguem tagga despesa no celular com maos sujas |
| **Exportacao CSV/PDF** | **NAO** | Sim (relatorios exportaveis) | Tarefa de escritorio/contabilidade |
| **Snapshots mensais** | **NAO** (geracao automatica em background) | Sim (botao "Fechar mes", historico) | Conceito contabil, nao expor no mobile |
| **Notas detalhadas** | **Colapsado** (campo existe mas escondido) | Sim (campo proeminente) | Mobile = anotar rapido, desktop = detalhar |

---

### 8. Top 10 Recomendacoes Priorizadas

| # | Recomendacao | Impacto | Esforco | Fase |
|---|-------------|---------|---------|------|
| 1 | **Resumo do dia no header** ("Hoje: +R$1.150 -R$450 = +R$700") -- zero toques para "quanto fiz hoje" | Alto | Baixo | 1 |
| 2 | **Half-sheet one-tap** -- modo padrao mostra `[Confirmar R$X via Pix]` com link "Editar detalhes" para expandir campos | Alto | Baixo | 1 |
| 3 | **Templates de despesa** -- chips com descricoes mais usadas (Pecas, Oleo, Material) que pre-preenchem desc + categoria em 1 toque | Alto | Medio | 1 |
| 4 | **Numpad com teclas grandes** (48pt+) e botoes de valor rapido `[+50] [+100] [+500]` no campo de valor | Alto | Baixo | 1 |
| 5 | **Split payment explicitado** -- apos pagamento parcial, prompt "Faltam R$X. Registrar outro agora?" | Medio | Baixo | 1 |
| 6 | **Botao Salvar na bottom** do form de entry (full-width, thumb zone) alem do nav bar top-right | Medio | Baixo | 1 |
| 7 | **`competenceDate` e `tags` marcados como invisivel** no mobile v1 (existem no modelo, nao aparecem no form) | Medio | Zero | 1 |
| 8 | **Terminologia expandida** -- adicionar "Pendente", "Pago", "Cancelado", "Verificar saldo", "Pago: X de Y", "Falta: X" a tabela | Medio | Zero | 1 |
| 9 | **Permission `registerFieldExpense`** para tecnico registrar despesa no campo (via tela de OS, nao tab Financeiro) | Medio | Medio | 2-3 |
| 10 | **Tabela Mobile v1 vs Web Futura** incorporada ao doc para guiar decisoes de UI durante implementacao | Alto | Zero | 1 |

### 9. O que o Doc Ja Faz Bem

Para registro: estes pontos da spec ja estao excelentes e nao precisam de mudanca:

- **Swipe-right para pagar** (2 toques) -- melhor atalho do modulo
- **Pre-fill inteligente** no half-sheet (valor + conta + forma + data)
- **Form de 2 niveis** (essencial visivel + detalhes colapsados)
- **FAB com 2 opcoes** (Despesa/Recebimento) -- simples e direto
- **Card expansivel de parcelas** com botao "Pagar" na proxima pendente
- **Badge de vencidas** na tab -- visibilidade sem abrir
- **Empty state + onboarding 3 passos** -- baixa barreira de entrada
- **Eye toggle** -- familiar de apps bancarios
- **Categorias por uso** (AccumulatedValue) -- as mais usadas sobem
- **Transferencia como half-sheet** em vez de tela dedicada

---

## Changelog

### Marco 2026

#### Milestone 1 implementado: Despesas + Extrato (31/03/2026)

**Sprints 1-8 concluidos. 44 arquivos, +5.656 linhas, zero erros no analyze, 42 testes passando.**

Arquivos criados:
- 4 models: `FinancialAccount`, `FinancialEntry`, `FinancialPayment`, `PaymentMethod` (+ 3 `.g.dart`)
- 6 repositories: 3 TenantRepository + 3 RepositoryV2 (accounts, entries, payments)
- 3 stores MobX: `FinancialAccountStore`, `FinancialEntryStore`, `FinancialPaymentStore` (+ 3 `.g.dart`)
- 5 widgets: `BalanceHeader`, `PaymentTimelineItem`, `PaymentConfirmationSheet`, `CategoryPickerGrid`, `InstallmentProgressCard`
- 2 telas: `FinancialStatementScreen` (extrato), `FinancialEntryFormScreen` (formulario 2 niveis)
- 1 widget de onboarding: `FinancialOnboardingSheet` (3 passos)
- 3 arquivos de teste: 42 testes (serialization + business logic)

Arquivos modificados:
- `Company` model (flag `useFinancialManagement`)
- `SegmentConfigService` + `SegmentConfigProvider` (getter do flag)
- `auth_wrapper.dart` (resolucao do flag)
- `permission.dart` (3 novas permissions: `manageFinancialEntries`, `manageFinancialAccounts`, `viewFinancialStatement`)
- `routes.dart` (4 novas rotas)
- `navigation_controller.dart` (tab condicional)
- `company_form_screen.dart` (toggle do flag)
- `bootstrap_service.dart` (`bootstrapFinancialCategories()`)
- 3 `.arb` (47 strings financeiras em pt/en/es)

Funcionalidades entregues:
- Feature flag `useFinancialManagement` (toggle, zero impacto quando desligado)
- Onboarding de 3 passos (criar conta, saldo inicial, CTA)
- Criar despesa simples ou parcelada
- Pagar via half-sheet one-tap com pre-fill
- Extrato com timeline agrupada por data + filtros por tipo
- Eye toggle para ocultar valores
- Resumo do dia no header ("Hoje: +X -Y = Z")
- Navegacao por mes
- Categorias dinamicas via AccumulatedValue (bootstrap com 14 categorias)
- Toggle "Repetir todo mes" para recorrencia
- Empty states com CTAs
- i18n completo (pt/en/es)
- Dark mode ready (cores com `.resolveFrom(context)`)

#### Reestruturacao de fases para sprints de IA (31/03/2026)

**Fases reorganizadas de 4 milestones de produto para 15+ sprints tecnicos otimizados para implementacao por IA:**

- 4 milestones de produto mantidos (Despesas, Contas, Sync/Estornos, Relatorios)
- Cada milestone quebrado em sprints de 2-8 arquivos (cabe no contexto de 1 sessao)
- 1 stack por sprint (nao mistura Flutter com TypeScript com Nunjucks)
- 1 padrao repetivel por sprint (ex: todos os models seguem mesma estrutura)
- Ponto de validacao concreto ao final de cada sprint (build_runner, analyze, teste manual)
- Sprints separados para API, Bot, Docs, Infra (rodam em paralelo via worktrees)
- Mapa de dependencias com sprints paralelizaveis identificados
- Sprints de alto risco marcados (Sync OS, Estornos) com checklists de teste exaustivos
- Complexidade relativa por sprint (S/M/L/XL)

#### Revisao UX Mobile-First (30/03/2026)

**Revisao completa da spec sob otica de usabilidade para dono de oficina mecanica:**

- Contagem de toques por acao (6 acoes dentro do limite de 4, 2 alertas: transferencia e "quanto fiz hoje")
- Classificacao de todos os campos do form: sempre visivel / colapsado / automatico (mobile-invisible)
- `competenceDate` e `tags` marcados como "nunca visivel no mobile v1" (existem no modelo, nao na UI)
- Terminologia expandida: adicionados "Pendente/Pago/Cancelado", "Verificar saldo", "Pago X de Y", "Falta X"
- Teste do "mao suja" com fluxo tela-a-tela e 5 recomendacoes (templates, numpad grande, voz, botao bottom)
- Analise de consistencia com padroes Cupertino existentes (3 elementos novos identificados, todos aceitaveis)
- 5 cenarios do dia-a-dia analisados: split payment, pagamento do bolso, "quanto fiz hoje", tecnico no campo, fornecedor recorrente
- Tabela completa Mobile v1 vs API/Web Futura (17 funcionalidades classificadas)
- Top 10 recomendacoes priorizadas por impacto e esforco
- **Nenhuma feature removida** -- todas as recomendacoes sao sobre UI (esconder, defaultar, automatizar)

#### Feature flag `useFinancialManagement` (30/03/2026)

**Modulo financeiro e opcional**, controlado por flag no Company model (padrao: false):
- Segue mesmo padrao de `useContracts`, `useDeviceManagement` (SegmentConfigProvider)
- Tab Financeiro condicional: dashboard OS (flag off) ou extrato (flag on)
- Sync bidirecional OS<->Financeiro so ativa com flag on
- API retorna 403 MODULE_DISABLED se flag off
- Bootstrap de categorias executa na primeira ativacao
- Zero impacto para quem nao ativa -- app continua como hoje
- Tabela completa de comportamento por flag (on vs off)
- Exemplos de codigo para navigation, order store, API guard e company form

#### Categorias dinamicas via AccumulatedValue + Bootstrap (30/03/2026)

**Mudanca:** Categorias financeiras deixam de ser hardcoded (`FinancialCategory` com listas fixas) e passam a ser 100% dinamicas via `AccumulatedValue` existente.

- Removida classe `FinancialCategory` com listas estaticas
- Categorias armazenadas em `accumulatedFields/expenseCategory/` e `incomeCategory/`
- Bootstrap cria categorias iniciais sugeridas (localizadas por idioma e segmento)
- Usuario pode criar/excluir categorias livremente via autocomplete
- Ranking por uso real (`usageCount`) -- mais usadas aparecem primeiro
- Picker usa `AccumulatedValueListScreen` existente (MVP) com evolucao para grid de icones (Fase 2+)
- API aceita category como string livre (nao enum)
- Adicionado `bootstrapFinancialCategories()` ao `BootstrapService`

#### Revisao e otimizacao do plano (30/03/2026)

**Bugs corrigidos:**
- Removido `overdue` do enum `FinancialEntryStatus` -- vencida e estado computado (`isOverdue` getter), nao status persistido. Evita necessidade de scheduled job.
- Corrigido ternario redundante em `recalculatePaidAmount` (ambos branches retornavam 'pending')
- Adicionado filtro `deletedAt != null` em `calculateRealBalance` (ignorava soft-deleted)
- Adicionado `syncSource` nos modelos `FinancialEntry` e `FinancialPayment` (estava na secao de sync mas ausente dos models)
- Corrigido API pagination de offset-based para cursor-based (Firestore nao suporta offset eficiente)
- Corrigido bot commands de `?period=today` para `?startDate/endDate` (consistente com Zod schema)

**Lacunas preenchidas:**
- Adicionado Zod schema para `POST /v1/financial/entries` (criacao de entry)
- Adicionado Zod schema para `POST /v1/financial/accounts` (criacao de conta)
- Adicionada secao "Comportamento Offline" (WriteBatch offline, conflitos, saldo temporario)
- Adicionada secao "Conta Bancaria Desativada" (o que acontece com entries pendentes)
- Adicionada tabela "Validacao de Valores" (min/max amount, campos obrigatorios)
- Adicionado indice/sumario no topo do documento para navegacao

#### Especificacao de API, Bot, Site e Documentacao (30/03/2026)

**Novas secoes adicionadas:**
- API Cloud Functions: endpoints REST completos (v1, app, bot) com schemas Zod e exemplos JSON
- Bot WhatsApp: comandos naturais, automacoes CRON, integracao com cobranca (Fase 4)
- Site Eleventy: artigo separado `gestao-financeira` com 10 secoes (trilingual)
- Documentacao: checklist de docs a atualizar/criar
- Fases de Implementacao: expandidas com API, bot, site e docs em cada fase

**Decisoes:**
- Site: artigo separado (nao atualizar financeiro.json existente)
- Bot: comandos financeiros apenas na Fase 4 (apos relatorios)
- API: cresce junto com o app (Fase 1 = entries/payments, Fase 2 = accounts, Fase 3 = sync, Fase 4 = bot)

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

#### 10 otimizacoes de robustez e completude (30/03/2026)

**Novos campos nos modelos:**
- `discountAmount` em `FinancialEntry` e `discount` em `FinancialPayment` -- suporte a desconto no pagamento parcial, evita saldo residual eterno
- `competenceDate` em `FinancialEntry` -- permite DRE por regime de competencia (aluguel de marco pago em abril aparece no DRE de marco)
- `transferDirection` (`out`/`in`) em `FinancialPayment` -- direcao explicita em transferencias, simplifica queries e reconciliacao
- `orderId` em entries payable documentado para uso futuro (custo direto da OS)

**Correcoes de robustez:**
- `recalculatePaidAmount` reescrito usando `Transaction` do Firestore (evita race condition em estornos simultaneos multi-device)
- Estorno de transferencia com logica completa: reverte ambos os payments do `transferGroupId` atomicamente
- Recorrencia com loop de catch-up: gera entries atrasadas quando app e reaberto apos periodo offline
- Documentada limitacao: geracao de recorrencia e client-side, nao ocorre sem abrir o app

**Ajustes de limites e validacao:**
- Limite de parcelas aumentado de 48 para 60 (5 anos -- cobre financiamento de equipamentos)
- Validacao de saldo negativo por tipo de conta: `cash`/`digitalWallet` alertam antes de ficar negativo, `bank`/`creditCard` permitem
- Snapshots mensais antecipados para Fase 2 (geracao manual via botao "Fechar mes")

**UX:**
- Toggle "Conceder desconto" no half-sheet de pagamento (colapsado por padrao)
- `remainingBalance` getter atualizado para considerar `discountAmount`

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
