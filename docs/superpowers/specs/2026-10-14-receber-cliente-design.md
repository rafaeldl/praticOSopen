# Receber de um cliente (um pagamento, várias OS)

Complementa `2026-10-10-telas-receber-design.md` e `2026-10-09-telas-financeiro-design.md`. Doc técnica: `docs/FINANCEIRO.md` ("Receber de um cliente").

## Problema

No Financeiro, cliente com várias OS em aberto obrigava a escolher uma OS ("Qual OS?") e receber só nela. Na prática o cliente paga de uma vez (parte ou tudo) por várias OS. O comprovante ficava preso a uma OS e a data do pagamento era sempre "agora".

## Decisões (fase 1)

1. **Mais antiga primeiro.** O valor recebido vai para as OS na mesma ordem de `Debtor.orders` (mais antiga primeiro), cada uma limitada ao que falta nela, em centavos inteiros. "Escolher as OS" (divisão manual) é fase 2: `allocatePayment` recebe a lista na ordem desejada e o gravador só consome `PaymentAllocation`, então a fase 2 só monta outra lista.
2. **Data do pagamento volta.** Linha "Quando", "Hoje" por padrão, abre seletor de data sem datas futuras. Vale na tela nova e no Receber de uma OS. Grava `paidAt` (hoje = agora; outro dia = meio-dia do dia, para não trocar de dia por fuso).
3. **Sem forma de pagamento** (Pix/dinheiro/cartão).
4. **Sem pagar a mais.** O valor não passa do total que o cliente deve (como já era por OS).
5. **Asaas é fase 3.** Nada muda nas Functions nem no Asaas.

## Tela "Receber de {cliente}"

Empurrada (age sobre o que já existe). `lib/screens/payments/receive_customer_screen.dart`.

| Parte | Conteúdo |
|---|---|
| Título | "Receber de João" (quebra linha, sem reticências) |
| Frase | "Deve R$ 1.250 em 3 OS" |
| Bloco `accentSoft` | Valor (pré-preenchido com tudo o que deve), dica ou motivo do botão desligado, "Quando · Hoje ›", "Anexar comprovante" |
| Como fica | Uma linha por OS, ao vivo: "OS 182 · quita R$ 450", "OS 190 · recebe R$ 300, fica R$ 200", "OS 201 · continua R$ 500". Sem toque na fase 1 |
| Nota | "O valor vai primeiro para as OS mais antigas." |
| Botão azul | "Recebi R$ X"; desligado com 0 ("Digite quanto recebeu.") ou acima do que deve ("Passa do que ele deve (R$ 1.250).") |

Sucesso: aviso opaco (`showAppToast`) e volta; o Financeiro recarrega. Erro: aviso, a tela fica.

## Entradas

- **Financeiro**: cliente com 2+ OS em aberto (lista e "Ver todos") abre a tela nova. Com 1 OS, Receber da OS. OS sem cliente continuam no "Qual OS?" (não são um pagador só).
- **Tela do cliente**: "Falta receber R$ X · Receber". Mesma regra do Receber (`AuthorizationService.canReceiveOnOrder`, some sem "Valores e cobrança"). O link só leva as OS em aberto em que a pessoa pode receber; com 1 abre o Receber dela. Consultor sem OS própria em aberto vê o "Falta receber R$ X" sem o "· Receber".

## Quem recebe

Uma regra só, `AuthorizationService.canReceiveOnOrder(order)`: dono, admin e gerente (`viewFinancialReports`) recebem em qualquer OS; o consultor recebe só nas OS que ele criou (`createdBy.id`, mesma posse do `viewOwnOrders` e da regra de update de `/orders`). Supervisor e técnico nunca. Ela decide o "Receber" da OS (botão azul, frase e linha "Falta receber"), a tela `/payment_management` (acesso negado na OS de outro) e o "· Receber" da tela do cliente (para o consultor, só as OS dele). Desconto continua só com acesso ao financeiro.

As "Outras OS do cliente" (OS de outros vendedores) não aparecem para o consultor: as regras não deixam ele ler essas OS. Isso vem depois por uma função no servidor, junto com a fase 3 (Asaas).

## Dados

