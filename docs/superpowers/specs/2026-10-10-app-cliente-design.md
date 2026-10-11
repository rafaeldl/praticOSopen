# App do cliente final: acompanhar a OS pelo link

**Data:** 2026-10-10 · **Status:** direção aprovada pelo Rafael, protótipo pronto, implementação não começou.
**Protótipos:** canvas https://claude.ai/artifact/NfHsv1Ge52LXGdpd9ZYihz, página **"App do cliente"** (12 pranchas ligadas pelo Play; comece em "1 · Recebe o link no WhatsApp").
**Base:** `docs/SHARE_LINK.md`, `docs/ASAAS_INTEGRATION.md`, `docs/APP_DESIGN_SYSTEM.md`.

## Por que importa

O link da OS é a única parte do PraticOS que chega a quem **não** é cliente pagante: cada OS compartilhada põe a marca na frente de um motorista, um dono de celular, um síndico. Parte deles tem um negócio de serviço. Hoje esse contato não é aproveitado nem medido.

## O que o cliente vê hoje

A página é Nuxt (`firebase/web`, Cloud Run `praticos-web`), em `/q/{token}`, e lê `GET /public/orders/{token}` (`firebase/functions/src/routes/public/orders.routes.ts`, aqui `ORD`).

| O que o cliente faz | Hoje | Onde |
|---|---|---|
| Ver status, número, previsão | Sim, com barra de progresso | `firebase/web/pages/q/[token].vue:22-34`, `components/order/OrderHeader.vue`, `OrderProgressCard.vue`; `ORD:115` |
| Ver serviços, peças e valores | Sim (total, desconto, pago, saldo) | `OrderSummaryCard.vue`, `OrderServicesCard.vue`, `OrderProductsCard.vue`; `ORD:169-186` |
| Ver fotos | Sim, galeria com lightbox | `OrderPhotosCard.vue`, `PhotoLightbox.vue`; `ORD:189` |
| Aprovar / não aprovar orçamento | Sim, só com status `quote` e permissão `approve`; recusar cancela a OS | `[token].vue:119-137,219-243`, `OrderQuoteApprovalCard.vue`; `ORD:239` (approve), `ORD:321` (reject) |
| Comentar | Sim, até 2000 caracteres | `OrderCommentsSection.vue`; `ORD:402`, `ORD:479` |
| Pagar (Asaas) | Sim: botão abre a fatura do Asaas em outra aba (Pix, boleto ou cartão escolhidos lá); recarrega ao voltar | `OrderChargeAction.vue:5`, `utils/charge.ts`, `[token].vue:166-176`; `ORD:58-110` |
| Avaliar | Sim, 1 a 5 estrelas, só com status `done`, uma vez | `OrderRatingSection.vue`; `ORD:511` |
| Ver checklist | **Não funciona:** a página passa `order.forms`, mas a API não devolve `forms` | `[token].vue:47,73`, `OrderChecklistCard.vue`; `ORD` sem `forms` |
| Falar com a oficina | **Não:** telefone, e-mail e endereço vêm na resposta, mas não aparecem | `ORD:201-210`; nada em `components/order` |
| Baixar PDF | Não | — |
| Histórico do veículo/aparelho | Não (só a OS atual) | — |
| Idioma | pt, en, es (`?lang=` ou navegador) | `composables/useOrderI18n.ts:357-369`, `OrderLangSwitcher.vue` |
| Marca PraticOS | "Powered by PraticOS", link para o site | `OrderFooter.vue:4-17` |
| Convite / indicação | Não | — |
| Medição | **Nenhuma** no navegador; só `viewCount` no servidor | `functions/src/middleware/share-token.middleware.ts:66` |
| Prévia no WhatsApp | Genérica: título fixo, sem oficina, sem imagem | `[token].vue:182-192` (`og:title` = `pageTitle`) |
| Instalar / atalho | Sem manifest nem service worker | `firebase/web/nuxt.config.ts`, `public/` só com `logo.png` |

