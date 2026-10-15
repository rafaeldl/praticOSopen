# AI_ORDER_ASSIST.md

## Visão Geral

Assistente de IA na **Nova OS** (passo 14 do redesenho, fase 2/3 da spec): o usuário toca em **Foto** e/ou **Falar o que fazer**, a Function `aiOrderAssist` lê a foto e o texto e devolve um **rascunho** da OS (cliente, veículo/placa, serviços e peças casados com o catálogo da empresa). Também muda ou tira itens que já estão na OS ("a pintura é 300", "tira a lavação"), na Nova OS e numa OS salva. O app preenche **a mesma Nova OS em branco**, com marca-texto amarelo no que a IA pôs, e o botão continua **"Salvar OS"**. A Function nunca grava a OS.

Specs: `docs/superpowers/specs/2026-10-11-telas-os-ia-design.md` (vale sobre) e `2026-10-09-os-ai-assistant-design.md` (§4 arquitetura, §4.2 cota).

**Desligado por padrão.** Quem liga é o servidor, sem build novo do app nem deploy (ver [Ligar e desligar](#ligar-e-desligar)):

- **Para todas as empresas:** `config/ai.enabledForAll == true`.
- **Por empresa:** `companies/{companyId}/settings/ai.enabled` (`true` ou `false`), que vale sobre a chave geral.

O app pergunta ao servidor (`GET /v1/app/ai/status`) ao abrir a OS e só mostra "Falar o que fazer" (e só manda a foto para a IA) quando a resposta é `enabled: true`. Desligada, a Function responde `AI_DISABLED` sem contar cota nem chamar o modelo.

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
| `src/services/ai/order-assist.deps.ts` | Dependências de produção (Firestore da empresa, cota, Vertex AI) |
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
| `lib/screens/order/order_screen_v2.dart` | Botões Foto (vidro) e Falar (grafite) na Nova OS; aplica o rascunho e marca o que a IA preencheu |
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
     cliente por nome (searchCustomers); veículo por placa/série
  ◀── rascunho {transcript, customer, device, items[], changes[], notes, dueDate, usage}
App: aplica changes (pergunta qual linha se houver duas iguais), soma items, ✦ azul no que veio da IA,
     aviso "Preenchi… · Desfazer" → ✓ no topo
```

## Mudar e tirar itens

O app manda as linhas que estão na tela (`order.services` e `order.products`: nome, valor e, nas peças, quantidade; até 50 de cada). O prompt numera essas linhas (`S1`, `S2`… serviços; `P1`… peças) e o modelo devolve **operações**:

| `action` | Quando | Campos |
|---|---|---|
| `add` | Item novo ("põe um alinhamento") | `kind`, `name`, `value`, `quantity` |
| `update` | Mudar valor ou quantidade de uma linha ("a pintura é 300", "são 3 litros") | `line` + `value`/`quantity` |
| `remove` | Tirar uma linha ("tira a lavação") | `line` |

Quando duas linhas servem ("a pintura" com duas Pintura na OS), o modelo deixa `line: null` e lista as duas em `candidates`.

O servidor separa a resposta: `add` vira `items` (casado com o catálogo, como antes) e `update`/`remove` viram `changes`, com a linha como `{kind, index}`. Muda descartada: linha que não existe na OS enviada, `update` sem valor nem quantidade, ambígua com menos de duas linhas válidas. Quantidade só vale em peça, arredondada e no mínimo 1. App antigo (sem `order`) recebe só `items`, como antes.

No app (`_applyDraft` em `order_screen_v2.dart`):

- **Mudar:** altera o valor/quantidade da linha (só na OS, nunca no catálogo) e marca com ✦.
- **Tirar:** tira na hora. É pedido do usuário, não ideia da IA, e o "Desfazer" põe de volta no mesmo lugar.
- **Duas linhas iguais:** abre a tela de escolher (`pickOne`) com a pergunta "Qual Pintura?" e o valor de cada uma. Voltar sem escolher ignora essa mudança.
- O app guarda as linhas que mandou; se a lista mudar enquanto a IA responde, a mudança vai para a linha certa ou é ignorada.

### Teste de intenção (2026-10-15)

30 frases sobre uma OS de oficina (adicionar, mudar valor, mudar quantidade, tirar, comando composto, item repetido, OS vazia), 3 rodadas por caminho. Scripts fora do repositório (scratchpad).

| Caminho | Acertos | Tempo (mediana) |
|---|---|---|
| A · Claude Sonnet + catálogo no prompt | 29/30 nas 3 rodadas | ~1,6 s |
| A · Gemini Flash + catálogo no prompt | 29/30 a 30/30 | ~1,5 s |
| C · Claude sem catálogo + Jev escolhendo do catálogo | 29/30 nas 3 rodadas | ~1,7 s (p90 até 6 s) |

O erro comum ("tira o óleo e o filtro", com o serviço "Troca de óleo" e a peça "Óleo" na OS) é o modelo perguntar qual das duas linhas: aceitável, o app pergunta. O caminho C errou uma vez a peça "Pastilha de freio dianteira" e somou uma chamada.

**Jev para escolher do catálogo: por enquanto não.** O catálogo no prompt é pequeno: metade das empresas tem 2 serviços e 2 peças, 90% até 17, e só 3 empresas passam de 150 (o limite do prompt). O caminho A acerta o mesmo, é mais rápido e simples. Rever quando houver empresas com catálogo grande ou erros de casamento medidos: o Jev entra no passo 5, só para o nome que não casou.

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
7. **Cliente:** só é escolhido quando o nome bate com um cadastrado (exato, ou único resultado). Sem cadastro, aparece "Ouvi “X”. Toque para escolher o cliente". Nunca troca um cliente já escolhido.
8. **Veículo:** só pela placa/série cadastrada (variações `ABC1234`/`ABC-1234`). Placa lida que não existe → "“Classic · NXS8620” não está no cadastro" (toque para escolher). Nome sozinho não escolhe veículo.
9. **Isolamento:** a empresa vem do token + `X-Company-Id` validado pela membership; o corpo não aceita `companyId` (schema `strict`). Toda busca recebe esse `companyId`.
10. **Relato e prazo:** `notes` (o que o cliente pediu ou o defeito) vai para "O que o cliente pediu" se estiver vazio. `dueDate` ("pronto sexta", "amanhã") vem como `YYYY-MM-DD` (ou `YYYY-MM-DDTHH:MM` quando a hora foi dita) e preenche "Fica pronto" se não houver data; sem hora, fica às 18:00. O modelo recebe a data de hoje no fuso de São Paulo para resolver dias da semana.
11. **Privacidade:** nomes de clientes não vão para o modelo (casamento no servidor). Logs só têm empresa, contagem de itens, código de erro e latência — nunca texto, transcrição ou imagem.
12. **Permissão:** `write:orders` (técnico não usa).
13. **Câmera** só abre ao tocar em Foto. **Microfone:** o "Falar" ouve na própria barra (reconhecimento de fala do aparelho, `speech_to_text`) e manda o texto; sem permissão, a barra vira um campo para digitar. A Function já aceita `audio` (m4a/aac, ≤3 MB) para quando o app gravar áudio.

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
- Antes de abrir o Claude para todos: a política de privacidade precisa citar a Anthropic (dados processados fora do Brasil, LGPD art. 33).
- Antes de abrir para todos: política de privacidade (fotos/texto processados pelo Google Vertex AI) e, quando houver gravação de áudio, `NSMicrophoneUsageDescription`/`RECORD_AUDIO` e rótulos de privacidade das lojas.

## Testes

- Functions: `src/services/ai/__tests__/` (`ai-quota.service`, `order-assist.service` com o grupo "changes to lines already in the order", `llm.client`, `gemini.client`, `claude.client`), `src/routes/v1/__tests__/ai.routes.test.ts` (`/status` e `/order-assist`) e `src/__tests__/ai-settings-script.test.ts`.
- App: `test/screens/order/order_screen_v2_test.dart` (grupo "assistant": servidor ligado/desligado, mudar valor, tirar e Desfazer, perguntar qual linha), `test/services/ai_order_assist_service_test.dart` (`parseAiStatusResponse`, leitura de `changes`).
