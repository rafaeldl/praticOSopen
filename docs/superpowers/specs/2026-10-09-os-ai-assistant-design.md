# Tela da OS com assistente de IA — design

**Data:** 2026-10-09 · **Status:** proposta para revisão · **Padrão visual:** `docs/APP_DESIGN_SYSTEM.md` (PR #326)
**Protótipos:** canvas https://claude.ai/artifact/NfHsv1Ge52LXGdpd9ZYihz — linha **E** (E1 a E4) e prancha "Padrão do app". As linhas A–D foram descartadas por excesso de informação.

## 1. Por que

O bot de WhatsApp foi desligado em 2026-10. Ele era pouco usado no geral, mas muito usado por quem usava: 7 empresas criaram OS por ele, e duas (uma funilaria e uma climatização) abriram cerca de 300 OS em três meses. O que esses usuários faziam, em ordem de volume:

1. Abrir OS com **foto + texto ou áudio curto** ("cliente, capô 500, polimento 450").
2. Deixar a IA **ler o aparelho na foto**: placa, marca e modelo no carro; marca, modelo, BTU e série na etiqueta do ar-condicionado.
3. **Ditar itens com valor** numa OS aberta ("aerofólio 300", "valor 550").
4. **Mudar status com uma palavra** ("Aprovado", "pode finalizar") e registrar pagamento.
5. **Anexar fotos**, inclusive as que chegam do cliente pelo WhatsApp.

As falhas do bot também ensinam:
- foto e texto chegando separados viravam **OS duplicada** ou com cliente errado;
- o bot **gravava sem confirmar** e às vezes dizia que fez o que não fez (status errado, valor apagado em vez de alterado);
- serviços eram criados no catálogo a cada pedido (**catálogo poluído**).

Ao mesmo tempo, a tela da OS atual (`lib/screens/order_form.dart`, ~3.300 linhas) mostra tudo de uma vez e é difícil para o nosso usuário, que tem pouca intimidade com tecnologia.

O discovery completo (agregado, fora do repositório por conter dados de clientes) está em `~/Backups/praticos-insights/bot-discovery/DISCOVERY.md`.

## 2. Objetivo

Trazer para dentro do app o que o bot fazia bem, sem os erros dele, numa tela da OS simples:

- **A tela responde "o que eu faço agora?"** e mostra só o que existe na OS.
- **A IA sempre propõe; quem grava é o usuário**, com um toque em "Está certo, pode fazer".
- Uma sessão de captura (várias fotos + fala) gera **uma** OS.
- A IA **escolhe do catálogo** e só sugere criar item novo quando não houver nada parecido.

Fora de escopo: as demais telas do app (trabalho separado de discovery de telas), cadastro de empresa por conversa (2 de 19 concluíram no bot), lembretes/agenda por voz, envio automático de mensagem ao cliente.

## 3. Experiência

### 3.1 Tela da OS (E1)

Seguindo as 6 zonas do padrão:

1. **Topo:** voltar · "OS 186" · menu "…".
2. **Título:** aparelho em destaque (ex.: "Classic 1.0 · NXS 8620") e cliente embaixo, com a foto de capa se houver.
3. **Próximo passo:** um bloco azul claro com frase simples ("Aprovada pelo cliente. Próximo passo: começar o serviço") e o **único botão azul** da tela. O botão muda conforme o status:

   | Status | Frase | Botão |
   |---|---|---|
   | `quote` | Orçamento pronto para o cliente | Cliente aprovou |
   | `approved` | Aprovada pelo cliente | Começar o serviço |
   | `progress` | Serviço em andamento | Marcar como pronto |
   | `done`, falta receber | Pronto. Falta receber R$ X | Receber |
   | `done`, pago | Tudo certo: pronto e pago | Enviar para o cliente |
   | `canceled` | OS cancelada | Reabrir |

4. **Conteúdo:** "O que vai ser feito" (serviços e peças com valor; toque abre o item). Depois só os blocos que **existem** nesta OS: checklist, contrato, entrega, endereço, comentários, outros aparelhos, documentos.
5. **Resumo:** "Total R$ 350 · Falta receber R$ 166" e o botão secundário "Receber".
6. **Barra fixa:** foto e **"Falar o que fazer"** (grafite). Toque longo em "Falar" abre o campo de texto, para quem prefere digitar.

O menu "…" guarda o que é raro: adicionar checklist, contrato, entrega, endereço, desconto, outro aparelho, documento, responsável, gerar PDF, link do cliente, cobrança Asaas, cancelar OS, apagar OS.

Status usa ponto colorido + texto; comentário interno perde o selo laranja (correções do padrão).

### 3.2 Falar com o assistente (E2)

1. O usuário toca em "Falar", fala e solta (ou digita, ou tira foto).
2. A tela mostra o que foi entendido ("Você disse: …") e, abaixo, **"Vou fazer isto na OS 186:"** em frases simples, com o que muda destacado em amarelo do logo:
   - "Colocar 2 para-choques, R$ 850 cada"
   - "Marcar como aprovada pelo cliente"
   - "Total passa de R$ 350 para R$ 2.050"
3. Botões: **"Está certo, pode fazer"** (azul) e "Falar de novo". Cada linha pode ser desmarcada ou tocada para corrigir antes de aplicar.
4. Quando a IA não tem certeza, ela pergunta em vez de chutar ("Qual o valor da porta traseira?") com o campo já aberto.
5. Ações destrutivas (remover item, remover pagamento, cancelar OS) aparecem em vermelho e pedem um segundo toque. Apagar a OS **não** é feito pela IA.

### 3.3 Nova OS (E3 e E4)

**E3 — Começar:** três opções grandes com exemplo de uso:
- **Tirar foto** ("do carro, da placa ou da etiqueta");
- **Falar** ("Revenda Sul, capô 500 e polimento 450");
- **Preencher eu mesmo** (fluxo manual).

Na captura, o usuário tira quantas fotos quiser e pode falar no meio. Nada é enviado até tocar em **"Pronto"**. Uma sessão = um rascunho = uma OS. Isso elimina a duplicata que o bot criava.

**E4 — Conferir antes de salvar:** cliente e aparelho com "Trocar" (mostrando os parecidos já cadastrados), serviços com valor e as perguntas do que faltou ("Porta traseira: qual o valor?"). Um botão só: **"Salvar OS"**. As fotos da captura vão anexadas.

### 3.4 Fotos vindas do WhatsApp (N3)

No WhatsApp, o usuário seleciona as fotos → Compartilhar → PraticOS. O app abre "4 fotos recebidas":
- no topo, a OS sugerida pela IA (placa ou série reconhecida na foto);
- abaixo, as OS em aberto, com busca por número, cliente ou placa;
- no fim, "Criar OS nova com estas fotos", que leva à E4 com as fotos já carregadas.

## 4. Arquitetura

```
App (Flutter)                               Cloud Functions (southamerica-east1)
─────────────                               ─────────────────────────────────────
Barra "Falar" / captura / share  ──audio,──▶ aiOrderAssist  (onCall, App Check, auth)
  grava áudio (m4a) + fotos       fotos,       1. valida usuário/empresa e cota
  sobe fotos ao Storage           OS atual     2. monta contexto: OS compacta, segmento,
                                               │   campos customizados, status válidos
                                               3. Gemini (Vertex AI) com responseSchema
                                               4. resolve nomes contra o catálogo
                                               │   (mesma lógica do unified-search do bot)
Cartão de proposta (E2/E4) ◀──operações──────  5. incrementa uso e devolve proposta
  usuário confirma                tipadas         (NÃO grava a OS)
  OrderStore aplica cada operação
  (mesmos métodos da tela manual)
```

Decisões:

- **IA só no servidor.** Chave e prompts ficam fora do app, a cota é aplicada no servidor e o modelo pode ser trocado sem nova versão nas lojas. Vertex AI pela conta de serviço do projeto, sem chave de API. Modelo: Gemini Flash (o mesmo da família que o bot usava); escolha final no piloto.
- **Áudio vai direto para o Gemini**, que transcreve e interpreta numa chamada. Evita a permissão de reconhecimento de fala do iOS e lida melhor com barulho de oficina e sotaque. A transcrição volta junto para a tela mostrar "Você disse".
- **A Function não grava a OS.** Ela devolve operações; o app aplica com os métodos que já existem no `OrderStore`. Sem regras novas no Firestore para a OS, e a proposta é sempre reversível até o toque.
- **Fotos sobem antes** para `tenants/{companyId}/orders/{orderId}/photos/` (ou `tenants/{companyId}/ai-inbox/{sessionId}/` na OS nova) e a Function recebe só os caminhos. Elas contam na cota de fotos como hoje.
- **Catálogo:** a lógica de busca de `routes/bot/unified-search.routes.ts` vira um serviço compartilhado (`services/catalog-match.service.ts`) usado pelo bot/MCP e pela IA. A proposta traz o item encontrado e até 3 parecidos para troca.
- **Segmento:** o contexto inclui o rótulo do aparelho e os `customFields` do segmento (`SegmentConfigService`), para a leitura de placa/etiqueta cair nos campos certos (`serial`, `manufacturer`, `customData['device.btu']` etc.).
- **Idioma:** a IA responde no idioma do app (pt, en, es).

### 4.1 Operações

Contrato tipado (zod na Function, modelo Dart no app). Cada operação traz `confidence` e, quando aplicável, `question` (o que perguntar ao usuário).

| Operação | Campos principais | Aplicada por |
|---|---|---|
| `addService` / `addProduct` | `catalogId?`, `name`, `value`, `quantity`, `description?`, `deviceId?`, `alternatives[]` | `addService` / `addProduct` |
| `updateItem` | `itemRef`, `value?`, `quantity?`, `description?` | edição do item |
| `removeItem` | `itemRef` | remoção do item (destrutiva) |
| `setStatus` | `status` ∈ `quote`, `approved`, `progress`, `done`, `canceled` | `setStatus` (cancelar é destrutiva) |
| `addPayment` | `amount`, `method?` | `addPayment` |
| `addDiscount` | `amount` | `addDiscountTransaction` |
| `markAsPaid` | — | `markAsFullyPaid` |
| `removePayment` | `transactionRef` | `removeTransaction` (destrutiva) |
| `setCustomer` | `customerId?` ou `newCustomer{name, phone?, taxId?}`, `alternatives[]` | `setCustomer` |
| `setDevice` / `addDevice` | `deviceId?` ou `newDevice{name, serial?, manufacturer?, customData?}`, `alternatives[]` | `setDevice` / `addDevice` |
| `setDueDate` | `date` | data de entrega |
| `addComment` | `text`, `public` | comentários |
| `attachPhotos` | `photoRefs[]` | já sobem antes; operação só confirma o vínculo |

Valores sempre em número; a tela formata com `FormatService`. "200 cada" vira `quantity` + `value` unitário; "garantia" vira valor 0 com descrição "Garantia".

### 4.2 Cota

- Novo campo em `SubscriptionLimits`: `aiRequestsPerMonth`, e em `SubscriptionUsage`: `aiRequestsThisMonth`, no mesmo padrão de `photosPerMonth` / `photosThisMonth` (`FeatureGateService`, `subscription-plans.ts`).
- Conta **cada chamada** à IA, aplicada ou não.
- Todos os planos têm IA, com as mesmas funções; muda só a quantidade: **Free 10, Starter 150, Pro 400, Business 1.000 por mês** (decidido em 2026-10-09). Ao atingir o limite, a barra "Falar" mostra o aviso de plano no mesmo estilo do limite de fotos e o fluxo manual continua livre.
- Custo estimado: ~US$ 0,008 por chamada com fotos e áudio no Gemini Flash (dobra em 2027). No pior caso, a IA consome 26% (Starter) a 42% (Business) do líquido do plano; medir no piloto.
- Prazo: a IA precisa estar no ar antes do fim da cortesia Pro (07/12/2026); se atrasar, a cortesia é estendida.

### 4.3 Receber fotos de outros apps

- **Android:** `intent-filter` para `SEND` e `SEND_MULTIPLE` com `image/*` no `AndroidManifest.xml`, lido por um pacote de share intent.
- **iOS:** Share Extension (target novo no Xcode, App Group para passar os arquivos, novo perfil no fastlane match). É `risk:high` pelo CLAUDE.md (assinatura iOS).
- Sugestão de OS: a Function `aiMatchOrder` lê placa/série nas fotos e busca o aparelho por `serial`; se achar OS em aberto desse aparelho, sugere. Sem leitura, a lista de OS em aberto aparece sozinha.

### 4.4 Privacidade

- Áudio e fotos vão para o Vertex AI (Google) só para processar o pedido; não são guardados além das fotos que o usuário anexou. Pelos termos do Vertex AI, os dados não treinam modelos.
- Atualizar a política de privacidade e os rótulos de privacidade das lojas (áudio). Adicionar `NSMicrophoneUsageDescription` e `RECORD_AUDIO` com texto claro ("para você falar o que fazer na OS").
- Logs da Function não registram transcrição nem conteúdo; só contagem, latência e tipo de operação.

## 5. Estrutura no app

A tela nova nasce em `lib/screens/order/` com um componente por zona/bloco, e o `OrderStore` continua sendo a fonte única de estado:

```
lib/screens/order/
  order_screen.dart              # monta as zonas; sem regra de negócio
  widgets/order_header.dart      # aparelho, cliente, foto
  widgets/next_step_card.dart    # frase + botão por status (tabela 3.1)
  widgets/order_items_section.dart
  widgets/order_extras_section.dart  # só o que existe
  widgets/order_summary.dart     # total / falta receber
  widgets/assistant_bar.dart     # foto + falar
  assistant/proposal_sheet.dart  # E2 / E4
  assistant/order_operation.dart # modelo das operações + aplicação no OrderStore
  capture/capture_screen.dart    # E3 / captura
  share/received_photos_screen.dart  # N3
lib/services/ai_assistant_service.dart  # chamada às Functions, upload, gravação
```

- O `order_form.dart` atual continua existindo até a tela nova ter **paridade** com tudo que está no menu "…". A troca é feita por uma opção "Nova tela da OS" (padrão desligado no piloto, ligado depois) e o arquivo antigo é removido quando a nova virar padrão.
- As cores e tamanhos vêm de `AppColors`, `AppTypography` e `AppSpacing`. A troca do azul do app (`activeBlue` em `lib/main.dart`) acontece na fase 1.

## 6. Fases

Cada fase é um plano próprio (`docs/superpowers/plans/`) e um ou mais PRs.

| Fase | Entrega | Risco |
|---|---|---|
| **1. Tela da OS nova, sem IA** | E1 completa com paridade do "…", próximo passo por status, opção "Nova tela da OS", troca do azul do app | `risk:low` (UI) |
| **2. IA na OS** | `aiOrderAssist`, serviço de catálogo compartilhado, operações, cartão de proposta (E2), cota `aiRequestsPerMonth` | `risk:high` (Function com escrita de uso e limites de assinatura) |
| **3. Nova OS por foto** | E3, captura, E4, leitura de placa/etiqueta por segmento | `risk:low` no app, Function já existente |
| **4. Fotos de outros apps** | Android primeiro; depois iOS Share Extension; `aiMatchOrder` | Android `risk:low`, iOS `risk:high` |

A fase 1 já entrega valor sozinha e serve de referência para o trabalho das demais telas.

## 7. Testes

- **Functions:** testes do schema das operações, da cota (incrementa, bloqueia no limite, ilimitado em −1), do serviço de catálogo e do prompt com o Gemini simulado.
- **Conjunto de avaliação da IA:** ~40 frases e fotos **inventadas**, baseadas nos padrões do discovery (sem dados reais), com as operações esperadas. Cobrir: "200 cada", "garantia", "11000", cliente por apelido, duas fotos do mesmo split, placa + vidro marcado, "pode finalizar", "recebi 166 no dinheiro". Roda manualmente antes de trocar modelo ou prompt; meta inicial de 90% das operações certas.
- **App:** testes de widget do próximo passo por status, da proposta (desmarcar, corrigir, aplicar só o marcado, destrutiva pede segundo toque) e da aplicação de cada operação no `OrderStore`; teste de que a captura gera uma única OS.

## 8. Decisões em aberto

1. Modelo final (Flash atual vs. o mais barato que passe no conjunto de avaliação).
2. Se o botão do próximo passo em `done` pago deve ser "Enviar para o cliente" ou "Entregue".
3. Quando a tela nova vira padrão para todos (sugestão: após duas semanas de piloto sem regressão).
