# Integração PraticOS com ChatGPT e Claude (servidor MCP)

**Data:** 2026-09-12
**Status:** Aprovado para planejamento

## Visão Geral

Expor o PraticOS como servidor MCP remoto, permitindo que o usuário converse com
o próprio sistema dentro do ChatGPT e do Claude: consultar OS, criar ordem de
serviço, mudar status, ver faturamento.

ChatGPT e Claude usam o mesmo protocolo (MCP). Um único servidor atende os dois.
"Plugin do ChatGPT" no sentido de 2023 não existe mais — a superfície atual é o
Apps SDK, construído sobre MCP, e no Claude são os Custom Connectors, também MCP.

### Por que o esforço é menor do que parece

A API de integrações já existe e já foi desenhada para consumo conversacional
pelo bot do WhatsApp. O namespace `/bot` cobre busca unificada, criação completa
de OS, fotos, comentários e faturamento.

Mais importante: as rotas de `/bot` leem o tenant de `req.userContext`. Trocar
apenas o middleware de autenticação dá acesso a toda essa superfície sem alterar
nenhum handler. O middleware `requireLinked` só verifica a existência de
`req.userContext`, então também não bloqueia o reuso.

O `mcpAuth` preenche `req.userContext` diretamente, como a autenticação do bot já
faz. Isso é deliberado: `resolveCompanyContext` trata apenas `apiKey` e `bearer`,
e um tipo novo cairia no 401 final dele. Adicionar um ramo `mcp` ali significaria
mexer num middleware que toda rota da aplicação atravessa. Em vez disso, o
`mcpAuth` aproveita o curto-circuito `if (req.userContext)` que abre aquele
middleware — o compartilhado fica intocado.

### Não objetivos

- Substituir o bot do WhatsApp. São canais complementares.
- Expor a API pública para integradores genéricos. O alvo é o usuário final
  conversando com um assistente.
- Upload de foto pelo chat. O usuário não tem o arquivo em mãos como tem no
  WhatsApp.
- Exclusão de entidades do catálogo (cliente, produto, serviço). Risco alto,
  ganho baixo.

## Arquitetura

```
ChatGPT / Claude
       │  Streamable HTTP (JSON-RPC)
       ▼
  POST /mcp/t/{token}      ← praticos.web.app, via rewrite do Hosting
       │                     para a function `api` (southamerica-east1)
       │
       ├─ mcpAuth (novo)          → token → req.auth + req.userContext
       │
       ▼
  src/mcp/
    server.ts     → handshake MCP, tools/list, resources/list
    tools/        → schema, descrição e annotations de cada tool
    bridge.ts     → despacho in-process para os handlers de rota existentes
    format/       → conversão da resposta da API em markdown compacto
    widgets/      → card da OS (ChatGPT)
       │
       ▼
  routes/bot/*  →  services/*  →  Firestore
```

### Decisão: hospedar dentro das Functions atuais

Alternativas consideradas:

| Opção | Veredito |
|---|---|
| Módulo `/mcp` no app Express atual | **Escolhida** |
| Serviço separado em Cloud Run consumindo a API por HTTP | Infra nova, secrets duplicados, hop extra |
| Servidor MCP falando direto com Firestore | Duplicaria a regra de negócio dos services |

O argumento comum a favor do Cloud Run é aproximar o servidor dos EUA, onde
rodam ChatGPT e Claude. Mas Firestore e API estão em `southamerica-east1`: um
MCP nos EUA faria cada tool call voltar para o Brasil. Um salto longo único
(cliente → Brasil) com o resto local é melhor.

Functions v2 roda sobre Cloud Run, então timeout e streaming não são
impedimento para Streamable HTTP stateless.

`src/mcp/` fica isolado o suficiente para virar serviço próprio depois, se
necessário.

### Decisão: expor pelo domínio do Hosting

O endereço do connector é `https://praticos.web.app/mcp/...`, não a URL crua do
Cloud Functions. Além de ser um endereço apresentável, usar o domínio da marca
conta a favor na revisão dos diretórios.

