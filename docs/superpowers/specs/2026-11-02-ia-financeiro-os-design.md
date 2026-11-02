# IA da OS: receber, desconto e status (Fase 1)

Data: 2026-11-02. Status: proposta, aguardando aprovação.
Base: `docs/AI_ORDER_ASSIST.md`, `docs/FINANCEIRO.md`, spec `2026-10-09-os-ai-assistant-design.md` (§3.2 e §4.1).

## 1. Problema

A IA da OS só mexe em itens, cliente, veículo, relato e prazo. `_applyDraft` diz isso no próprio comentário: "Never receives or cancels". Para registrar um recebimento, a pessoa para de falar e entra em Receber, digita o valor, escolhe a forma e confirma.

A spec de outubro previa `setStatus`, `addPayment`, `addDiscount` e `markAsPaid`, que nunca foram feitos. A lógica de dinheiro já existe no app. Falta a IA entender o pedido e levar até ela.

## 2. Objetivo

Com uma frase, a pessoa registra o que aconteceu e confere em um toque.

| Frase | Cartão |
|---|---|
| "Pagou tudo no Pix" | Receber R$ 800 no Pix · quitada |
| "Deu 500 de entrada" (OS aprovada) | Receber R$ 500 · falta R$ 300 |
| "Deu 500 de entrada" (orçamento) | Aprovar · Receber R$ 500 · falta R$ 300 |
| "Pagou metade em dinheiro" | Receber R$ 400 em dinheiro · falta R$ 400 |
| "Ficou devendo 200" | Receber R$ 600 · falta R$ 200 |
| "Pagou ontem no cartão" | Receber R$ 800 no cartão, em 01/11 · quitada |
| "Dá 10% de desconto" | Desconto de R$ 80 · total R$ 720 |
| "O cliente aprovou" | Aprovar |
| "Terminei, pagou 300 no Pix" | Receber R$ 300 no Pix · falta R$ 500 · Concluir |

### Fora desta fase

- Nota fiscal, cobrança e comprovante por foto (Fase 2).
- Pedidos fora da tela da OS e perguntas como "quanto falta?" (Fase 3).
- Cancelar a OS, voltar para orçamento, remover pagamento e estornar pela IA.
- Mais de um pagamento por pedido.

## 3. Decisões

| Decisão | Escolha | Por quê |
|---|---|---|
| Quem grava | O app, depois do toque em Confirmar | A Function nunca grava a OS, e isso não muda |
| Confirmação | Sempre, para dinheiro e status | Um "pago" errado mexe no Financeiro, avisa o cliente e pode emitir nota. O bot gravava sem confirmar e errava |
| Valores no modelo | O modelo **não recebe** total, pago nem saldo | Ele não tem como errar uma conta que não faz. Manda só o que foi dito, e também menos dados saem do Brasil no caso do Claude |
| Conta do valor | No app, no momento do cartão, com o saldo atual da OS | O saldo já inclui os itens mudados na mesma frase |
| Regras e permissões | No app, com as mesmas funções de Receber | O servidor não sabe qual é a OS. As regras do Firestore continuam sendo a última barreira |
| "Pagou tudo" | `addPayment(saldo)`, não `markAsFullyPaid` | `markAsFullyPaid` não aceita forma nem data e não funciona offline |
| Origem do pedido | Só fala ou texto | Foto nunca gera ação nesta fase. Comprovante é da Fase 2 |

## 4. Tela

Depois de aplicar itens e campos como hoje, se houver ação, abre uma folha:

```
Confere?                         (título)
OS 186 · Revenda Sul

Receber R$ 300 no Pix       ›
Falta R$ 500
Marcar como pronta

[ Confirmar ]                    (azul, o único)
Agora não
```

- A linha de receber abre a `ReceivePaymentSheet` já preenchida (`initial: ReceiveDraft`), para mudar valor, forma ou data. A linha de desconto abre `showReceiveDiscountSheet`.
- O nome do status vem de `config.getStatus`, com a palavra do segmento.
- O valor sai do `FormatService`, e a forma de `paymentMethodLabel`.
- "Agora não" descarta só as ações. Os itens continuam na OS, com o "Desfazer" de sempre.

Depois de confirmar, a nota acima da barra mostra "Recebido R$ 300 · falta R$ 500 · Desfazer". Se a OS mudou de status, o "Avisar o cliente?" aparece como hoje.