- `companies/{companyId}/receipts/{receiptId}` (`Receipt`): `customer`, `amount`, `paidAt`, `allocations` [{`orderId`, `orderNumber`, `amount`, `transactionId`}], `receiptFile` (opcional), `status` (`active`/`canceled`), auditoria.
- Cada OS: transação `payment` normal com sua parte + `paidAt` + `receiptGroupId`. `paid`/`payment` pela conta de sempre (`OrderPaymentMath.addPaymentUpdate`).
- Recebimento + N OS num único WriteBatch (offline, tudo ou nada).
- Comprovante enviado uma vez (`tenants/{companyId}/receipts/{receiptId}/{arquivo}`); cada OS ganha um `OrderDocument` `receipt` apontando para o mesmo arquivo, ligado à sua transação (`linkedTransactionId` / `receiptDocumentId`). Escolhido em vez de um campo novo na transação porque o "ver comprovante" da OS e o PDF já leem `OrderDocument`; nada muda lá.
- Data do pagamento em todo lugar: `paidAt ?? createdAt` (`PaymentTransaction.paidOn`): "Recebido em {mês}", lista de pagamentos da OS (ordem e rótulo).

## Regras (risk:high)

- `receipts`: cria owner, admin, manager e consultant (`canReceivePayments`); lê e atualiza quem vê o financeiro (`canViewFinancial`) ou quem criou o recebimento; criação exige `status == 'active'`, `amount > 0`, `allocations` não vazia e `createdBy.id` = usuário; atualização só em `status`/`receiptFile`/`updatedAt`/`updatedBy`; `delete` nunca. As regras não conferem se cada OS da repartição é do consultor; isso vale pela regra de update de `/orders`, no mesmo batch (OS de outro nega o batch todo).
- Consultor/técnico: a consulta das OS do cliente filtra também `createdBy.id` (só igualdade, sem índice composto), senão as regras negam.
- Storage `tenants/{companyId}/receipts/{receiptId}/{arquivo}`: membro da empresa (claims), imagem ou PDF até 10 MB, só criação.

## Fase 2 (feita)

Decisões do dono: mais antiga primeiro com opção de escolher as OS; data do pagamento sim; sem forma de pagamento; pagar a mais bloqueado.

1. **Escolher as OS.** Link "Escolher as OS" embaixo de "Como fica" (só com 2+ OS em aberto) abre a tela de escolher com várias marcações: título "Quais OS ele está pagando?", linha "OS 185" com "Falta R$ 400 · 01/10/2026", ✓ nas marcadas, ✓ do topo confirma. Padrão: todas. Depois de escolher, o valor vai só para as escolhidas, mais antiga primeiro; o valor é preenchido com o que falta nelas e esse é o máximo.
2. **Recebimento.** Tela própria: título = valor, "João · 14/10/2026", uma linha por OS ("OS 185 · R$ 400 · quitada" / "OS 184 · R$ 100 · falta R$ 200"), "Ver comprovante" se houver, um botão azul "Mandar recibo para João" e "…" com "Desfazer recebimento" em vermelho (confirmação em alerta). Abre ao tocar no pagamento (com `receiptGroupId`) no "Já recebido" da OS e pela seção "Recebimentos" da tela do cliente.
3. **Desfazer.** Um WriteBatch: recebimento `canceled` + cada OS perde a sua transação, com a conta de `OrderPaymentMath.removeTransaction` (`paidAmount`, `paid`, `payment`). Sai o `OrderDocument` do comprovante, o arquivo fica. Sem desfazer parcial: remover a parte de um recebimento numa OS (ou "Desfazer pagamentos" com uma parte dessas) explica e oferece abrir o recebimento.
4. **Recibo em PDF.** Cabeçalho da empresa como no PDF da OS, "RECIBO" + "Nº 3F9A1C" (6 primeiros caracteres do id), "Recebemos de João a quantia de R$ 700,00 em 14/10/2026.", tabela (OS, descrição = veículo/aparelho ou primeiro serviço, pago agora, ainda falta), total, "Falta receber R$ X dessas OS." se sobrar, "Registrado por Ana". Também para um pagamento de uma OS só ("Mandar recibo" na folha do pagamento). Asaas fica fora (continua o comprovante do Asaas).

Regras: sem mudança (o desfazer só toca `status`/`updatedAt`/`updatedBy` no recebimento; as OS seguem a regra de sempre). Quem vê e mexe: acesso ao financeiro em todos; o consultor só nos recebimentos que ele registrou (`AuthorizationService.canManageReceipt`, mesma posse da regra de `receipts`). "Mandar recibo" de um pagamento de uma OS: quem recebe nessa OS (`canReceiveOnOrder`). A seção "Recebimentos" da tela do cliente fica só com acesso ao financeiro.

## Fase 3

- Asaas (cobrança de várias OS).