Hoje o `firebase.json` só tem rewrite para o serviço `praticos-web`. Entra um
rewrite novo apontando `/mcp/**` para a function `api`, que preserva o path
completo — então o `app.use('/mcp', ...)` do Express funciona sem alteração.

Dois cuidados:

- O rewrite do Hosting tem timeout de 60s. O transporte usado é
  request/response, então não há problema. SSE de longa duração exigiria
  revisitar essa decisão.
- As respostas de `/mcp` precisam de `Cache-Control: no-store`, senão o CDN do
  Hosting pode cachear resposta de JSON-RPC.

### Decisão: bridge in-process

Os handlers de `/bot` carregam orquestração real. O `POST /orders/full` tem
cerca de 300 linhas resolvendo find-or-create de dispositivo, deduplicação de OS
recente e montagem de agregados. Reimplementar isso nas tools duplicaria regra
de negócio.

As tools montam um par `req`/`res` em memória e chamam o router Express já
montado, in-process. Sem hop de rede, sem duplicação, e os testes existentes em
`routes/bot/__tests__/` continuam cobrindo a lógica.

Custo aceito: é um despacho interno, fora do fluxo normal do Express. Mitigado
mantendo o bridge em um arquivo único, pequeno e com teste próprio.

## Fases

Cada fase é entregável e utilizável sozinha.

| Fase | Entrega | Autenticação |
|---|---|---|
| 1 | `/mcp` no ar, 13 tools, card da OS, tela Ajustes → Integrações | Token na URL, gerado no app |
| 2 | OAuth 2.1 com DCR e refresh | "Conectar com PraticOS" |
| 3 | Submissão aos diretórios do ChatGPT e do Claude | — |
| 4 | RBAC por colaborador | Papel do usuário aplicado nas tools |

Nas fases 1 a 3 a conexão é por empresa, sempre com permissão de owner/admin.
A fase 4 passa a respeitar o papel de cada colaborador.

## Tools

13 tools. O número é deliberadamente baixo: quanto mais tools, pior o modelo
escolhe entre elas.

### Consulta (`readOnlyHint: true`)

| Tool | Rota | Descrição |
|---|---|---|
| `search` | `POST /bot/search/unified` | Resolve cliente, dispositivo, serviço e produto |
| `list_orders` | `GET /bot/orders/list` | Lista OS com filtros |
| `get_order` | `GET /bot/orders/{n}/details` | Detalhe completo de uma OS |
| `get_today_summary` | `GET /bot/summary/today` | Resumo do dia |
| `get_pending_orders` | `GET /bot/summary/pending` | OS pendentes |
| `get_revenue` | `GET /bot/analytics/financial` | Faturamento por período |
| `list_entities` | `GET /bot/entities/{tipo}` | Lista clientes, dispositivos, serviços ou produtos |

### Escrita (`readOnlyHint: false`)

| Tool | Rota | Annotation |
|---|---|---|
| `create_order` | `POST /bot/orders/full` | `destructiveHint: false` |
| `update_order_status` | `PATCH /bot/orders/{n}/status` | `idempotentHint: true` |
| `update_order` | `PATCH /bot/orders/{n}` | `idempotentHint: true` |
| `add_order_item` | `POST .../services` e `.../products` | `destructiveHint: false` |
| `add_order_comment` | `POST .../comments` | `destructiveHint: false` |
| `create_entity` | `POST /bot/entities/{tipo}` | `destructiveHint: false` |

### Regras das tools

**`search` é obrigatória antes de criar.** Mesma regra que o SKILL.md do bot já
impõe. Sem ela o modelo inventa `customerId`. A descrição de `create_order`
declara explicitamente que os IDs precisam vir de `search`.

**Saída enxuta.** As respostas de `/bot` trazem `formatContext` e agregados
pensados para o bot montar card. Repassar isso cru queima contexto. Cada tool
passa por um formatador que devolve markdown compacto. No ChatGPT o card visual
acompanha como widget.

**Tools com parâmetro de tipo.** Três tools cobrem mais de uma rota através de um
parâmetro obrigatório, em vez de virar várias tools:

- `add_order_item` recebe `type: 'service' | 'product'`
- `list_entities` e `create_entity` recebem
  `type: 'customer' | 'device' | 'service' | 'product'`

Isso mantém a lista de tools curta sem esconder a intenção do modelo.

**Listas truncadas.** Toda tool que retorna lista tem teto explícito de itens
(padrão: 20, configurável por parâmetro até 50), senão uma empresa com milhares
de OS estoura o contexto.

**Nomenclatura.** Nomes e descrições em inglês, conforme a regra 1 do CLAUDE.md
e o que os revisores dos diretórios esperam. O `title` legível, exibido ao
usuário, em português: "Buscar cliente ou OS", "Criar ordem de serviço".

## Autenticação

### Fase 1: token na URL

O ChatGPT e o claude.ai oferecem apenas duas opções ao adicionar um connector:
sem autenticação ou OAuth. Não há campo para header customizado. Enquanto o
OAuth não existe, o token vai no path:

```
https://praticos.web.app/mcp/t/{token}
```

O usuário cola essa URL como endereço do connector. Para o cliente MCP é "sem
autenticação"; o token no path identifica a empresa.

**Riscos e mitigações.** Token em URL aparece em log de servidor e em histórico
de navegação. É aceito como ponte temporária porque o token é opaco e aleatório,
vinculado a uma única empresa, revogável a qualquer momento e expira em 90 dias.
O middleware de log da aplicação redige o path.

**O que a redação não alcança:** Cloud Run e Firebase Hosting registram a URL
completa nos próprios logs de plataforma, antes de qualquer código nosso rodar.
Nenhuma mitigação no nível da aplicação muda isso. Ou seja, enquanto o token
viajar na URL, ele está nos logs de plataforma do projeto — acessível a quem
tiver acesso de leitura a eles. É a razão mais forte para a fase 2 não ser
opcional, e precisa estar escrito na documentação pública da feature para que
quem gera um token saiba o que está aceitando.

**Armazenamento.** Reusa a coleção `apiKeys`, com `type: 'mcp'` e `userId`. O
middleware `mcpAuth` preenche `req.auth` e o restante do pipeline funciona sem
alteração.

### Fase 1: tela no app

`Ajustes → Integrações`, a partir de `lib/screens/menu_navigation/settings.dart`.

- Lista as conexões ativas com nome, data de criação e último uso
- Botão de gerar, que exibe a URL completa **uma única vez**, com copiar
- Botão de revogar
- Restrito a owner e admin

Endpoints novos sob `/v1/app/integrations`, com o `bearerAuth` que o app já usa:

| Método | Rota |
|---|---|
| `GET` | `/v1/app/integrations/tokens` |
| `POST` | `/v1/app/integrations/tokens` |
| `DELETE` | `/v1/app/integrations/tokens/{id}` |

### Fase 2: OAuth 2.1 próprio

**Decisão: não usar IdP externo.** Os usuários já existem no Firebase Auth.
Trazer Auth0 ou equivalente significaria migrar identidade — problema grande
para resolver um problema médio. O Firebase Auth já autentica a pessoa; falta
apenas a casca OAuth.

Componentes:

- `/.well-known/oauth-authorization-server`
- `/.well-known/oauth-protected-resource`
- `/authorize` — tela de login em `praticos.web.app/oauth`, reusando Firebase Auth web
- `/token` com suporte obrigatório a `refresh_token`
- `/register` — registro dinâmico de cliente (DCR)
- Callback da Anthropic: `https://claude.ai/api/mcp/auth_callback`

Sem `refresh_token` os usuários sofrem falhas aleatórias quando o token expira,
e isso é motivo de reprovação na revisão dos diretórios.

Nessa fase o token passa a ser por pessoa, não por empresa, o que habilita
naturalmente a fase 4.

## Card da OS (ChatGPT)

Um único componente, reusado por `get_order`, `create_order`,
`update_order_status` e `add_order_item`. O conteúdo segue o que já está
especificado em `backend/bot/workspace/skills/praticos/references/os-card.md`.