### Avisos no cartão

| Situação | Texto na folha |
|---|---|
| Vai emitir nota automática | "Isso também emite a nota fiscal." |
| Tem cobrança aberta | O texto atual `receiveChargeAdjusts` |

A nota automática é avisada só quando as ações viram a OS: `nfseAutoIssue: paid` e o saldo chega a zero (por pagamento ou desconto), ou `nfseAutoIssue: completed` e o status vira `done`. A OS que já teve nota não dispara outra, mas a folha não precisa tratar isso: é só um aviso a mais.

A tela da OS não conhece a cobrança aberta. A folha cria um `OrderChargeController` para ler `openCharge`, e o Confirmar espera essa leitura.

### Quando a ação não pode acontecer

A IA nunca finge que fez. A folha mostra o motivo no lugar da linha, ou uma nota se não sobrar nada para confirmar.

| Situação | Comportamento |
|---|---|
| Quem fala não pode receber | "Só quem recebe pagamentos pode registrar isso." |
| Quem fala não pode dar desconto (`canViewFinancialReports`) | "Só quem cuida do financeiro pode dar desconto." O consultor recebe, mas não dá desconto |
| Empresa sem "Valores e cobrança" | Ignora dinheiro, sem aviso; a empresa não usa essa parte |
| OS cancelada | "Esta OS está cancelada." |
| OS sem valor ou já quitada | "Esta OS não tem nada a receber." |
| Valor acima do saldo | Abre a linha de receber com o saldo e diz "Falta só R$ 300." Nunca grava a mais |
| Desconto acima do saldo | Abre o desconto com o máximo |
| Valor em branco ("pagou uma parte") | Abre a linha de receber para digitar |
| Checklist pendente ao concluir | A linha "Pronta" sai e aparece "Falta terminar 1 checklist." O resto segue |
| Sem permissão para o status | A linha sai e aparece `permissionDenied` |

## 5. Contrato

A entrada de `POST /v1/app/ai/order-assist` não muda. A resposta do modelo ganha um campo opcional:

```jsonc
"actions": {
  "payment": {
    "kind": "full" | "value" | "percent" | "leaving",
    "value": 500,              // obrigatório, menos em "full"
    "method": "pix" | "cash" | "card" | "other" | null,
    "paidDate": "2026-11-01"   // só quando foi dito
  },
  "discount": { "kind": "value" | "percent", "value": 10 },
  "status": "approved" | "progress" | "done"
}
```

| `kind` | Frase | Conta no app |
|---|---|---|
| `full` | "pagou tudo", "quitou" | saldo |
| `value` | "deu 500" | 500 |
| `percent` | "pagou metade" | saldo × 50% |
| `leaving` | "ficou devendo 200" | saldo − 200 |
| sem `value` | "pagou uma parte" | abre a linha para digitar |

Se o valor sair zero ou negativo, a linha abre para digitar.

Desconto `percent` usa o total atual da OS, como a folha de desconto.

**Servidor:** zod com `.catch(undefined)` em cada parte, para uma ação inválida não derrubar o rascunho. Data futura é descartada. `canceled` e `quote` não são aceitos.

**Resposta ao app:** `actions` (ou `null`), mais `nfseAutoIssue`, com o momento da emissão automática (`paid` ou `completed`), só quando houver `actions` e a empresa tiver `nfseEnabled`, `nfseReady` e `asaasConnected`, as mesmas condições de `autoIssueInvoice`. Vem do servidor porque `GET /setup` é só de dono e admin, e quem recebe pode ser gerente ou consultor.

**App antigo:** ignora o campo. A frase só de pagamento continua dando "nada encontrado", como hoje.

### Regras novas no prompt

- `payment` só para dinheiro que **já entrou**. "Vai pagar", "paga sexta" e "paga na entrega" não são pagamento.
- `discount` só para desconto pedido. "Cortesia" e "garantia" continuam sendo item com valor 0.
- "Óleo 200, já pago" é item + `payment.full`.
- "Óleo 200" sozinho nunca gera pagamento.
- "Aprovou" → `approved`; "comecei" → `progress`; "pronto", "terminei", "finaliza" → `done`.
- Ações vêm só do que foi dito ou digitado, nunca de foto.
- Nunca calcular valores. Devolver o que foi dito.

## 6. Execução