**Validade do link:** 7 dias por padrão (`share-token.service.ts:22-26`, `share_link_service.dart:32`), 14 ou 30 no app (`share_link_sheet.dart:120-141`). Vencido ou revogado, a página mostra um erro genérico (`[token].vue:10-18`) sem saída: não diz quem procurar, apesar de o telefone da oficina estar no payload.

### Problemas

1. **Tudo de uma vez.** De 8 a 10 blocos empilhados (`[token].vue:26-55`). O cliente não sabe o que fazer: aprovar? pagar? esperar?
2. **Sem contato.** O cliente volta para o WhatsApp e procura a conversa. Na tela de erro, fica sem saída.
3. **Link morre antes da OS.** Uma OS que demora mais de 7 dias perde o acompanhamento.
4. **A marca não trabalha.** A prévia do link não mostra a oficina, e o rodapé é um link solto.
5. **Nada medido.** Não sabemos quantos abrem, aprovam, pagam ou tocam no PraticOS.
6. **Pequenas falhas:** checklist que nunca aparece; `OrderHeader.vue:145` lê `customer.address`, que a API não manda.

## Formato: web refeita agora, app depois

Decisão do Rafael (2026-10-10): **web agora, app depois.**

| Opção | Custo | Ganho de divulgação | Veredito |
|---|---|---|---|
| **Web melhorada + PWA** (mesmo link) | Baixo: só `firebase/web` e a rota pública | Todo cliente vê, sem instalar | **Agora** |
| Abrir no app PraticOS, área "Minhas OS" | Alto: modo cliente no app (auth, regras, revisão da Apple) | Alto para quem instala, mas pouca gente instala para ver uma OS | **Fase 2**, via universal link, só para quem já tem o app |
| App Clip / Instant App | Alto: target nativo novo, assinatura (`risk:high`) | Médio | Só se os números da fase 1 pedirem |
| App nativo separado | Muito alto: segundo app nas lojas | Baixo | Não |

**Por que não começar pelo app:** o cliente recebe o link no WhatsApp e quer uma resposta em segundos. Pedir instalação perde a maioria antes de ver a OS. A web refeita entrega o mesmo efeito de rede (marca, indicação, convite) sem essa barreira. O app entra depois para quem já tem: o link abre direto nele (universal link), e a web convida a baixar só **depois** de aprovar ou avaliar, nunca antes.

**PWA leve:** manifest com o nome e o ícone da oficina e o botão "Pôr na tela de início" depois de aprovar. Sem service worker offline na fase 1, porque a OS muda e precisa vir do servidor.

## Jornada (pranchas)

Regras do app que valem aqui: uma pergunta por tela, **"O que falta?"** no bloco `accentSoft`, um botão azul, cor nunca sozinha, português do dia a dia, textos 34/22/19/17/15, modo escuro.

| # | Prancha | Pergunta respondida | Botão azul |
|---|---|---|---|
| 1 | `cli-whatsapp` | O que é esse link? A prévia mostra o logo da oficina, "OS 183 · VW Gol 2018" e o que falta | — |
| 2 | `cli-orcamento` | "Você aprovar o orçamento de R$ 1.250" + previsão + itens | Aprovar R$ 1.250 (recusar e tirar dúvida viram link) |
| 3 | `cli-aprovado` | Confirmação curta ("A oficina já foi avisada") + "Pôr na tela de início" | Ver o andamento |
| 4 | `cli-andamento` | "Nada com você" + previsão + passos com texto (Recebido, Aprovado, No serviço · agora, Pronto) + fotos | nenhum: não há ação do cliente |
| 5 | `cli-pagar` | "Pagar R$ 950. Está pronto para retirar." Pix, cartão ou boleto | Pagar R$ 950 |
| 5b | `cli-pagar-sem-online` | Empresa sem Asaas: "Retirar o carro e pagar R$ 950 na oficina" + endereço | Combinar a retirada (WhatsApp) |
| 6 | `cli-pago-avaliar` | "Pago. Obrigado!" + "Como foi o serviço?" (5 estrelas de 52 px) | as estrelas são a ação |
| 7 | `cli-avaliado` | Histórico deste veículo nesta oficina + "Indique a oficina" | — |
| 8 | `cli-historico` | "Suas OS", guardadas só neste celular, agrupadas por veículo e oficina | — |
| — | `cli-andamento-escuro` | Modo escuro da tela 4 | — |
| — | `cli-expirado` | "Este link venceu" → pedir link novo no WhatsApp, com mensagem pronta | Pedir link no WhatsApp |
| — | `cli-app-minhas-os` | Fase 2: o mesmo cliente no app PraticOS como usuário comum | Ver o orçamento |

