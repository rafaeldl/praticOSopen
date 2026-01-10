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

| Status da OS | Pode Registrar Pagamento? | Auto-Aprovação? |
|--------------|---------------------------|-----------------|
| Orçamento | Sim | Sim (transita para Aprovado) |
| Aprovado | Sim | Não |
| Em Andamento | Sim | Não |
| Concluído | Sim | Não |
| Cancelado | Não | Não |

**Regra Atual:** Pagamentos podem ser registrados em qualquer status, exceto **Cancelado**.

**Auto-Aprovação:** Quando um pagamento ou desconto é registrado em uma OS com status **Orçamento**, ela é automaticamente aprovada e transita para o status **Aprovado**. Isso elimina a necessidade de aprovação manual antes de registrar o primeiro pagamento.

**Interface:** Ao visualizar a tela de pagamentos em uma OS em orçamento, um banner informativo azul é exibido explicando que a OS será automaticamente aprovada ao registrar o pagamento.

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
// Registrar pagamento
void addPayment(double amount, {String? description})

// Registrar desconto
void addDiscountTransaction(double amount, {String? description})

// Marcar como totalmente pago
void markAsFullyPaid({String? description})

// Remover transação
void removeTransaction(int index)

// Atualizar status baseado nos valores
void _updatePaymentStatus()
```

---

## Changelog

### Janeiro 2026

#### Auto-Aprovação de Orçamentos ao Registrar Pagamento (10/01/2026)

**Mudanças:**
- Pagamentos agora podem ser registrados em OS com status **Orçamento**
- Auto-transição de 'quote' → 'approved' ao registrar pagamento/desconto
- Banner informativo na UI explicando o comportamento de auto-aprovação
- Bloqueio de pagamentos apenas para status **Cancelado**
- Métodos atualizados: `addPayment()`, `addDiscountTransaction()`, `markAsFullyPaid()`
- Lógica de `updatePayment()` ajustada para permitir exibir pagamentos em orçamentos

**Motivação:**
Simplificar o fluxo de trabalho eliminando a necessidade de aprovar manualmente um orçamento antes de registrar o pagamento. Agora o ato de registrar o pagamento já implica na aprovação do orçamento.

**Arquivos modificados:**
- `lib/screens/payment_management_screen.dart` - Removido bloqueio para 'quote'
- `lib/mobx/order_store.dart` - Adicionada lógica de auto-aprovação

**Commits:**
- `eac385b` - feat: auto-approve orders when payment is registered on quote status

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
