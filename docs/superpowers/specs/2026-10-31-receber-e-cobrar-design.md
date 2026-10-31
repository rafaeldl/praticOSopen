# Receber e cobrar na mesma tela

Revê `2026-10-14-receber-cliente-design.md` e `2026-10-10-telas-receber-design.md`. Doc técnica: `docs/FINANCEIRO.md`.

## Problema

A tela perguntava "quanto recebeu?" antes de saber se o dinheiro já tinha entrado. Mandar cobrança, o caso de quem ainda não recebeu, ficava no "…" (várias OS) ou num link no fim da tela (uma OS), com três nomes diferentes.

## Decisões

1. **Dois botões do mesmo tamanho:** azul "Marcar como recebido" (o caso mais comum é o balcão) e cinza "Mandar cobrança".
2. **O formulário vai para uma sheet.** Na tela ficam só cliente, "A receber", valor, botões e OS. Custa um toque a mais no balcão e evita marcar dinheiro por engano.
3. **Uma estrutura para uma ou várias OS.** Mudam só as marcações e o "Já recebido" embaixo.
4. **Boleto não tem botão próprio.** A cobrança à vista deixa o cliente escolher Pix, boleto ou cartão no link.
5. **Cobrança enviada:** nada azul, porque quem age é o cliente. "Mandar de novo" em cinza e "Marcar como recebido" como link. Vencida: vermelho e "Mandar de novo" azul, porque a fatura vencida ainda aceita pagamento.
6. **As OS continuam marcáveis com cobrança aberta,** porque a cobrança pode cobrir só parte delas e o recebimento vale para as marcadas.
7. **Link de uma OS aparece na linha dela** em "Receber de João", e cobrança nova que o substitui pede confirmação.
8. **"Próxima cobrança" cobra o cliente, não uma OS.** Com várias OS abre esta tela já na sheet de cobrança. Sem Asaas continua "Qual OS?".

## HIG

- Buttons: "use a prominent style (accent-color background) for the most likely action".
- Buttons: "Distinguish the preferred choice by style, not size."
- Pull-down buttons: "keep primary actions easily discoverable".
- Feedback: "integrating status feedback near the item it describes".