Em toda tela, o topo tem o logo e o nome da oficina e o botão **"Falar"** (WhatsApp da empresa, já no payload). Comentários continuam existindo, mas saem do caminho principal: "Falar" leva ao WhatsApp, onde a conversa já acontece.

**O que muda no conteúdo:** o bloco "O que falta?" vem de uma função pura `customerNextStep(order, charge, permissions)` em `firebase/web/utils/`. Com testes, ela devolve `approve | wait | pay | payAtShop | rate | done` e escolhe a frase e o botão. O resto da página fica embaixo, recolhido por prioridade.

## Marca: a oficina é o rosto

O cliente confia na oficina, não no PraticOS. Se a nossa marca vier na frente, o link parece propaganda ou golpe. Além disso, o dono da oficina precisa sentir que a página é **dele** para mandar o link sempre.

- **Oficina:** logo, nome, "Falar", prévia do WhatsApp (`og:title` = "OS 183 · VW Gol 2018 · Auto Center Silva", `og:image` = logo da empresa, `og:description` = o que falta).
- **PraticOS:** só "Feito com PraticOS" no rodapé, em `textSecondary`. Depois da avaliação, com o cliente satisfeito, entra "· Conheça" (link com UTM).
- **Nunca:** banner, pop-up, pedido de instalação antes da aprovação, ou convite enquanto há algo a fazer (aprovar, pagar).

## Divulgação sem ser chato

| Momento | O que aparece | Por quê |
|---|---|---|
| Prévia no WhatsApp | Logo e nome da oficina | Mais cliques no link (efeito indireto) |
| Rodapé, sempre | "Feito com PraticOS" | Discreto, como "Enviado do iPhone" |
| Depois de avaliar | "Indique a [oficina]" (manda o contato da oficina no WhatsApp) | Ajuda o nosso cliente pagante a ganhar clientes. É a indicação que ele quer |
| Depois de avaliar | "Feito com PraticOS · Conheça" | Quem presta serviço reconhece o valor depois de usar como cliente |
| Fase 2, no app | "Você também presta serviço? Abrir a minha empresa no PraticOS" | Converte cliente em empresa no mesmo app |

### Medição (GA4 no `firebase/web`, sem dado pessoal)

Eventos com parâmetros só técnicos (`segment`, `status`, `has_charge`, `lang`), sem token, nome, telefone ou valor:

`customer_link_open`, `customer_quote_approve`, `customer_quote_reject`, `customer_pay_click`, `customer_rating_submit`, `customer_contact_click`, `customer_add_to_home`, `customer_referral_click`, `praticos_footer_click` (com UTM `utm_source=os_link`), `customer_link_expired_view`.

Funil para olhar: abriu → aprovou → pagou → avaliou → tocou em PraticOS. **Sem meta numérica antes de medir:** a primeira entrega mede o ponto de partida. Consentimento de cookies conforme a política atual do site (GA4 com `analytics_storage` só após aceite, se o site já faz assim; senão, sem cookies e só contagem por evento).

