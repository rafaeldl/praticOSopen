# AI_ORDER_ASSIST.md

## Visão Geral

Assistente de IA na **Nova OS** (passo 14 do redesenho, fase 2/3 da spec): o usuário toca em **Foto** e/ou **Falar o que fazer**, a Function `aiOrderAssist` lê a foto e o texto e devolve um **rascunho** da OS (cliente, veículo/placa, serviços e peças casados com o catálogo da empresa). Também muda ou tira itens que já estão na OS ("a pintura é 300", "tira a lavação"), na Nova OS e numa OS salva. O app preenche **a mesma Nova OS em branco**, com marca-texto amarelo no que a IA pôs, e o botão continua **"Salvar OS"**. A Function nunca grava a OS.

Specs: `docs/superpowers/specs/2026-10-11-telas-os-ia-design.md` (vale sobre) e `2026-10-09-os-ai-assistant-design.md` (§4 arquitetura, §4.2 cota).

**Desligado por padrão.** Quem liga é o servidor, sem build novo do app nem deploy (ver [Ligar e desligar](#ligar-e-desligar)):

- **Para todas as empresas:** `config/ai.enabledForAll == true`.
- **Por empresa:** `companies/{companyId}/settings/ai.enabled` (`true` ou `false`), que vale sobre a chave geral.

O app pergunta ao servidor (`GET /v1/app/ai/status`) ao abrir a OS e só mostra "Falar o que fazer" (e só manda a foto para a IA) quando a resposta é `enabled: true`. Desligada, a Function responde `AI_DISABLED` sem contar cota nem chamar o modelo.

## Primeiro uso

`showAiIntroOnce` (`lib/screens/order/assistant/ai_intro.dart`) abre uma folha em Início, uma vez por aparelho, depois que a lista carrega e só com o assistente ligado. "Experimentar agora" abre a Nova OS já ouvindo (`openNewOrder(startTalking: true)`). Com qualquer resposta, não volta a aparecer (`ai_intro_seen_v1` em `SharedPreferences`).

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
| `src/routes/v1/ai.routes.ts` | `GET /v1/app/ai/status` (ligada? + uso do mês, sem contar) e `POST /v1/app/ai/order-assist` no `api` (bearer + `resolveCompanyContext` + `apiCoreLimiter`); os dois exigem `write:orders` |
| `src/services/ai/order-assist.service.ts` | Validação (zod), prompt, parse da resposta, casamento com catálogo, orquestração (`runOrderAssist`) com dependências injetáveis |
| `src/services/ai/order-assist.deps.ts` | Dependências de produção (Firestore da empresa, cota, Vertex AI); carrega até 2.000 clientes e veículos (só nome, telefone, placa, marca) para comparar na memória |
| `src/services/ai/fuzzy-match.ts` | Busca por semelhança sem IA: `matchCustomer` e `matchDevice` (ver [Cliente e veículo pela voz](#cliente-e-veículo-pela-voz)) |
| `src/services/ai/ai-quota.service.ts` | Chave geral (`config/ai`) + chave da empresa (`settings/ai`) → `resolveAiSettings`; cota mensal (`aiUsage/{YYYY-MM}`) e `getAiUsage` |
| `scripts/ai-settings.ts` | `npm run ai`: liga/desliga por empresa ou para todas |
| `src/services/ai/llm.client.ts` | Interface neutra (`LlmClient`, `LlmRequest` com JSON Schema) e `LlmRouter`, que escolhe o provedor por pedido |
| `src/services/ai/gemini.client.ts` | `VertexGeminiClient` (Gemini no Vertex AI, credencial da conta de serviço; sem chave) e `toGeminiSchema` |
| `src/services/ai/claude.client.ts` | `ClaudeClient` (Claude na API da Anthropic, `@anthropic-ai/sdk`, structured outputs, fallback do servidor) |

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
Nova OS em branco
  Foto → câmera (só aqui) → sheet com a foto ─┐
  Falar → sheet (texto/ditado) ───────────────┤ "Pronto"
                                              ▼
POST /v1/app/ai/order-assist {text?, photos?[base64 JPEG ≤2 MB, até 4], audio?, locale, order?{services[], products[]}}
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

## Provedores

A Function não depende de um provedor. `order-assist.service.ts` monta um `LlmRequest` (prompt, texto, fotos/áudio e o JSON Schema da resposta) e o `LlmRouter` entrega para o cliente certo:

1. `settings/ai.provider` da empresa (`gemini` ou `claude`);
2. senão `config/ai.defaultProvider` (padrão de todas as empresas);
3. senão `AI_PROVIDER` no ambiente da Function;
4. senão `gemini`.

Se o provedor escolhido não lê alguma parte do pedido (o Claude não recebe áudio), o pedido vai para o provedor padrão. Para somar outro provedor: criar um `LlmProviderClient` (`generateJson` + `supportsMedia`), registrar no `LlmRouter` em `order-assist.deps.ts` e incluir o nome em `LLM_PROVIDERS`.

| Provedor | Modelo padrão | Variáveis | Credencial | Onde roda |
|---|---|---|---|---|
| `gemini` | `gemini-2.5-flash` | `AI_GEMINI_MODEL`, `AI_VERTEX_LOCATION` | Conta de serviço (sem chave) | Vertex AI, São Paulo |
| `claude` | `claude-sonnet-5-5` | `AI_CLAUDE_MODEL`, `AI_CLAUDE_EFFORT` (padrão `low`) | Secret `ANTHROPIC_API_KEY` | API da Anthropic (EUA) |

O Claude usa structured outputs (`output_config.format`) com o mesmo schema e `fallbacks: "default"` (beta `server-side-fallback-2026-07-01`): se o modelo recusar, o servidor da Anthropic tenta outro modelo na mesma chamada. Recusa final, resposta cortada ou erro da API viram `AI_UNAVAILABLE` e a cota é devolvida.

## Regras de Negócio

1. **A IA propõe, o usuário salva.** Na Nova OS nada é gravado até o ✓ do topo; as marcas somem ao salvar. "Desfazer" tira o que a última leitura colocou, volta os valores que ela mudou e põe de volta o que ela tirou.
2. **Tirar só por pedido.** A IA só tira uma linha quando o usuário pede ("tira…", "remove…"); nunca recebe nem cancela a OS.
3. **Cada chamada conta**, aplicada ou não. Chamada que falha antes de o modelo responder é devolvida.
4. **Limite por plano** (spec 2026-10-09 §4.2): Free 10, Starter 150, Pro 400, Business 1.000 por mês. `settings/ai.monthlyLimit` sobrepõe (piloto; `-1` = ilimitado). Mês = mês UTC; mês novo = documento novo, sem job de reset.
5. **Cota esgotada** → mensagem clara e o fluxo manual continua livre.
6. **Catálogo nunca é poluído:** item sem correspondência entra na OS só com o nome (sem `id` de catálogo). Preço: o falado; senão o do catálogo; senão `null` ("sem valor").
7. **Cliente:** escolhido sozinho só quando a busca tem certeza (mesmo telefone, mesmo nome, ou um único nome muito próximo). Parecidos → "Qual Juliene?". Nada parecido → cliente novo, cadastrado no ✓ (ver [Cliente e veículo pela voz](#cliente-e-veículo-pela-voz)). Nunca troca um cliente já escolhido.
8. **Veículo:** escolhido sozinho pela placa/série (com ou sem traço, Mercosul ou antiga) ou por um único modelo do mesmo jeito. Placa que não existe → veículo novo, cadastrado no ✓. Modelo sem placa: se nenhum cadastrado é parecido, veículo novo cadastrado no ✓; se há parecidos, pergunta qual, com "Cadastrar" como opção (para não criar repetidos sem perguntar).
14. **Cadastro só no ✓.** Cliente e veículo novos ganham o id na tela, mas só são gravados quando a OS é salva; "Desfazer" antes disso não deixa nada. Numa OS já salva, o novo não entra sozinho: a linha pede para tocar ("Cadastrar … como cliente novo").
15. **Serviços e peças não vão para o catálogo pela voz.** Entram só na OS (regra 6). Um "Salvar no catálogo" na linha fica para depois.
9. **Isolamento:** a empresa vem do token + `X-Company-Id` validado pela membership; o corpo não aceita `companyId` (schema `strict`). Toda busca recebe esse `companyId`.
10. **Relato e prazo:** `notes` (o que o cliente pediu ou o defeito) vai para "O que o cliente pediu" se estiver vazio. `dueDate` ("pronto sexta", "amanhã") vem como `YYYY-MM-DD` (ou `YYYY-MM-DDTHH:MM` quando a hora foi dita) e preenche "Fica pronto" se não houver data; sem hora, fica às 18:00. O modelo recebe a data de hoje no fuso de São Paulo para resolver dias da semana.
11. **Privacidade:** nomes de clientes não vão para o modelo (casamento no servidor). Logs só têm empresa, contagem de itens, código de erro e latência — nunca texto, transcrição ou imagem.
12. **Permissão:** `write:orders` (técnico não usa).
13. **Câmera** só abre ao tocar em Foto. **Microfone:** o "Falar" ouve na própria barra (reconhecimento de fala do aparelho, `speech_to_text`) e manda o texto; sem permissão, a barra vira um campo para digitar. Continua ouvindo até tocar em parar: quando o iPhone encerra a sessão sozinho (pausa de 10 s ou o limite de cerca de 1 minuto), outra começa e o texto continua; só termina sozinho depois de 20 s sem fala nova ou em 5 minutos. A tela fica acesa enquanto ouve (`wakelock_plus`, em `speech_listener.dart`). A Function já aceita `audio` (m4a/aac, ≤3 MB) para quando o app gravar áudio.

## Exemplos de Uso

Ligar para uma empresa: ver [Ligar e desligar](#ligar-e-desligar). O app não precisa de opção de build.

```dart
final draft = await AiOrderAssistService().assist(text: 'Revenda Sul, capô 500');
```

## Passos manuais (needs-human)

- ~~Ativar a **Vertex AI API** (`aiplatform.googleapis.com`) no projeto `praticos`~~ feito em 2026-10-11. A conta de serviço de runtime (`…-compute@developer`) tem Editor, que cobre `aiplatform.user`. Não há chave/segredo para cadastrar.
- Opcional: `AI_GEMINI_MODEL` / `AI_VERTEX_LOCATION` (padrão `gemini-2.5-flash` / `southamerica-east1`, São Paulo, para os dados ficarem no Brasil — LGPD) em `firebase/functions/.env` se quiser outro modelo/região.
- Ligar por empresa ou para todas: `npm run ai` ([Ligar e desligar](#ligar-e-desligar)).
- ~~**Claude:** cadastrar a chave antes do deploy (sem ela o deploy da Function `api` falha): `firebase functions:secrets:set ANTHROPIC_API_KEY --project praticos`~~ feito em 2026-10-14.
- **Claude no emulador:** o emulador lê a chave de `firebase/functions/.secret.local` (no `.gitignore`; o repositório é público). Para copiar do Secret Manager sem mostrar a chave: `echo "ANTHROPIC_API_KEY=$(firebase functions:secrets:access ANTHROPIC_API_KEY --project praticos)" >> firebase/functions/.secret.local && chmod 600 firebase/functions/.secret.local`.
- ~~Antes de abrir o Claude para todos: a política de privacidade precisa citar a Anthropic (dados processados fora do Brasil, LGPD art. 33).~~ feito em 2026-10-17 (seção "Assistente de IA" em `privacy.html`).
- Antes de abrir para todos: política de privacidade (fotos/texto processados pelo Google Vertex AI) e, quando houver gravação de áudio, `NSMicrophoneUsageDescription`/`RECORD_AUDIO` e rótulos de privacidade das lojas.

## Testes

- Functions: `src/services/ai/__tests__/` (`fuzzy-match`, `ai-quota.service`, `order-assist.service` com o grupo "changes to lines already in the order", `llm.client`, `gemini.client`, `claude.client`), `src/routes/v1/__tests__/ai.routes.test.ts` (`/status` e `/order-assist`) e `src/__tests__/ai-settings-script.test.ts`.
- App: `test/screens/order/order_screen_v2_test.dart` (grupo "assistant": servidor ligado/desligado, mudar valor, tirar e Desfazer, perguntar qual linha, cliente novo salvo no ✓, "Qual Juliene?", veículo novo pela placa e pelo modelo, "Qual Super Classic?"), `test/services/ai_order_assist_service_test.dart` (`parseAiStatusResponse`, leitura de `changes`).
