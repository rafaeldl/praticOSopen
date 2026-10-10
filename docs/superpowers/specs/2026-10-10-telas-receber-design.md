# Receber do cliente (pagamentos da OS e link para pagar)

Complementa `2026-10-09-telas-financeiro-design.md`. Protótipos na linha "Receber do cliente" da página "Telas do app" do canvas (https://claude.ai/artifact/NfHsv1Ge52LXGdpd9ZYihz). Componentes: ver `2026-10-09-telas-componentes-design.md`.

> A tela abre pela OS (`order_form.dart`), que é de outra sessão. Esta spec só define a tela de receber; a linha "Pagamento" da OS continua levando até ela.

## Problema atual

Telas: `lib/screens/payment_management_screen.dart` (1.313 linhas), `lib/screens/payments/widgets/order_charge_section.dart` + `order_charge_card.dart`, `lib/screens/payments/create_charge_screen.dart`. Uso: 518 visualizações / 43 usuários em 28 dias (Analytics, 11/09–08/10), a 6ª tela mais aberta fora da OS.

| Achado | Evidência |
|---|---|
| A pergunta "o cliente pagou?" fica no meio da tela, depois de 4 linhas de resumo coloridas | `payment_management_screen.dart:113-186` |
| 4 ações azuis disputam: Registrar (filled), Anexar, "Pagar valor total", "Cobrar com Asaas" | `:584`, `:563-571`, `:609-617`, `order_charge_card.dart:318-325` |
| Desconto, que é raro, é o primeiro controle (segmentado Pagamento/Desconto) | `:384-462` |
| "Pagar valor total: R$ X" repete o valor que já vem preenchido | `:597-623`, `:88-95` |
| Link vermelho "A Receber" apaga todos os pagamentos | `:358-367`, `:949-971` |
| Remover um pagamento só arrastando a linha | `:689-706` |
| Status da cobrança: pendente em azul de ação, vencida em vermelho de perigo | `order_charge_card.dart:18-31` |
| Depois de gerar a cobrança, abre um diálogo e o usuário ainda precisa achar "Compartilhar link" | `payment_management_screen.dart:282-284` |
| Jargão: Visão geral, Restante, Total pago, Transação, Saldo, Fatura, Vencimento | `.arb`: `overview`, `remaining`, `totalPaid`, `noTransactionsRecorded`, `chargeBalanceHint`, `chargeCopyInvoiceLink`, `chargeDueDate` |
| Moeda presa em `pt_BR`/R$ no campo | `:493-495` |
| Cada pagamento termina num `CupertinoAlertDialog` com OK | `:1232-1257` |

## Telas propostas

| Prancha | O que responde | Botão azul |
|---|---|---|
| Receber · falta receber | "Quanto a Ana pagou?" Valor grande já preenchido com o que falta, "Como pagou" (Pix/Dinheiro/Cartão) | **Recebi R$ 950** (acompanha o valor digitado) |
| Receber · tudo recebido | Ponto verde + "Tudo recebido", lista do que entrou | nenhum |
| Receber · menu "…" | Dar desconto · Anexar comprovante · Desfazer pagamentos (vermelho, com confirmação) | — |
| Receber · dar desconto | Sheet com Cancelar; diz o novo total ("passa de R$ 1.250 para R$ 1.200") | Dar R$ 50 de desconto |
| Receber · tocar num pagamento | Sheet: valor, como pagou, quem anotou · Ver comprovante · Remover este pagamento | — |
| Receber · criar link para pagar | Sheet (Asaas): valor, "Pagar até", "Parcelar no cartão: Não". CPF/CNPJ só aparece se faltar (como hoje) | Criar e mandar o link (abre o WhatsApp direto) |
| Receber · link esperando pagamento | "A Ana ainda não pagou os R$ 950. O link vale até 17/10." · link "Ela pagou de outro jeito" | Lembrar a Ana pelo WhatsApp |
| Receber · opções do link | Mandar de novo · Copiar o link · Cancelar o link (vermelho) | — |

Regras:
- "Mandar link para a Ana pagar" só aparece com o piloto Asaas e a permissão `chargeOrder` (como `order_charge_section.dart:60-69`). Sem Asaas, a mesma linha abre o sheet de compartilhar a OS (`ShareLinkSheet`, prancha "Financeiro · mandar cobrança").
- Status do link: esperando = âmbar + texto; vencido = âmbar + "Venceu em 17/10"; pago = verde. Azul e vermelho saem do status.
- Pagamento que veio pelo link aparece como "Pix pelo link · o app anotou sozinho" e não pode ser removido no app (só estorno), como hoje (`PaymentTransaction.isAsaas`).
- Sem diálogo de sucesso: depois de "Recebi", a tela vira "Tudo recebido" ou mostra o novo "Falta receber".
- No Financeiro, tocar numa linha de "Falta receber" abre esta tela (OS com uma pendência) ou o cliente (mais de uma OS).

## Componentes

Reaproveita `AppTopBar`, `ScreenTitle`, `NextStepBlock`, `MoneyField` (aqui em 34, dentro do bloco), `PrimaryButton`, `AppListRow`, `StatusDot`, `SummaryLine`, `MoreMenu`, `DestructiveAction` e `ShareSheet`. Novo, registrado no doc comum: `ChoiceChips`.

## Ordem de implementação

1. **Textos e cores** (risk:low): trocar o jargão nos `.arb`; status da cobrança com `AppColors`; tirar o link vermelho "A Receber" da tela e levar para o "…"; `FormatService` no campo de valor.
2. **Tela Receber** (risk:low, UI): bloco de próximo passo com valor + "Recebi R$ X"; desconto e anexo no "…"; tocar no pagamento abre o sheet (sai o arrastar); sem diálogo de sucesso.
3. **Link para pagar** (risk:high, billing): sheet de criar link; ao criar, abrir o envio pelo WhatsApp direto; estado "esperando pagamento" com "Lembrar".
4. **Como pagou** (decisão abaixo).

## Perguntas em aberto

1. **"Como pagou" (Pix/Dinheiro/Cartão)**: `PaymentTransaction` não tem esse campo (`lib/models/payment_transaction.dart`). Opções: gravar no `description` (sem migração, risk:low) ou criar `method` no modelo (modelo compartilhado, risk:high, permite relatório por forma de pagamento). Ou deixar de fora.
2. **Lembrete automático**: o Asaas já manda lembrete por e-mail/SMS? Se sim, o botão "Lembrar a Ana" pode virar secundário.