## Privacidade

O link é público: quem o tiver vê a OS.

**O cliente vê:** nome da oficina, logo, telefone (para "Falar") e endereço (só na retirada sem pagamento online); número da OS; nome do cliente mascarado ("Ana R."); veículo ou aparelho, com placa/serial mascarados; itens e valores; fotos que a oficina pôs na OS; previsão; nome do técnico nos comentários (como hoje).

**Nunca aparece:** telefone, e-mail ou endereço do cliente; custo interno, margem, notas internas, comentários não marcados como visíveis; ids do Asaas e do Firestore; outras OS da oficina.

**Ajustes na API** (na mesma etapa da web):
- tirar `company.email` da resposta se não for usado;
- tirar o `id` de `devices` (`ORD:154-168`);
- pôr `requireSharePermission` também em `GET /:token/comments` e `POST /:token/rating`.

**Histórico "Suas OS":** fica no `localStorage` do navegador (token, número, oficina, veículo, status). Nada novo no servidor e nenhum cadastro. A tela diz "Guardadas só neste celular". Ao abrir uma OS do histórico com o link vencido, a pessoa cai na tela "Este link venceu".

**Validade:** passar o padrão para "enquanto a OS estiver aberta + 30 dias depois de concluída", porque o link morrer no meio do serviço quebra o acompanhamento. Mudar a regra de expiração é `risk:high`, então vai em PR separado com revisão.

**Repositório público:** pranchas e spec usam dados fictícios (Auto Center Silva, Ana R., Cell Fix). Nenhum dado real de cliente entra no repo.

## Fase 2: o mesmo app para o cliente

- Universal link (`/q/{token}`): com o app instalado, abre a OS no app. Sem o app, abre a web (comportamento padrão).
- Usuário sem empresa vira "cliente": tela "Minhas OS" (`cli-app-minhas-os`) com as OS de todas as oficinas vinculadas ao telefone verificado.
- "Abrir a minha empresa" leva ao primeiro acesso de sempre (ramo → seu negócio).
- Exige: login por telefone, vínculo cliente↔telefone entre empresas, regras do Firestore e revisão da Apple (4.2/funcionalidade mínima). Tudo `risk:high`. Decidir com os números da fase 1 (quantos clientes únicos abrem links por mês e quantos voltam).

## Ordem de implementação

| # | Etapa | Onde | Risco |
|---|---|---|---|
| 1 | Prévia do WhatsApp com oficina, OS e o que falta (`og:*` no SSR) | `firebase/web/pages/q/[token].vue` | `risk:low` |
| 2 | GA4 + eventos acima | `firebase/web` | `risk:low` |
| 3 | Botão "Falar" (WhatsApp da oficina) e tela de link vencido com saída | `firebase/web`; a API precisa devolver telefone também no 401 (só nome + telefone da empresa) | `risk:low` (web), `risk:high` se mexer no middleware |
| 4 | Bloco "O que falta?" (`customerNextStep`, com testes) e reorganização das telas 2-6 | `firebase/web` | `risk:low` |
| 5 | Ajustes de privacidade na API (campos, permissões) e devolver `forms` resumido | `functions/src/routes/public/orders.routes.ts` | `risk:high` (Function pública de produção) |
| 6 | Histórico local, manifest e "Pôr na tela de início" | `firebase/web` | `risk:low` |
| 7 | Indicação + "Conheça" depois de avaliar | `firebase/web` | `risk:low` |
| 8 | Validade do link enquanto a OS estiver aberta | `share-token.service.ts`, app | `risk:high` |
| 9 | Fase 2: universal link + "Minhas OS" no app | app, auth, rules | `risk:high`, decidir com dados |

Cada etapa vem com teste (Vitest em `firebase/web/tests`, `npm test` em `firebase/functions`) e atualização de `docs/SHARE_LINK.md`.
