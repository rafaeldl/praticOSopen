# Protótipo das telas do app web

Protótipo navegável, com dados fictícios, para o dono ver e opinar. Não é código de produção, não usa Firebase nem API, e não reabre o projeto do app web, suspenso em 2026-11-01.

Abrir sem instalar nada:

    open dist/index.html

Alterar: `npm install`, `npm run dev`. Gerar de novo: `npm run build`. Testes: `URL=file://$PWD/dist/index.html node tests/run.mjs`.

Telas: Início, Ordens de serviço (lista e quadro), Agenda, Financeiro (resumo e Receber), Clientes, Notas fiscais, Catálogo, Importar clientes e Entrada (em Ajustes do protótipo). Mandar ao cliente, link de pagamento e impressão abrem de dentro da OS. Botões tracejados "Simular" fazem o papel do cliente.

No celular (até 640 px): abas embaixo, tabelas viram listas, painéis ocupam a tela e cada aviso sobe de baixo. Arrastar sai: no Quadro usa o menu …, e na Agenda a lista do dia abre a OS para marcar a data. Semana da Agenda e seleção em lote na lista de OS ficam só no computador.

## Direção visual

O `docs/WEB_APP_DESIGN.md` do PR #473 foi escrito antes do tema Campo (#488). Diferenças:

| Item | PR #473 | Protótipo |
|---|---|---|
| Fontes | Archivo, IBM Plex Sans, IBM Plex Mono | Outfit, DM Sans, IBM Plex Mono (site atual) |
| Tinta | Grafite | Azul-marinho (site atual) |
| Navegação | Coluna neutra | Faixa azul-marinho, como no site e no login |
| Ação principal | Azul, como no app | Amarelo do site por padrão; azul disponível em Ajustes do protótipo |
| IA em um registro | Faz e oferece Desfazer | Pergunta antes, como pedido no brief |

Mantidos do PR #473: regras de tela, mestre-detalhe, atalhos, status com ponto e texto, tokens novos de contraste para aviso e borda de campo.

O amarelo foi escolhido porque, numa ferramenta densa, o azul já marca link, linha selecionada, OS aprovada e o ✦ da IA. O amarelo só aparece na ação principal.

## Limites do protótipo

- O relógio fica parado às 10:40 do dia atual, para os exemplos contarem sempre a mesma história.
- Nada é enviado. "Mandar ao cliente" copia a mensagem. O assistente só reconhece palavras do catálogo e cobrança.
- O Financeiro tem um histórico fictício de 6 meses que só existe nele: essas OS antigas não aparecem na lista nem na ficha do cliente, e a linha abre o cliente. Nos primeiros 7 dias do mês ele abre no mês anterior. Como no app, não há despesas. Falta receber conta só as OS prontas; no app inclui também o saldo de OS em andamento com sinal pago.
- Os dados voltam ao início quando a página é recarregada. Só as preferências ficam salvas no navegador.
- Sem login, permissões, tempo real, impressão, importação, nota fiscal, checklists e comentários do cliente.

Sigla mantida: "OS", explicada uma vez no primeiro acesso (decisão do dono, 2026-11-02).