Servido como resource `ui://praticos/order-card`, apontado pelo `_meta` da tool.
Bundle React pequeno, embutido no recurso HTML.

### Regra de degradação

**O texto da tool precisa ser completo sozinho.** O Claude não renderiza widget.
Se alguma informação essencial existir apenas no card, a experiência no Claude
quebra. O card é apresentação, nunca conteúdo exclusivo.

### Botões de ação

O card tem botões que chamam tools via `window.openai.callTool`:

| Botão | Tipo | Comportamento |
|---|---|---|
| Copiar link do cliente | Leitura | Ação imediata |
| Marcar como concluída | Escrita | Confirmação no próprio card |
| Aprovar | Escrita | Confirmação no próprio card |

Um clique que grava pula a confirmação natural do chat. Por isso toda ação de
escrita no card entra em estado de confirmação primeiro — o botão vira
"Confirmar? Sim / Cancelar" — antes de chamar a tool. Ações de leitura vão
direto.

### Risco a validar cedo

As fotos vêm de URL assinada do Firebase Storage e o iframe do ChatGPT tem CSP
restritiva. O domínio do Storage precisa ser declarado. Validar na primeira
semana de implementação, não no fim.

## Segurança

- Rate limit dedicado para `/mcp`, separado do `apiCoreLimiter`
- Toda escrita via MCP registrada na auditoria com origem `mcp`, distinguindo do
  que veio do app
- Nomes de cliente e textos de comentário entram no contexto do modelo como
  **dado, nunca como instrução**. Um cliente pode escrever qualquer coisa em um
  comentário de OS. O system prompt do servidor declara isso explicitamente.
- Listas com teto de itens
- Path redigido nos logs enquanto o token estiver na URL

## Testes

Segue o padrão existente em `routes/bot/__tests__/`.

| Nível | Escopo |
|---|---|
| Unitário | `bridge.ts`, formatadores de saída, `mcpAuth` |
| Integração | `tools/list` e `tools/call` para cada uma das 13 tools |
| Manual | MCP Inspector → Claude Code → claude.ai → ChatGPT dev mode |

A ordem do teste manual é intencional: o Inspector isola problemas de protocolo,
o Claude Code isola problemas de transporte, e só então entram os dois clientes
finais.

## Submissão aos diretórios (fase 3)

Requisitos conhecidos, a confirmar contra a documentação vigente no momento da
submissão:

**Claude**
- Organização Team ou Enterprise (não disponível em plano individual)
- Acesso de gerenciamento de diretório (owner da organização)
- Toda tool com `title` legível e safety hint aplicável
- Nome de tool com no máximo 64 caracteres
- Conta de teste para os revisores

**ChatGPT**
- Submissão pelo portal de plugins
- Nome, logo, descrição, URL da empresa e da política de privacidade
- Prompts de teste com respostas esperadas
- Login OAuth feito de dentro do fluxo de submissão, mais usuário e senha para
  os revisores testarem
- `offline_access` no escopo OAuth, senão o ChatGPT perde acesso quando a
  autorização original expira

## Documentação a produzir

Conforme a regra 12 do CLAUDE.md:

- `docs/MCP_INTEGRATION.md` — documentação técnica da feature
- Artigo público no site Eleventy (pt, en, es), com dados em
  `firebase/hosting/src/_data/docs/` e templates em `firebase/hosting/src/docs/`
- Hub de docs atualizado em `src/_data/docs.json`

## Referências

- [Submitting apps to the ChatGPT app directory](https://help.openai.com/en/articles/20001040-submitting-apps-to-the-chatgpt-app-directory)
- [Build with the Apps SDK](https://help.openai.com/en/articles/12515353-build-with-the-apps-sdk)
- [Submitting to the Connectors Directory — Claude](https://claude.com/docs/connectors/building/submission)
- [Building custom connectors via remote MCP servers](https://support.anthropic.com/en/articles/11503834-building-custom-connectors-via-remote-mcp-servers)
