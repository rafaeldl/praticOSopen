# AI_ORDER_ASSIST.md

## Visão Geral

Assistente de IA na **Nova OS** (passo 14 do redesenho, fase 2/3 da spec): o usuário toca em **Foto** e/ou **Falar o que fazer**, a Function `aiOrderAssist` lê a foto e o texto e devolve um **rascunho** da OS (cliente, veículo/placa, serviços e peças casados com o catálogo da empresa). Também muda ou tira itens que já estão na OS ("a pintura é 300", "tira a lavação"), na Nova OS e numa OS salva. O app preenche **a mesma Nova OS em branco**, com marca-texto amarelo no que a IA pôs, e o botão continua **"Salvar OS"**. A Function nunca grava a OS.

Specs: `docs/superpowers/specs/2026-10-11-telas-os-ia-design.md` (vale sobre) e `2026-10-09-os-ai-assistant-design.md` (§4 arquitetura, §4.2 cota).

**Desligado por padrão.** Quem liga é o servidor, sem build novo do app nem deploy (ver [Ligar e desligar](#ligar-e-desligar)):

- **Para todas as empresas:** `config/ai.enabledForAll == true`.
- **Por empresa:** `companies/{companyId}/settings/ai.enabled` (`true` ou `false`), que vale sobre a chave geral.

O app pergunta ao servidor (`GET /v1/app/ai/status`) ao abrir a OS e só mostra "Falar o que fazer" (e só manda a foto para a IA) quando a resposta é `enabled: true`. Desligada, a Function responde `AI_DISABLED` sem contar cota nem chamar o modelo.

## Primeiro uso

`showAiIntroOnce` (`lib/screens/order/assistant/ai_intro.dart`) abre uma folha em Início, uma vez por aparelho, depois que a lista carrega, só com o assistente ligado e só para quem tem o "+" (técnico não). Se o usuário saiu de Início enquanto o servidor respondia, nada é gravado e a folha espera a próxima carga. "Experimentar agora" abre a Nova OS já ouvindo (`openNewOrder(startTalking: true)`). Com qualquer resposta, não volta a aparecer (`ai_intro_seen_v1` em `SharedPreferences`).

## Ligar e desligar

Pelo script `npm run ai` (em `firebase/functions`, credencial do `gcloud auth application-default login`). Sem `--yes` ele só mostra o que faria.

```bash
cd firebase/functions

# Ver como está (geral e uma empresa)
npm run ai -- show --project praticos --company <companyId>

# Uma empresa: ligar (com Claude e limite opcional), desligar, voltar a seguir a chave geral
npm run ai -- on     --project praticos --company <companyId> --provider claude --limit 100 --yes
npm run ai -- off    --project praticos --company <companyId> --yes
npm run ai -- follow --project praticos --company <companyId> --yes

# Todas as empresas: ligar com Claude como padrão, ou desligar
npm run ai -- on  --project praticos --all --provider claude --yes
npm run ai -- off --project praticos --all --yes
```

| Situação | `config/ai` | `companies/{id}/settings/ai` | Resultado |
|---|---|---|---|
| Ninguém ligado | vazio | vazio | desligada |
| Piloto | vazio | `enabled: true` | ligada só na empresa |
| Todos ligados | `enabledForAll: true` | vazio | ligada |
| Todos menos uma | `enabledForAll: true` | `enabled: false` | desligada nessa empresa |
| Claude para todos, uma no Gemini | `defaultProvider: 'claude'` | `provider: 'gemini'` | Gemini nessa empresa |

Quanto demora para valer:
- **Servidor:** mudança por empresa vale na hora. A `config/ai` é lida no máximo uma vez por minuto em cada instância da Function.
- **App:** guarda a resposta de cada empresa por 5 minutos (`kAiStatusCacheDuration`). Os botões aparecem ou somem na próxima OS aberta depois disso.
- **Erro:** se o servidor não responder (sem internet, servidor antigo, técnico sem `write:orders`), o app trata a IA como desligada.

## Arquitetura

### Function (firebase/functions)

| Arquivo | Papel |
|---|---|
| `src/routes/v1/ai.routes.ts` | `GET /v1/app/ai/status` (ligada? + uso do mês, sem contar), `POST /v1/app/ai/order-assist` e `POST /v1/app/ai/form-photo` no `api` (bearer + `resolveCompanyContext` + limite por IP e por usuário); todos exigem `write:orders` |
| `src/services/ai/form-photo.service.ts` | Foto do checklist: validação (zod), cota e `runFormPhoto` com dependências injetáveis; prompt e parser em `form-photo.prompt.ts` |
| `src/services/ai/form-photo.deps.ts` | Dependências de produção da foto do checklist, com modelo e região próprios (`AI_FORM_PHOTO_*`) |
| `src/services/ai/order-assist.service.ts` | Validação (zod), prompt, parse da resposta, casamento com catálogo, orquestração (`runOrderAssist`) com dependências injetáveis |
| `src/services/ai/order-assist.deps.ts` | Dependências de produção (Firestore da empresa, cota, Vertex AI); carrega até 2.000 clientes e veículos (só nome, telefone, placa, marca) para comparar na memória |
| `src/services/ai/fuzzy-match.ts` | Busca por semelhança sem IA: `matchCustomer` e `matchDevice` (ver [Cliente e veículo pela voz](#cliente-e-veículo-pela-voz)) |
| `src/services/ai/ai-quota.service.ts` | Chave geral (`config/ai`) + chave da empresa (`settings/ai`) → `resolveAiSettings`; cota mensal (`aiUsage/{YYYY-MM}`) e `getAiUsage` |
| `scripts/ai-settings.ts` | `npm run ai`: liga/desliga por empresa ou para todas |
| `src/services/ai/llm.client.ts` | Interface neutra (`LlmClient`, `LlmRequest` com JSON Schema) e `LlmRouter`, que escolhe o provedor por pedido |
| `src/services/ai/gemini.client.ts` | `VertexGeminiClient` (Gemini no Vertex AI, credencial da conta de serviço; sem chave) e `toGeminiSchema` |
| `src/services/ai/claude.client.ts` | `ClaudeClient` (Claude na API da Anthropic, `@anthropic-ai/sdk`, structured outputs; fallback do servidor só em Sonnet/Opus) |

### App

| Arquivo | Papel |
|---|---|
| `lib/services/ai_order_assist_service.dart` | `AiOrderAssistClient`/`AiOrderAssistService` (HTTP): `isEnabled()` (status com cache de 5 min por empresa) e `assist()`; modelo `AiOrderDraft`, erros `AiAssistError` |
| `lib/screens/order/assistant/assistant_input_sheet.dart` | Sheet "Falar o que fazer": campo de texto (o microfone do teclado faz o ditado) + fotos; "Pronto" manda tudo junto |
| `lib/screens/order/order_screen_v2.dart` | Botões Foto (vidro) e Falar (grafite) na Nova OS; aplica o rascunho e marca o que a IA preencheu; "Qual Juliene?" para cliente e veículo |
| `lib/services/assistant_registration.dart` | `AssistantRegistration`: monta o cliente/veículo novo com id e grava só no ✓ |
| `lib/screens/widgets/app_list_row.dart` | `marked: true` = marca-texto (`AppColors.marker` / `onMarker`) |

### Firestore

```
config/ai                                { enabledForAll?: bool, defaultProvider?: 'gemini'|'claude' }  # só Admin SDK
companies/{companyId}/settings/ai        { enabled?: bool, monthlyLimit?: int, provider?: 'gemini'|'claude' }  # só Admin SDK; cada campo vale sobre o geral
companies/{companyId}/aiUsage/{YYYY-MM}  { count, limit, updatedAt }             # só Admin SDK
```

Nenhuma regra nova: os três caminhos não têm `match` em `firestore.rules`, então o app não lê nem escreve (negado por padrão). Sem índice novo.

## Fluxo de Dados

```
Nova OS em branco (ou já com fotos compartilhadas de outro app, ver docs/RECEIVE_SHARE.md)
  Foto → câmera (só aqui) → sheet com a foto ─┐
  Falar → sheet (texto/ditado) ───────────────┤ "Pronto"
                                              ▼
POST /v1/app/ai/order-assist {text?, photos?[base64 JPEG ≤2 MB, até 4], audio?, locale, order?{services[], products[]},
                              history?[até 3 falas], context?{customer, devices, request, due, pending}}
  1. ligada? (settings/ai.enabled, senão config/ai.enabledForAll) senão 403 AI_DISABLED
  2. cota: transação em aiUsage/{mês}; no limite → 429 AI_QUOTA_EXCEEDED {used, limit}
  3. catálogo da empresa (até 300 serviços e 300 produtos, nome + preço)
  4. Modelo (Gemini ou Claude, ver "Provedores"; resposta presa ao JSON Schema) — falhou → devolve a cota, 503 AI_UNAVAILABLE
  5. operações add → casa com o catálogo (items); update/remove → confere a linha (changes);
     cliente e veículo por semelhança (fuzzy-match: telefone, placa, nome, marca)
  ◀── rascunho {transcript, customer, customerGuess(+Phone), customerOptions[], device, deviceGuess*, deviceOptions[],
                items[], changes[], notes, dueDate, usage}
App: aplica changes (pergunta qual linha se houver duas iguais), soma items, ✦ azul no que veio da IA,
     aviso "Preenchi… · Desfazer" → ✓ no topo
```

## Mudar e tirar itens

O app manda as linhas que estão na tela (`order.services` e `order.products`: nome, valor e, nas peças, quantidade; até 50 de cada). O prompt numera essas linhas (`S1`, `S2`… serviços; `P1`… peças) e o modelo devolve **operações**:

| `action` | Quando | Campos |
|---|---|---|
| `add` | Item novo ("põe um alinhamento") | `kind`, `name`, `description`, `value`, `quantity` |
| `update` | Mudar valor, quantidade ou descrição de uma linha ("a pintura é 300", "são 3 litros", "a pintura é no capô") | `line` + `value`/`quantity`/`description` |
| `remove` | Tirar uma linha ("tira a lavação") | `line` |

**Descrição:** a parte ou o detalhe do item vai em `description`, e o nome fica o do catálogo ("pintura do para-choque" → `Pintura` / `Para-choque`; "farol esquerdo" → `Farol` / `Esquerdo`). A descrição também ajuda a achar a linha ("a pintura do capô é 400" com duas Pintura). No app, entra no campo "Descrição" do item, aparece embaixo do nome e sai no PDF.

Quando duas linhas servem ("a pintura" com duas Pintura na OS), o modelo deixa `line: null` e lista as duas em `candidates`.

O servidor separa a resposta: `add` vira `items` (casado com o catálogo, como antes) e `update`/`remove` viram `changes`, com a linha como `{kind, index}`. Muda descartada: linha que não existe na OS enviada, `update` sem valor nem quantidade, ambígua com menos de duas linhas válidas. Quantidade só vale em peça, arredondada e no mínimo 1. App antigo (sem `order`) recebe só `items`, como antes.

No app (`_applyDraft` em `order_screen_v2.dart`):

- **Mudar:** altera o valor/quantidade da linha (só na OS, nunca no catálogo) e marca com ✦.
- **Tirar:** tira na hora. É pedido do usuário, não ideia da IA, e o "Desfazer" põe de volta no mesmo lugar.
- **Duas linhas iguais:** abre a tela de escolher (`pickOne`) com a pergunta "Qual Pintura?" e o valor de cada uma. Voltar sem escolher ignora essa mudança.
- O app guarda as linhas que mandou; se a lista mudar enquanto a IA responde, a mudança vai para a linha certa ou é ignorada.

### Teste de descrição (2026-10-22)

6 frases de funilaria/pintura (parte do carro no item, dois itens com parte, sem parte, duas Pintura em partes diferentes, mudar a parte, mudar o valor pela parte), 2 rodadas. Claude 12/12; Gemini 11/12 (numa rodada não mudou a descrição, sem aplicar nada errado).

### Teste de intenção (2026-10-15)

30 frases sobre uma OS de oficina (adicionar, mudar valor, mudar quantidade, tirar, comando composto, item repetido, OS vazia), 3 rodadas por caminho. Scripts fora do repositório (scratchpad).

| Caminho | Acertos | Tempo (mediana) |
|---|---|---|
| A · Claude Sonnet + catálogo no prompt | 29/30 nas 3 rodadas | ~1,6 s |
| A · Gemini Flash + catálogo no prompt | 29/30 a 30/30 | ~1,5 s |
| C · Claude sem catálogo + Jev escolhendo do catálogo | 29/30 nas 3 rodadas | ~1,7 s (p90 até 6 s) |

O erro comum ("tira o óleo e o filtro", com o serviço "Troca de óleo" e a peça "Óleo" na OS) é o modelo perguntar qual das duas linhas: aceitável, o app pergunta. O caminho C errou uma vez a peça "Pastilha de freio dianteira" e somou uma chamada.

**Jev para escolher do catálogo: por enquanto não.** O catálogo no prompt é pequeno: metade das empresas tem 2 serviços e 2 peças, 90% até 17, e só 3 empresas passam de 150 (o limite do prompt). O caminho A acerta o mesmo, é mais rápido e simples. Rever quando houver empresas com catálogo grande ou erros de casamento medidos: o Jev entra no passo 5, só para o nome que não casou.

## Corrigir o que a IA pôs e lembrar o que foi dito

Issue #631. A IA pode trocar o que **ela mesma** pôs, e a fala nova vai junto com as últimas falas da OS. Assim funcionam "não, a placa é…", "o prazo é segunda", "não, era 350" e "o mesmo valor".

**Quem preencheu cada campo.** Cliente, veículo, relato e prazo têm ✦ quando vieram da IA. Enquanto a pessoa não mexe, a fala nova pode trocar esse valor. Quando a pessoa mexe à mão (escolhe outro cliente, troca o veículo, digita o relato, escolhe a data), o ✦ sai e a IA não toca mais naquele campo. As linhas de serviço e peça já mudavam (ver [Mudar e tirar itens](#mudar-e-tirar-itens)).

| Onde | Como sabe que é da IA |
|---|---|
| App (`order_screen_v2.dart`) | `_marked` (`'customer'`, `'request'`, `'due'`) e `_markedDevices`; mexer à mão tira a marca |
| Web, Nova OS (`NewOrderAssist.vue`) | `form.marked`; digitar no relato ou no prazo tira a marca (`NewOrderDrawer.vue`) |
| Web, OS salva (`OrderAssistant.vue`) | `put`: o que a IA gravou; vale enquanto o valor na OS continua igual |

**Histórico curto.** As 3 últimas falas desta OS (até 500 caracteres cada) ficam **só na memória da tela**: fechou a tela, sumiu. Nada vai para o banco. "Desfazer" tira a fala desfeita do histórico. Fala por áudio entra pela transcrição.

**O que vai para o servidor** (os dois campos são opcionais, e o app antigo continua igual):

```json
{
  "history": ["Gol placa ABC1234, troca de óleo"],
  "context": {
    "customer": { "chosen": true, "fromAi": true },
    "devices": [{ "name": "Gol", "serial": "ABC1234", "fromAi": true }],
    "request": { "text": "Barulho na suspensão", "fromAi": true },
    "due": { "date": "2026-11-13T18:00", "fromAi": false },
    "pending": ["customer"]
  }
}
```

- O cliente vai só como escolhido ou não, **nunca o nome**. Veículos vão com nome e placa.
- `pending`: a tela está perguntando ("Qual Juliene?", "Qual Pintura?"). Um nome, placa ou preço na fala nova responde.

**No servidor** (`order-assist.service.ts`):

- Com `history` ou `context`, o prompt ganha o bloco "Current order" (quem preencheu cada campo) e as regras de `MEMORY_PROMPT`: responder só à fala nova; o histórico já foi aplicado e **nunca é aplicado de novo**, serve só para entender a fala; só campo "(from assistant)" pode ser corrigido.
- O veículo corrigido volta com `replaces` (`V1`, `V2`…). O servidor converte em índice (`device.replaces`) só quando aquele veículo veio da IA. App e web trocam aquele veículo em vez de somar outro.
- `guardUserFields`: cliente, relato e prazo que a pessoa preencheu são tirados da resposta. A regra vale para qualquer cliente do servidor, mesmo que a tela já não aplicasse.
- Com memória, `device` é obrigatório no formato da resposta (`null` quando nenhum veículo foi dito). Opcional, o Claude deixava de fora o veículo corrigido, o mesmo problema que já aconteceu com `payment`.
- O prompt lista os 7 dias depois de hoje (`nextDays`), porque o Gemini errava o dia da semana ("quarta" virava quinta).
- Log: só a quantidade de falas no histórico e se veio contexto (`history=2 context=true`), nunca texto.

Custo: de 50 a 400 tokens de entrada a mais por fala. A cota não muda: 1 por fala.

**"Desfazer"** volta ao valor de antes: o veículo, o cliente, o relato ou o prazo que a IA tinha posto, com o ✦.

**Fora daqui:** a IA trocar o que a pessoa preencheu. Precisa de spec e muda as regras 1 e 16.

### Teste de frases em sequência (2026-11-06)

`firebase/functions/scripts/ai-memory-eval.ts` usa o prompt, o parser e o `runOrderAssist` reais com os modelos reais. A OS é simulada com as regras das telas. São 17 cenários de 1 a 4 falas: corrigir placa, modelo, prazo, valor, quantidade, cliente e relato; "o mesmo valor"; falas seguidas sem repetir item; segundo veículo; e cliente, veículo, relato e prazo escolhidos pela pessoa. As frases não têm dados de clientes.

| Conjunto | Claude Sonnet 5.5 | Gemini 2.5 Flash |
|---|---|---|
| Ajuste (17 cenários × 3 rodadas, 102 falas) | 102/102 | 102/102 |
| Inéditos (7 cenários × 2 rodadas, 30 falas, prompt travado) | 30/30 | 30/30 |
| Itens duplicados | 0 | 0 |
| Correções aplicadas | 43/43 | 43/43 |
| Algo da pessoa trocado | 0 | 0 |

Antes dos ajustes, o Claude deixava de fora o veículo corrigido em 4 de 6 casos e o Gemini errava o dia da semana. Os ajustes foram `device` obrigatório e a lista dos próximos dias.

```bash
cd firebase/functions
GCLOUD_PROJECT=praticos ANTHROPIC_API_KEY=... npx ts-node scripts/ai-memory-eval.ts --runs 3
GCLOUD_PROJECT=praticos ANTHROPIC_API_KEY=... npx ts-node scripts/ai-memory-eval.ts --runs 2 --only h-   # inéditos
```

Rodar de novo ao mudar o prompt, o formato da resposta ou o modelo.

## Cliente e veículo pela voz

"OS da Juliana, 48 2222-2222, Corsa placa MMM0099": o servidor procura cada um **sem IA**, comparando na memória. A IA só tira o nome, o telefone, a placa e a marca da fala; os cadastros nunca vão para ela.

**Por que não a busca do Firestore:** ela só acha palavra exata (`keywords`), então "Juliene" não acha "Juliana" e "GM Corsa" não acha um Corsa com marca "Chevrolet". Os cadastros são pequenos (2026-10-15: a maior empresa tem menos de 2.000 clientes), então o servidor lê nome/telefone/placa/marca de até 2.000 e compara tudo. Acima disso, as buscas exatas por telefone, placa e palavra continuam valendo.

**Como compara** (`fuzzy-match.ts`):

| O que | Como | Exemplo |
|---|---|---|
| Telefone | Só os dígitos; os 8 últimos batem (ignora DDI, DDD e o 9 da frente) | "+55 48 2222-2222" = "(48) 2222-2222" |
| Placa | Sem traço e espaço; Mercosul ↔ antiga (`ABC1C34` = `ABC1234`) | "abc 1234" = "ABC-1234" |
| Nome | Jaro-Winkler por palavra + som parecido em português (Luis/Luiz, Thiago/Tiago, Rafael/Raphael, Sousa/Souza, Wagner/Vagner) | "Juliene" ~ "Juliana" (perto, pergunta) |
| Marca | Apelidos: GM/Chevrolet, VW/Volkswagen, Mercedes/MB… | "GM Corsa" = Corsa · Chevrolet |

**Decisão:**
- **Certeza** (telefone ou placa iguais, nome igual, ou um único nome com nota ≥ 0,97) → entra na OS com ✦.
- **Perto** (nota ≥ 0,80, até 4) → a linha "Ouvi “Juliene”" abre **"Qual Juliene?"** com os parecidos, "Cadastrar Juliene como cliente novo" e "Outro cliente". Para veículo é igual, com ou sem placa ("Super Classic" perto de "Classic 1.0" pergunta "Qual Super Classic?").
- **Nada perto** → na Nova OS, entra como **"Juliana · (48) 2222-2222 · novo"** e é cadastrado no ✓. Veículo também: pela placa que não existe, ou pelo modelo quando nenhum cadastrado é parecido ("Super Classic · novo").

**Testes:** `src/services/ai/__tests__/fuzzy-match.test.ts` (nomes, sons, marcas, placas, telefones).

## Receber, desconto e status pela voz

Fase 1 (spec `docs/superpowers/specs/2026-11-02-ia-financeiro-os-design.md`). "Pagou tudo no Pix", "deu 500 de entrada", "dá 10% de desconto" e "terminei" viram um cartão "Confere?". Nada de dinheiro ou status é gravado antes do toque em Confirmar.

**Chave própria, desligada por padrão.** `financeActions` em `companies/{id}/settings/ai` ou em `config/ai`, com a mesma lógica de `enabled` (o valor da empresa vence). Desligada, o modelo não recebe as regras nem o campo `actions`, e a resposta vem com `actions: null`.

```bash
npm run ai -- on --project praticos --company <id> --finance on --yes   # liga para uma empresa
npm run ai -- on --project praticos --company <id> --finance off --yes  # desliga só isso
npm run ai -- on --project praticos --all --finance on --yes            # liga para todas
```

**O modelo não faz conta.** Ele não recebe total, pago nem saldo. Devolve só o que foi dito, e o app calcula com o saldo atual da OS, já com os itens mudados na mesma frase.

| `kind` | Frase | Conta no app |
|---|---|---|
| `full` | "pagou tudo" | saldo (recalculado ao gravar) |
| `value` | "deu 500" | 500 |
| `percent` | "pagou metade" | saldo × 50% |
| `leaving` | "ficou devendo 200" | saldo − 200 |
| sem `value` | "pagou uma parte" | a linha pede o valor |

**App:**

- `lib/screens/order/assistant/ai_actions_plan.dart`: `planAiActions` monta o cartão. É uma função pura, com regras e permissões.
- `ai_actions_sheet.dart`: a folha. As linhas de dinheiro abrem `ReceivePaymentSheet` e `showReceiveDiscountSheet`.
- `ai_actions_runner.dart`: executa na ordem desconto, aprovar, pagamento e status. Para na primeira falha. `undoAiActions` desfaz do último para o primeiro.
- `lib/screens/payments/order_payment_actions.dart`: gravar pagamento e mensagens de erro, compartilhados com a tela de pagamentos.

**Regras:**

- Foto sozinha nunca gera ação: o servidor nem pede `actions` ao modelo.
- Orçamento não aceita pagamento: o cartão mostra "Marcar como aprovada" junto de "Receber". Quem recebe mas não aprova vê o motivo, e nada é gravado.
- O status só anda para a frente. Cancelar e voltar para orçamento ficam fora.
- Valor acima do saldo vira o saldo, com o aviso "Falta só R$ X." Nunca grava a mais.
- Nota automática: o cartão avisa com `paid` quando um **pagamento** zera o saldo, e com `completed` quando a OS vira `done`. Desconto que quita não emite nota (`closedByDiscount` no gatilho), então não avisa. "Desfazer" não cancela a nota e diz isso.
- **Nova OS:** as ações ficam guardadas e a folha abre depois do ✓, com a OS já criada. Elas não podem entrar junto na criação: o gatilho da nota só olha atualizações, e técnico não cria OS com dinheiro. A tela espera o id por `kAiActionsSaveWait` (6 s). Sem id (offline), fecha como sempre, não grava dinheiro e o aviso pede para registrar depois.
- "Desfazer" depois do cartão desfaz as ações e também o que a mesma frase pôs na OS.
- Status recusado pelo servidor: a tela volta ao status anterior, os passos seguintes não rodam e aparece o erro. Sem resposta em `kStatusSaveWait` (offline), conta como mudado. Concluir pelo cartão também oferece a próxima manutenção.

**Eventos** (sem valores): `ai_action_proposed {types}`, `ai_action_confirmed {edited}`, `ai_action_dismissed`, `ai_action_undone`, `ai_action_failed {step}`.

**Só texto, sempre no Claude.** Com a chave ligada, o servidor manda o pedido com texto para o Claude, qualquer que seja o provedor da empresa. Áudio não recebe as regras: o Claude não ouve, e o app já manda texto. O motivo está no teste abaixo.

**Teste com os modelos reais** (`firebase/functions/scripts/ai-finance-eval.ts`, 2026-11-02, duas passadas por frase, prompt e parser reais):

Primeiro prompt:

| Conjunto | Claude Sonnet 5.5 | Claude Haiku 5.5 | Gemini 2.5 Flash |
|---|---|---|---|
| Ajuste (98 frases, 15 do bot) | 194/196 | 191/196 | 192/196 |
| Frases novas (40) | 80/80 | 76/80 | 75/80 |
| Promessa ou preço virando pagamento | 0 | 3 (só no ajuste) | 8 (3 no ajuste, 5 nas novas) |

Prompt ajustado para os erros do Haiku (promessa com momento futuro, "dia 28", "restou", "fechou"). As 40 frases de antes já tinham sido vistas, então a prova foi em `scripts/ai-finance-eval-final.json`, com 42 frases inéditas e o prompt travado:

| Conjunto | Claude Sonnet 5.5 | Claude Haiku 5.5 |
|---|---|---|
| Ajuste (98 frases, 15 do bot) | 196/196 | 195/196 |
| Frases já vistas (40 + 83 públicas do ajuste) | 246/246 | 246/246 |
| Inéditas (42) | 79/84 (94,0%) | 82/84 (97,6%) |
| Promessa ou preço virando pagamento nas inéditas | 1 | 0 |

Metas da spec: 0 promessa ou preço virando pagamento, 95% de acerto. Nas inéditas, só o Haiku bate. A falha do Sonnet foi uma passada de "quedó en deber 90 para el mes que viene", frase ambígua: pode ser dívida que ficou, sem pagamento antes. Os outros erros são seguros: nada foi proposto ou a pessoa digita o valor. A diferença entre os dois é de poucas chamadas, e preço e tempo de resposta não foram comparados. Desde 2026-11-11 o padrão do servidor é o Haiku (ver [Provedores](#provedores)). As frases do bot ficam fora do repositório, porque vêm de conversas reais.

```bash
cd firebase/functions
GCLOUD_PROJECT=praticos ANTHROPIC_API_KEY=... npx ts-node scripts/ai-finance-eval.ts --providers claude --runs 2
```

Com ações opcionais no formato de resposta, o Claude pulava `payment` em "terminei, pagou 300" ("aprovado", "quitou" e parecidos). Por isso `payment`, `discount` e `status` são obrigatórios e vêm `null` quando não foram ditos. Rodar o teste de novo ao mudar prompt, formato ou modelo.

Nenhuma empresa tem a chave ligada.

## Foto do checklist

Spec: `docs/superpowers/specs/2026-11-10-checklist-ia-foto-design.md`. A pessoa tira a foto de uma pergunta do checklist e a IA, sabendo a pergunta, responde (km, combustível, número de série) e escreve uma observação editável ("Amassado na porta traseira esquerda"). O app chama a rota (#688); a Function não grava nada.

### Rota `POST /v1/app/ai/form-photo`

Mesmo bearer, `write:orders`, chave de ligar (`settings/ai.enabled` ou `config/ai.enabledForAll`) e cota da OS.

```jsonc
// Pedido
{
  "photo": { "mimeType": "image/jpeg", "data": "<base64, até 2 MB>" },
  "question": { "label": "Nível de combustível", "type": "select", "options": ["Reserva", "1/4", "1/2", "3/4", "Cheio"] },
  "device": { "category": "Veículo", "name": "Fiat Uno 2015" },   // opcional, sem placa nem série
  "segment": "automotive", "locale": "pt",                        // opcionais
  "lastReading": { "value": 102000, "unit": "km" }                // opcional, só em pergunta de leitura
}
// Resposta 200
{ "success": true, "data": {
  "answer": "1/2",                       // só quando confident e, com opções, uma delas (a original)
  "note": "Ponteiro no meio",            // observação da pergunta
  "optionNotes": [{ "option": "Porta", "text": "Amassado na porta traseira esquerda" }],
  "photoNote": "Luz de óleo acesa",      // o que a foto mostra e a pergunta não pediu
  "photoIssue": "dark",                  // dark | blurry | off_target
  "confident": true,
  "usage": { "used": 12, "limit": 150 }
} }
```

Campos sem valor não vêm. Erros iguais aos da OS: 400 `VALIDATION_ERROR`, 403 `INSUFFICIENT_PERMISSIONS` ou `AI_DISABLED`, 429 `AI_QUOTA_EXCEEDED` (com `used` e `limit`), 503 `AI_UNAVAILABLE`.

- **Resposta fora das opções é descartada** no servidor; maiúscula e espaço não contam ("cheio" vira "Cheio"). `confident: false` nunca devolve `answer`, só a observação.
- **Cota:** cada foto lida conta 1, inclusive foto escura ou tremida, porque o modelo foi chamado. Só é devolvida quando o modelo não respondeu (erro, fora do ar ou resposta que não é JSON).
- **Privacidade:** o corpo é `strict`: não há campo para cliente, telefone, placa, série nem `companyId`. O equipamento vai só como categoria e modelo. O log só tem empresa, tipo da pergunta, código de erro e tempo (`[aiFormPhoto] company=… type=number ms=…`), nunca a imagem ou texto.
- **Pergunta `select` ou `checklist` sem opções** dá 400. `photo_only` é aceita e devolve só observações.

### Modelo da foto do checklist

Decidido pelo Rafael em 2026-11-11 (#701): **Gemini 3.8 Flash na região `global`, com `thinkingLevel: low`**. No teste abaixo ele leu 78 de 80 fotos sem nenhuma resposta errada dada com certeza; o Gemini 2.5 de São Paulo, padrão da OS, deu 6. O padrão fica no código (`form-photo.deps.ts`), como o da OS; a OS continua com o dela.

| Variável | Valores | Padrão |
|---|---|---|
| `AI_FORM_PHOTO_PROVIDER` | `gemini`, `claude` ou `company` (segue o `provider` da empresa, como a OS) | `gemini` |
| `AI_FORM_PHOTO_GEMINI_MODEL` | ex.: `gemini-2.5-flash` | `gemini-3.8-flash` |
| `AI_FORM_PHOTO_VERTEX_LOCATION` | ex.: `southamerica-east1` | `global` |
| `AI_FORM_PHOTO_GEMINI_THINKING` | `minimal`, `low`, `medium`, `high` ou `off` (não manda o nível; o cliente do Gemini decide, e no 2.5, que recusa o campo, não manda nada) | `low` |

**Privacidade:** o Gemini 3.8 não existe em São Paulo. Em `global`, o Google escolhe a região que processa a foto, que pode ser fora do Brasil ("Endpoints don't guarantee data residency", na [página de regiões](https://cloud.google.com/vertex-ai/generative-ai/docs/learn/locations)). Segundo a [página de retenção](https://cloud.google.com/vertex-ai/generative-ai/docs/vertex-ai-zero-data-retention), o Google não usa os dados para treinar modelos sem permissão, guarda em cache por no máximo 24 horas e pode registrar pedidos para detectar abuso. A política de privacidade (seção "Assistente de IA", em `firebase/hosting/src/_data/legal.json`) diz isso desde 2026-11-11. Para voltar a São Paulo: `AI_FORM_PHOTO_GEMINI_MODEL=gemini-2.5-flash`, `AI_FORM_PHOTO_VERTEX_LOCATION=southamerica-east1`, `AI_FORM_PHOTO_GEMINI_THINKING=off` e tirar a frase da política.

### Teste antes da rota

O prompt, o formato de resposta e o parser da §7 ficam em `src/services/ai/form-photo.prompt.ts`. O parser descarta resposta fora das opções e qualquer resposta com `confident: false`, mas mantém a observação. `scripts/checklist-photo-eval.ts` manda cada foto com a pergunta e mede o acerto por tipo (km, combustível, número de série, dano, tela, visor), se a observação diz o lugar certo e quanto tempo leva. As fotos e as respostas certas ficam fora do repositório.

```bash
cd firebase/functions
ANTHROPIC_API_KEY=... GCLOUD_PROJECT=praticos npm run ai:photo-eval -- --dir <pasta com cases.json> \
  --gemini-model gemini-3.8-flash --gemini-location global --gemini-thinking low --runs 2
```

Primeira medição (2026-11-11, 40 perguntas em 36 fotos públicas do Wikimedia Commons, duas passadas). "Errada" é resposta dada com certeza e que estava errada; "sem resposta" é quando o modelo disse que não tinha certeza:

| Modelo | Certas | Erradas | Sem resposta | Km certo | Observação com o lugar certo | Tempo (mediana) |
|---|---|---|---|---|---|---|
| Gemini 3.8 Flash (`global`, `thinkingLevel: low`) | 78/80 | 0 | 2 | 26/26 | 18/18 | 3,7 s |
| Gemini 2.5 Flash (São Paulo) | 74/80 | 6 | 0 | 24/26 | 14/18 | 2,3 s |
| Claude Sonnet 5.5 (`effort: low`) | 61/80 | 2 | 17 | 16/26 | 16/18 | 2,8 s |
| Claude Haiku 5.5 (`effort: low`) | 62/80 | 0 | 18 | 20/26 | 15/18 | 2,0 s |

O Gemini 2.5 leu um hodômetro com certeza e errou um dígito, e nas observações trocou esquerda e direita. Os dois Claude quase não erram, mas deixam sem resposta muito km e combustível que estão legíveis. O Gemini 3 pensa demais por padrão: o `VertexGeminiClient` aceita `thinkingLevel`, que só é enviado quando alguém o informa. Fotos públicas não são fotos de balcão, então a decisão da Fase 1 depende de repetir o teste com fotos reais.

Segunda rodada, só o Sonnet 5.5 (2026-11-11, mesmo conjunto, sem `fallbacks`). Nos casos sem resposta da primeira rodada ele lia o número certo na observação, mas marcava `confident: false`. A foto não era o problema: o Sonnet 5.5 recebe a foto de 1920 px inteira (~4.300 tokens de entrada) e reduzir para 1568 px só aumentou os sem resposta. O prompt `read` (`--prompt read`) diz que ler todos os dígitos conta como certeza, mesmo com a foto um pouco tremida, de lado ou com reflexo. O custo usa US$ 2 por milhão de tokens de entrada e US$ 10 por milhão de saída:

| Sonnet 5.5 | Certas | Erradas | Sem resposta | Km certo | Tempo (mediana) | 1.000 fotos |
|---|---|---|---|---|---|---|
| `low`, prompt `strict` | 60/80 | 2 | 18 | 15/26 | 2,6 s | US$ 9,97 |
| `medium`, `strict` | 58/80 | 0 | 22 | 15/26 | 2,6 s | US$ 10,03 |
| `high`, `strict` | 76/80 | 1 | 3 | 25/26 | 2,9 s | US$ 10,94 |
| `low`, `read` | 70/80 | 2 | 8 | 22/26 | 2,7 s | US$ 10,00 |
| `medium`, `read` | 68/80 | 3 | 9 | 23/26 | 2,7 s | US$ 10,06 |
| `high`, `read` | 75/80 | 1 | 4 | 26/26 | 2,8 s | US$ 10,66 |
| `low`, `read`, foto em 1568 px | 68/80 | 0 | 12 | 22/26 | 2,6 s | US$ 7,96 |

O que mais muda é o `effort: high`, que custa pouco a mais e não deixa mais lento. O Gemini 3.8 Flash da primeira rodada usa ~1.740 tokens de entrada e ~170 de saída por foto: US$ 1,94 por 1.000 fotos no preço de lançamento (US$ 0,75/3,75 até 31/12/2026) e US$ 3,89 depois.

## Provedores

A Function não depende de um provedor. `order-assist.service.ts` monta um `LlmRequest` (prompt, texto, fotos/áudio e o JSON Schema da resposta) e o `LlmRouter` entrega para o cliente certo:

1. `settings/ai.provider` da empresa (`gemini` ou `claude`);
2. senão `config/ai.defaultProvider` (padrão de todas as empresas);
3. senão `AI_PROVIDER` no ambiente da Function;
4. senão `gemini`.

Se o provedor escolhido não lê alguma parte do pedido (o Claude não recebe áudio), o pedido vai para um que lê: primeiro o padrão do ambiente (`AI_PROVIDER`), depois qualquer outro configurado. Com o Claude para todos, o áudio do app web vai para o Gemini. Para somar outro provedor: criar um `LlmProviderClient` (`generateJson` + `supportsMedia`), registrar no `LlmRouter` em `order-assist.deps.ts` e incluir o nome em `LLM_PROVIDERS`.

| Provedor | Modelo padrão | Variáveis | Credencial | Onde roda |
|---|---|---|---|---|
| `gemini` | `gemini-3.8-flash` | `AI_GEMINI_MODEL`, `AI_VERTEX_LOCATION` (padrão `global`), `AI_GEMINI_THINKING` (padrão `low` no Gemini 3) | Conta de serviço (sem chave) | Vertex AI, `global` (pode sair do Brasil) |
| `claude` | `claude-haiku-5-5` | `AI_CLAUDE_MODEL`, `AI_CLAUDE_EFFORT` (padrão `low`) | Secret `ANTHROPIC_API_KEY` | API da Anthropic (EUA) |

O Claude usa structured outputs (`output_config.format`) com o mesmo schema, pensamento adaptativo (o campo `thinking` não vai) e nenhum `temperature` (o Haiku 5.5 recusa). Com Sonnet 5.5, Opus ou Fable em `AI_CLAUDE_MODEL`, vai também `fallbacks: "default"` (beta `server-side-fallback-2026-07-01`): se o modelo recusar, o servidor da Anthropic tenta outro modelo na mesma chamada. O Haiku não tem esse recurso, então não vai. Recusa final, resposta cortada ou erro da API viram `AI_UNAVAILABLE` e a cota é devolvida.

### Haiku como padrão (2026-11-11)

O texto e as fotos da OS passam ao Claude Haiku 5.5, e o áudio (só o app web manda) ao Gemini 3.8 Flash em `global`, com `thinkingLevel: low`. O Gemini 2.5 Flash, que respondia até aqui, passou da data de retirada do Google.

Medição com os modelos reais, prompt e parser da OS. Frases: `ai-memory-eval.ts` (24 cenários × 2) e `ai-finance-eval.ts` (cases + 15 frases do bot × 2; inéditas `ai-finance-eval-final.json` × 2). Fotos: 11 fotos públicas do Wikimedia Commons (as mesmas do teste do checklist: carros batidos, retrovisor, celulares trincados, impressora, plaqueta de motor), só a foto, sem fala, 2 passadas. Custo em US$ por chamada, com o preço de lista de 2026-11 (Haiku US$ 0,10/0,50 por milhão de tokens; Gemini 2.5 Flash 0,30/2,50; Gemini 3.8 Flash 0,75/3,75 até 31/12/2026, o dobro depois):

| | Haiku 5.5 | Gemini 2.5 Flash (SP, hoje) | Gemini 3.8 Flash (`global`, `low`) |
|---|---|---|---|
| Frases em sequência | 98/98 | 98/98 | 94/96 (2 sem resposta) |
| Dinheiro (ajuste + bot) | 195/196 (1 resposta cortada) | não medido | não medido |
| Dinheiro, inéditas | 130/130, nada virou pagamento | — | — |
| Fotos sem erro, prompt antigo | 13/22 | 16/22 | 21/22 (1 sem resposta) |
| Fotos sem erro, prompt com a regra do nome | 17/22 (+2 sem serviço sugerido) | — | 19/22 |
| Dado inventado nas fotos, prompt antigo | 5 nomes descritivos ("Veículo com dano na lateral traseira"), 1 marca errada | 1 placa inventada, 1 nome "Meeting02" | 0 |
| Dado inventado nas fotos, prompt novo | 3 nomes descritivos | — | 1 modelo errado, 1 nome descritivo |
| Lado errado nas fotos (prompt antigo) | 4 | 1 | 0 |
| Tempo, texto (mediana / p90) | 1,2 s / 2,0 s | 1,3 s / 2,0 s | 2,3 s / 3,1 s |
| Tempo, foto (mediana / p90 / pior) | 2,2 s / 4,4 s / 6,5 s | 3,1 s / 6,7 s | 4,7 s / 12,4 s / 44 s |
| Custo, texto | US$ 0,0003 | US$ 0,0010 | US$ 0,0018 |
| Custo, foto | US$ 0,0006 | US$ 0,0021 | US$ 0,0039 |

O Haiku escreve observações mais completas e não repete item. Para os nomes descritivos, o prompt ganhou uma regra (2026-11-11): da foto, o nome é marca e modelo reconhecidos; sem certeza, o veículo fica vazio e a descrição vai para as observações; lado só quando dá para saber. Ela baixou os nomes descritivos do Haiku de 5 para 3 e acabou com a marca errada, mas ele passou a sugerir menos serviço numa foto de amassado. Com a regra, as frases continuaram 98/98 e o dinheiro 97/98 (a falha é segura: nada proposto). O que sobra aparece como veículo novo com ✦ e só é cadastrado no ✓. A resposta cortada ("2 para-choque 850") não se repetiu em 100 chamadas da mesma frase. Ela vira `AI_UNAVAILABLE` e a cota volta. O Gemini 3.8 erra menos nas fotos, mas é o mais lento, e 3 de cerca de 120 chamadas não voltaram em 45 s.

**Ligar** (depois do merge e do deploy da Function `api` terminar):

```bash
cd firebase/functions
npm run ai -- show --project praticos
npm run ai -- on --project praticos --all --provider claude --yes   # grava config/ai.defaultProvider = 'claude'
```

Até lá, depois do deploy, tudo vai ao Gemini 3.8 em `global`. Voltar ao Gemini: `npm run ai -- on --project praticos --all --provider gemini --yes`. Rodar `ai-memory-eval.ts` e `ai-finance-eval.ts` de novo ao mudar o prompt ou o modelo.

## Regras de Negócio

1. **A IA propõe, o usuário salva.** Na Nova OS nada é gravado até o ✓ do topo; as marcas somem ao salvar. "Desfazer" tira o que a última leitura colocou, volta os valores que ela mudou e põe de volta o que ela tirou.
16. **A IA troca só o que ela mesma pôs.** Cliente, veículo, relato e prazo com ✦, que a pessoa ainda não mexeu, podem ser trocados por uma fala nova. O que a pessoa escolheu ou digitou continua intocável (ver [Corrigir o que a IA pôs](#corrigir-o-que-a-ia-pôs-e-lembrar-o-que-foi-dito)).
2. **Tirar só por pedido.** A IA só tira uma linha quando o usuário pede ("tira…", "remove…"); nunca cancela a OS, e só recebe depois do cartão de confirmar (ver "Receber, desconto e status pela voz").
3. **Cada chamada conta**, aplicada ou não. Chamada que falha antes de o modelo responder é devolvida.
4. **Limite por plano** (spec 2026-10-09 §4.2): Free 10, Starter 150, Pro 400, Business 1.000 por mês. `settings/ai.monthlyLimit` sobrepõe (piloto; `-1` = ilimitado). Mês = mês UTC; mês novo = documento novo, sem job de reset.
5. **Cota esgotada** → mensagem clara e o fluxo manual continua livre.
6. **Catálogo nunca é poluído:** item sem correspondência entra na OS só com o nome (sem `id` de catálogo). Preço: o falado; senão o do catálogo; senão `null` ("sem valor").
7. **Cliente:** escolhido sozinho só quando a busca tem certeza (mesmo telefone, mesmo nome, ou um único nome muito próximo). Parecidos → "Qual Juliene?". Nada parecido → cliente novo, cadastrado no ✓ (ver [Cliente e veículo pela voz](#cliente-e-veículo-pela-voz)). Nunca troca um cliente escolhido pela pessoa; o que a IA pôs pode ser corrigido ("não, o cliente é o Pedro").
8. **Veículo:** escolhido sozinho pela placa/série (com ou sem traço, Mercosul ou antiga) ou por um único modelo do mesmo jeito. Placa que não existe → veículo novo, cadastrado no ✓. Modelo sem placa: se nenhum cadastrado é parecido, veículo novo cadastrado no ✓; se há parecidos, pergunta qual, com "Cadastrar" como opção (para não criar repetidos sem perguntar).
14. **Cadastro só no ✓.** Cliente e veículo novos ganham o id na tela, mas só são gravados quando a OS é salva; "Desfazer" antes disso não deixa nada. Numa OS já salva, o novo não entra sozinho: a linha pede para tocar ("Cadastrar … como cliente novo").
15. **Serviços e peças não vão para o catálogo pela voz.** Entram só na OS (regra 6). Um "Salvar no catálogo" na linha fica para depois.
9. **Isolamento:** a empresa vem do token + `X-Company-Id` validado pela membership; o corpo não aceita `companyId` (schema `strict`). Toda busca recebe esse `companyId`.
10. **Relato e prazo:** `notes` (o que o cliente pediu ou o defeito) vai para "O que o cliente pediu" se estiver vazio ou com o texto que a IA pôs. `dueDate` ("pronto sexta", "amanhã") vem como `YYYY-MM-DD` (ou `YYYY-MM-DDTHH:MM` quando a hora foi dita) e preenche "Fica pronto" se não houver data ou se a data for a que a IA pôs; sem hora, fica às 18:00. O modelo recebe a data de hoje no fuso de São Paulo para resolver dias da semana.
11. **Privacidade:** nomes de clientes não vão para o modelo (casamento no servidor); o `context` diz só se há cliente escolhido. O histórico das falas fica só na memória da tela e vai para o modelo junto com a fala nova, sem ser gravado. Logs só têm empresa, contagem de itens e de falas no histórico, código de erro e latência — nunca texto, transcrição ou imagem.
12. **Permissão:** `write:orders` (técnico não usa).
13. **Fotos por pedido:** no máximo 4 (`kAiMaxPhotos`, igual a `MAX_PHOTOS` da Function). Mais fotos entram na OS, mas só as 4 primeiras são lidas. Antes, 5 ou mais da galeria davam 400 e "IA indisponível".
16. **OS salva** (app e web): cliente só quando a OS não tem; veículo cadastrado (placa ou modelo único) entra com ✦; placa ou nome novo vira a linha "Ouvi…"/"… não está no cadastro", que cadastra com um toque; relato só em campo vazio. "Desfazer" tira o que a fala pôs. No web: `savedOrderFill` em `lib/orders/assist-draft.ts`.
17. **Câmera** só abre ao tocar em Foto. **Microfone:** o "Falar" ouve na própria barra (reconhecimento de fala do aparelho, `speech_to_text`) e manda o texto; sem permissão, a barra vira um campo para digitar. Continua ouvindo até tocar em parar: quando o iPhone encerra a sessão sozinho (pausa de 10 s ou o limite de cerca de 1 minuto), outra começa e o texto continua; só termina sozinho depois de 20 s sem fala nova ou em 5 minutos. A tela fica acesa enquanto ouve (`wakelock_plus`, em `speech_listener.dart`). A Function já aceita `audio` (m4a/aac, ≤3 MB) para quando o app gravar áudio. O app web já grava no navegador e manda `audio` (webm, ogg ou mp4), ver `docs/WEB_APP.md`.

## Exemplos de Uso

Ligar para uma empresa: ver [Ligar e desligar](#ligar-e-desligar). O app não precisa de opção de build.

```dart
final draft = await AiOrderAssistService().assist(text: 'Revenda Sul, capô 500');
```

## Passos manuais (needs-human)

- ~~Ativar a **Vertex AI API** (`aiplatform.googleapis.com`) no projeto `praticos`~~ feito em 2026-10-11. A conta de serviço de runtime (`…-compute@developer`) tem Editor, que cobre `aiplatform.user`. Não há chave/segredo para cadastrar.
- Opcional: `AI_GEMINI_MODEL` / `AI_VERTEX_LOCATION` / `AI_GEMINI_THINKING` (padrão `gemini-3.8-flash` / `global` / `low`) em `firebase/functions/.env`. O Gemini 2.5 em São Paulo passou da data de retirada do Google e o 3.8 dá 404 lá; voltar a São Paulo exige mudar a política de privacidade.
- Ligar por empresa ou para todas: `npm run ai` ([Ligar e desligar](#ligar-e-desligar)).
- ~~**Claude:** cadastrar a chave antes do deploy (sem ela o deploy da Function `api` falha): `firebase functions:secrets:set ANTHROPIC_API_KEY --project praticos`~~ feito em 2026-10-14.
- **Claude no emulador:** o emulador lê a chave de `firebase/functions/.secret.local` (no `.gitignore`; o repositório é público). Para copiar do Secret Manager sem mostrar a chave: `echo "ANTHROPIC_API_KEY=$(firebase functions:secrets:access ANTHROPIC_API_KEY --project praticos)" >> firebase/functions/.secret.local && chmod 600 firebase/functions/.secret.local`.
- ~~Antes de abrir o Claude para todos: a política de privacidade precisa citar a Anthropic (dados processados fora do Brasil, LGPD art. 33).~~ feito em 2026-10-17 (seção "Assistente de IA" em `privacy.html`).
- ~~Política de privacidade com Anthropic (texto e fotos, EUA) e Google (áudio, fora do Brasil)~~ feito em 2026-11-11. Quando o app do celular gravar áudio: `NSMicrophoneUsageDescription`/`RECORD_AUDIO` e rótulos de privacidade das lojas.

## Testes

- Functions: `src/services/ai/__tests__/` (`fuzzy-match`, `ai-quota.service`, `order-assist.service` com o grupo "changes to lines already in the order", `llm.client`, `gemini.client`, `claude.client`), `src/routes/v1/__tests__/ai.routes.test.ts` (`/status` e `/order-assist`) e `src/__tests__/ai-settings-script.test.ts`.
- Web: `tests/assist-memory.test.ts` (histórico, `context`, trocar só o da IA) e `e2e/ai-memory.spec.ts` (Nova OS e OS salva: placa, relato e prazo corrigidos, histórico no corpo, Desfazer).
- Functions: grupo "history and context (issue #631)" em `order-assist.service.test.ts` (schema, prompt, `replaces`, `guardUserFields`, `withMemorySchema`, `nextDays`).
- App: `test/screens/order/order_screen_v2_test.dart` (grupo "assistant", com "corrects what it put and remembers (#631)": servidor ligado/desligado, mudar valor, tirar e Desfazer, perguntar qual linha, cliente novo salvo no ✓, "Qual Juliene?", veículo novo pela placa e pelo modelo, "Qual Super Classic?"), `test/services/ai_order_assist_service_test.dart` (`parseAiStatusResponse`, leitura de `changes`).