Ao tocar em Confirmar, nesta ordem:

1. **Desconto:** `addDiscountTransaction`.
2. **Aprovar**, se a OS é orçamento e há pagamento: `_store.setStatus('approved')`. Orçamento não aceita pagamento.
3. **Pagamento:** `addPayment(valor, paidAt: paidAtFor(dia), paymentMethod: forma)`, com o saldo recalculado nesta hora.
4. **Status pedido:** `_store.setStatus`.

Se um passo falhar, os seguintes não rodam, e a nota diz o que entrou e o que faltou. As mensagens são as de `_paymentFailureMessage`.

`_trySetStatus` abre diálogos e não devolve resultado, então não serve aqui. A permissão (`canChangeStatus`) e o checklist pendente são conferidos antes, ao montar a folha.

`_doRegister` sai de `payment_management_screen.dart` para um helper usado pelas duas telas, e `_paymentFailureMessage` vai junto. O "Avisar o cliente?" só é oferecido no fim, uma vez, com `_offerNotifyCustomer`.

### Pagamento em orçamento sem pedido de aprovação

"Deu 500 de entrada" num orçamento adiciona a linha "Aprovar", visível na folha. Quem pode receber mas não pode aprovar vê o motivo, e nada é gravado.

### Nova OS

A OS ainda não existe. As ações ficam guardadas e a folha abre logo depois de "Salvar OS". O "Desfazer" do rascunho descarta as ações junto. Sair sem salvar também.

### Desfazer

Na nota, depois de confirmar, por ordem inversa:

- Pagamento e desconto: `removeTransaction`, com o índice achado pelo id da transação. Precisa de internet.
- Status: volta ao anterior, se `canChangeStatus` permitir. Senão fica, e a nota avisa.
- Nota já emitida não é cancelada. Com `nfseAutoIssue`, a mensagem de desfazer diz "A nota fiscal continua emitida."

## 7. Cota, privacidade e custo

- Conta um uso por pedido, como hoje. Não muda a cota.
- Logs seguem sem texto, valor ou transcrição.
- Eventos em `logAiEvent`, sem valores: `ai_action_proposed {types}`, `ai_action_confirmed {edited}`, `ai_action_dismissed`, `ai_action_undone`, `ai_action_failed {step}`.

## 8. Testes

**Functions** (`order-assist.service`): parse de cada `kind`, ação inválida não derruba o rascunho, data futura descartada, `canceled` recusado, `nfseAutoIssue` só com a nota pronta.

**App:**
- Conta de cada `kind`, incluindo item mudado na mesma frase e valor acima do saldo.
- Cada linha da tabela da §4, por papel: dono, gerente, consultor (própria OS e de outro), técnico.
- Ordem de execução, parada no meio, desfazer e OS offline.
- Nova OS: folha depois de salvar, e descarte com "Desfazer".

**Modelo:** arquivo com pelo menos 40 frases reais, nos dois provedores (Gemini e Claude) e nos três idiomas. Inclui as do bot em `~/Backups/praticos-insights/bot-discovery/`.

| Critério | Meta |
|---|---|
| Frase no futuro virando pagamento | 0 |
| Item com preço virando pagamento | 0 |
| Tipo e valor corretos | 95% |

Se a meta não bater, a função não vai para produção.

## 9. Lançamento

1. Servidor primeiro, com `actions` atrás de `companies/{id}/settings/ai.financeActions`, ou de `config/ai.financeActions` para todas (mesma lógica de `enabled` em `resolveAiSettings`, e opção nova no `npm run ai`). Desligado, a resposta vem com `actions: null`.
2. Ligar na Demo Oficina e testar no iPhone.
3. Ligar para o Manuel. Olhar 2 semanas de eventos.
4. Ligar para todos se **80% ou mais** dos cartões forem confirmados sem editar, e **5% ou menos** desfeitos.

## 10. Documentação

Atualizar `docs/AI_ORDER_ASSIST.md` e `docs/FINANCEIRO.md`, a documentação pública do site nos três idiomas e a seção "Assistente de IA" da política, se o texto não cobrir valores falados.

## 11. Em aberto

1. O texto dos botões e do título precisa passar pelo Rafael: "Confere?", "Confirmar" e "Agora não".
2. Teste de usabilidade com um dono de oficina antes de ligar para todos: a palavra "Receber" no cartão é clara para quem disse "pagou"?
