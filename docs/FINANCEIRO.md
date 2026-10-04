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

#### Registrar Pagamento/Desconto
- Alternar entre **Pagamento** e **Desconto** via segmented control
- Campo de valor pré-preenchido com saldo restante
- Campo de observação opcional (ex: "Pagamento em dinheiro", "Desconto fidelidade")
- Ação rápida "Pagar valor total"

#### Histórico de Transações
- Lista de todas as transações (pagamentos e descontos)
- Ordenadas por data (mais recente primeiro)
- Swipe para remover transação

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

---

## Dashboard Financeiro

### Acesso
Menu lateral > **Dashboard** (requer permissão `viewFinancialReports`)

### Indicadores

| Indicador | Descrição |
|-----------|-----------|
| Faturamento Total | Soma dos totais de todas as OS filtradas |
| Valor Recebido | Soma de todos os `paidAmount` |
| A Receber | Soma de `(total - paidAmount)` das OS não pagas |
| OS Pagas | Quantidade de OS com status `paid` |

### Cálculo Considerando Pagamentos Parciais

```dart
// Valor Recebido (considera pagamentos parciais)
totalPaidAmount = orders.fold(0.0, (sum, order) {
  if (order.payment == 'paid') {
    return sum + (order.paidAmount ?? order.total ?? 0.0);
  }
  return sum + (order.paidAmount ?? 0.0);
});

// A Receber (considera saldo restante)
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
| Admin | Sim | Sim | Sim |
| Gerente | Sim | Sim | Sim |
| Supervisor | Não | Não | Não |
| Consultor | Sim* | Não | Não |
| Técnico | Não | Não | Não |

*Consultor vê preços apenas das próprias OS

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
| `lib/screens/dashboard/financial_dashboard_simple.dart` | Dashboard financeiro |

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
