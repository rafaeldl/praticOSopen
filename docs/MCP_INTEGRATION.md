# Integração MCP (ChatGPT e Claude)

Permite que uma empresa use o PraticOS de dentro do ChatGPT e do Claude, através do protocolo MCP (Model Context Protocol). O assistente consulta e opera dados da empresa - ordens de serviço, clientes, dispositivos, serviços e produtos - usando a mesma lógica de negócio do bot de WhatsApp.

## Visão Geral

Cada empresa gera, dentro do próprio app PraticOS, uma URL de conexão única. Essa URL é cadastrada como "connector" no ChatGPT ou no Claude. A partir daí, o assistente passa a enxergar 13 ferramentas (tools) MCP que leem e escrevem dados da empresa, respeitando o isolamento multi-tenant.

Pontos centrais:

- **Endpoint**: `https://praticos.web.app/mcp/t/{token}` - rewrite do Firebase Hosting para a Cloud Function `api`, falando MCP via Streamable HTTP, em modo stateless (`sessionIdGenerator: undefined`).
- **Token de conexão**: gerado no app em **Ajustes → Integrações**. Formato `mcp_` + 48 caracteres hexadecimais. A URL completa é exibida **uma única vez**, expira em 90 dias e pode ser revogada a qualquer momento na mesma tela.
- **Reaproveitamento de lógica**: as tools não reimplementam regra de negócio - elas despacham, em processo, para os mesmos roteadores Express que já atendem o bot de WhatsApp (`routes/bot/*`).
- **Fase 1 usa URL como segredo**: não há OAuth ainda. Isso tem uma limitação de segurança conhecida, documentada abaixo.

## Arquitetura

### Módulos (`firebase/functions/src/mcp/`)

| Arquivo | Responsabilidade |
|---|---|
| `router.ts` | Monta `POST /t/:token` em `/mcp` (`app.use('/mcp', mcpIpLimiter, mcpLimiter, mcpRouter)` em `src/index.ts`). Aplica cabeçalhos `Cache-Control: no-store, no-transform` antes de `mcpAuth`, inclusive na resposta 401, para que o token nunca fique em cache de CDN. Cria o `StreamableHTTPServerTransport` por requisição (stateless) e conecta o `McpServer`. |
| `auth.ts` (`mcpAuth`) | Resolve o token do path (`req.params.token`) em `apiKeys` (`where('key', '==', token)`), valida `active`, `type === 'mcp'` e expiração, e popula `req.auth` e `req.userContext` - o mesmo formato que os handlers `/bot` já esperam. Responde 401 (`Invalid or expired connection token`) sem revelar qual dessas condições falhou. |
| `bridge.ts` (`callRoute`) | Despacha uma chamada para um router Express **em processo** (sem HTTP real), simulando `req`/`res`. Tem um timeout de segurança de 25s (`RESPONSE_TIMEOUT_MS`) para o caso de um handler nunca responder. |
| `server.ts` (`buildMcpServer`) | Monta o `McpServer` por requisição: registra o recurso do card (`registerOrderCardResource`) e as tools de leitura e escrita. |
| `tools/read.ts` | As 7 tools somente-leitura. |
| `tools/write.ts` | As 6 tools de escrita, incluindo a auditoria (`auditWrite`). |
| `format/order.ts`, `format/list.ts` | Formatam as respostas em texto (sempre completo, independente de o host suportar o card visual). |
| `widgets/order-card.ts` | Define o recurso MCP Apps do card (`ui://praticos/order-card`), o allowlist de campos exposto no `structuredContent` e o `_meta` que liga uma tool ao card. |

### Widget (`firebase/functions/widgets/`)

Fonte React do card em `src/order-card.tsx`, lógica pura de decisão (quais botões aparecem, o que muda após uma escrita) isolada em `src/card-state.ts`, tema do host (merge do `hostContext` e aplicação das variáveis CSS) em `src/host-theme.ts`, e a ponte `postMessage` com o host em `src/bridge.ts`.

```bash
cd firebase/functions/widgets && npm run build
```

Esse comando roda o `build.mjs`: usa `esbuild` para empacotar `src/order-card.tsx` num único arquivo IIFE minificado (`dist/order-card.js`) e depois grava esse JS como uma constante de string em `../src/mcp/widgets/bundle.ts` (`export const ORDER_CARD_BUNDLE = "..."`). Esse arquivo gerado **é commitado** - o `predeploy` das Functions roda apenas `tsc`, não o build do widget, então `bundle.ts` precisa já estar atualizado no repositório antes do deploy. Sempre que `order-card.tsx`, `card-state.ts`, `host-theme.ts`, `bridge.ts` ou `bridge-protocol.ts` mudarem, rodar o build e commitar o `bundle.ts` resultante junto.

O `build.mjs` registra um plugin de resolução (`node-resolve-bare-imports`) que resolve imports "nus" (`react`, `react-dom`, etc.) usando o algoritmo padrão do Node a partir de `widgets/node_modules`, em vez de deixar o `esbuild` descobrir sozinho - isso evita depender de qualquer configuração de resolução de módulos herdada do restante do monorepo `firebase/`.

### Segurança de transporte

- Rate limiting dedicado (`mcpIpLimiter`, `mcpLimiter`) antes mesmo do router MCP ser alcançado.
- `firebase.json` tem uma entrada `/mcp/**` em `hosting.headers` reforçando `no-store` na borda da CDN - complementar ao header setado em `router.ts`, cobrindo inclusive respostas que nunca chegam à function (ex.: 429 do rate limiter).
- Erros do handler nunca logam `req.path`/`req.params` (carregam o token); apenas o erro em si.

## Fluxo de Dados

```
Cliente MCP (ChatGPT / Claude)
        |  POST /mcp/t/{token}  (JSON-RPC sobre Streamable HTTP)
        v
router.ts  ---(no-store headers)--->  mcpAuth
        |                                  |
        |                     apiKeys: valida key, active, type='mcp', expiresAt
        |                     popula req.auth + req.userContext
        v
buildMcpServer(req)  -->  tool handler (read.ts / write.ts)
        |
        v
callRoute(router, { method, path, body, source: req })   <-- bridge.ts, em processo
        |
        v
Roteador /bot existente (orders.routes.ts, orders-management.routes.ts,
comments.routes.ts, entities.routes.ts, summary.routes.ts,
analytics.routes.ts, unified-search.routes.ts)
        |
        v
Services de negócio (os mesmos usados pelo bot de WhatsApp)
        |
        v
Firestore (multi-tenant, isolado por companyId)
```

A resposta segue o caminho inverso: o corpo do `/bot` é formatado em texto (`format/order.ts`, `format/list.ts`) e, para as tools de OS, também em `structuredContent` filtrado por allowlist para alimentar o card.

## Regras de Negócio

### As 16 tools

**Leitura** (`readOnlyHint: true`):

| Tool | Função |
|---|---|
| `search` | Resolve cliente, dispositivo, serviço ou produto em IDs. Deve ser chamada antes de `create_order` ou `add_order_item` - só os IDs retornados por ela são válidos. |
| `list_orders` | Lista ordens de serviço, com filtro opcional por status. |
| `get_order` | Detalhe completo de uma OS (inclui foto de capa e contagem de fotos). |
| `list_order_photos` | Lista as fotos anexadas à OS com link direto, descrição, autor e data. |
| `get_today_summary` | Resumo do dia. |
| `get_pending_orders` | OS pendentes. |
| `get_revenue` | Faturamento. |
| `list_entities` | Lista cadastros (clientes, dispositivos, serviços, produtos). |

**Escrita** (`readOnlyHint: false`):

| Tool | Função |
|---|---|
| `create_order` | Cria uma OS. `customerId`, `deviceId(s)`, `serviceId`, `productId` **precisam** vir de uma chamada anterior a `search` - nunca são inventados pelo modelo. Não aceita um id de OS existente (não serve para "criar com este número"); status inicial padrão `quote`, aceitando apenas `quote`, `approved` ou `progress` - avançar além disso é `update_order_status`. |
| `update_order_status` | Muda o status de uma OS existente. |
| `update_order` | Atualiza campos de uma OS existente. |
| `add_order_item` | Adiciona um serviço ou produto a uma OS. |
| `add_order_comment` | Adiciona um comentário a uma OS. |
| `create_entity` | Cadastra cliente, dispositivo, serviço ou produto. |
| `upload_order_photo` | Anexa uma foto (base64) à OS informada com descrição e nome opcionais. |
| `delete_order_photo` | Exclui uma foto da OS pelo `photoId` (`destructiveHint: true`). |

### Limites de listagem

Toda tool de listagem usa `DEFAULT_LIMIT = 20` e `MAX_LIMIT = 50` (`tools/read.ts`): sem `limit` explícito, retorna até 20; qualquer valor pedido acima de 50 é reduzido para 50.

### Card MCP Apps e degradação

- Recurso `ui://praticos/order-card`, mime `text/html;profile=mcp-app` (exigido pela spec MCP Apps `ext-apps 2026-01-26`).
- A ligação tool → card é feita por `_meta.ui.resourceUri` (padrão MCP Apps, funciona em ChatGPT e Claude) e pelo alias `_meta['openai/outputTemplate']` (compatibilidade com runtimes mais antigos do ChatGPT).
- `ui.visibility` é deliberadamente omitido: o padrão (`["model", "app"]`) mantém a tool chamável tanto pelo modelo quanto pelo card.
- O card conversa com o host via `postMessage` (JSON-RPC, spec `ext-apps 2026-01-26`), implementado em `widgets/src/bridge.ts`.
- Botões do card: **Aprovar**, **Concluir** (ambos passam por um estado de confirmação dentro do próprio card antes de disparar a escrita) e **Copiar link do cliente**. Os botões de status só aparecem quando o status atual da OS permite a ação (`availableActions` em `card-state.ts`); uma falha de rede deixa a OS como estava, sem assumir nada sobre o estado do servidor.
- Um novo `ui/notifications/tool-result` da **mesma** OS (ex.: o modelo mudou o status pelo chat com o card aberto) substitui a OS local do card sem remontá-lo; a confirmação aberta só sobrevive se a nova OS ainda permitir aquela escrita, e a mensagem é limpa se o status mudou (`receiveOrder` em `card-state.ts`). OS diferente remonta o card (`key={order.number}`).
- Tema: o HTML do recurso declara `color-scheme: light dark` e valores de fallback em `:root` para as variáveis de estilo que o card usa (`--color-text-primary`, `--color-border-*`, `--color-text-danger`, `--font-sans`). Quando o host manda `theme` e `styles.variables` (no `hostContext` do `ui/initialize` ou em `ui/notifications/host-context-changed`, que é parcial e é mesclado), elas são aplicadas inline no `<html>` e têm prioridade. `styles.css.fonts` não é injetado; a fonte cai no restante da pilha de `--font-sans`.
- Nunca dar `height: 100%` / `100vh` a `html`, `body` ou `#root`: a ponte mede o tamanho observando `document.documentElement` para enviar `ui/notifications/size-changed`, e isso só reflete a altura do conteúdo enquanto nada estica esses elementos (há teste em `widgets.test.ts`).
- `structuredContent` segue um **allowlist** explícito (`toCardData` em `widgets/order-card.ts`): número, status, total, `shareUrl`, `coverPhotoUrl`, `photosCount`, nome do cliente, nome/serial dos dispositivos, itens (nome/valor/quantidade). Telefone do cliente e URL interna de foto do bot (`mainPhotoUrl`) nunca saem do servidor.
- Foto de capa no card: Quando a OS possui fotos, a URL pública (`coverPhotoUrl`) é enviada no `structuredContent.order` e renderizada no topo do card. O domínio do Firebase Storage está liberado em `_meta.ui.csp.resourceDomains: ['https://storage.googleapis.com']`.
- CSP e domínio do widget: ficam no `_meta` do **resource** (em `resources/list` e em `resources/read`), não no `_meta` da tool — é onde a spec MCP Apps e o ChatGPT leem. O resource declara `ui.csp` (padrão), `openai/widgetCSP` (espelho para runtimes antigos do ChatGPT) e `openai/widgetDomain: 'https://praticos.web.app'`, domínio exclusivo exigido pelo ChatGPT para submeter o app. O domínio usa a chave do ChatGPT, e não `ui.domain`, porque o formato é definido por cada host e um valor no formato do ChatGPT poderia ser recusado pelo Claude.
- Um host sem suporte a MCP Apps simplesmente ignora o recurso e mostra apenas o texto da resposta - que é sempre completo, nunca um resumo pensado só para acompanhar o card.

### Auditoria de escrita

Toda tool de escrita loga uma linha estruturada antes de retornar (`auditWrite` em `tools/write.ts`):

```json
{"event":"mcp_write","tool":"update_order_status","origin":"mcp","companyId":"...","userId":"...","orderNumber":123}
```

Apenas identificadores passam por um allowlist explícito (`orderNumber`, `photoId`, `type`, `customerId`, `serviceId`, `productId`, `deviceId` - com `add_order_item` resolvendo seu `itemId`+`type` para `serviceId`/`productId`). Telefone, e-mail, endereço, buffer base64 e texto livre (corpo de comentário, descrições de item/cliente/foto) nunca entram no log: um campo novo adicionado depois ao input de uma tool fica de fora do log por padrão, não vaza por padrão.

### Quem pode gerar uma conexão

- **Backend**: exige papel owner ou admin (mesma checagem de `apiKeys` usada para outros tipos de chave).
- **App (Flutter)**: a entrada "Integrações" em Ajustes usa o mesmo guard de "Colaboradores" (`canManageUsers`, `PermissionType.manageUsers`), que hoje cobre apenas admin. Um dono (owner) de empresa cadastrado via bot de WhatsApp ainda não tem o papel `owner` reconhecido no lado Flutter, então não vê a entrada até essa lacuna ser corrigida (rastreado separadamente, fora do escopo desta fase).

### UI de geração/revogação (app)

Tela `lib/screens/integrations/integration_list_screen.dart`:
- "+" no topo abre um diálogo pedindo um nome (ex.: "Meu ChatGPT").
- Ao salvar, a URL completa aparece uma única vez, com botão "Copiar URL" - a partir daí ela não é mais recuperável pela UI, nem logada, nem incluída em mensagens de erro.
- A lista mostra nome, "Nunca usada" ou "Último uso em {data}", e um botão "Revogar" com confirmação ("Revogar esta conexão? Quem estiver usando esta URL perde o acesso.").
- Erros do backend chegam por `code` (`FORBIDDEN`, `NOT_FOUND`), nunca pela mensagem de diagnóstico em inglês do backend.

## Segurança - limites conhecidos da fase 1

O token viaja na própria URL, porque nem o ChatGPT nem o claude.ai permitem cabeçalho customizado num connector (comentário de `mcpAuth`). A aplicação redige o token dos próprios logs, mas os logs de plataforma do Cloud Run e do Firebase Hosting registram a URL completa, e nenhum código de aplicação consegue mudar isso. A Fase 2 substitui o token na URL por OAuth ("Conectar com PraticOS"), eliminando esse ponto.

## Firestore

Índice composto em `apiKeys` (`companyId` ASC, `type` ASC, `createdAt` DESC), necessário para listar os tokens de uma empresa por data. Definido em `firebase/firestore.indexes.json` e já implantado em produção. Não há workflow de CI que implante índices do Firestore - o deploy é manual:

```bash
cd firebase && npm run deploy:indexes
```

## Exemplos de Uso

### URL do connector

```
https://praticos.web.app/mcp/t/mcp_1a2b3c4d5e6f...   (48 caracteres hex após "mcp_")
```

Essa é a URL completa mostrada uma única vez em Ajustes → Integrações → Nova conexão.

### Exemplo de `tools/call`

Requisição JSON-RPC para a tool `list_orders`, filtrando por status:

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "tools/call",
  "params": {
    "name": "list_orders",
    "arguments": {
      "status": "progress",
      "limit": 10
    }
  }
}
```

Resposta (resumida): um `content` de texto sempre completo e, quando a tool está ligada ao card (ex.: `get_order`, `create_order`, `update_order_status`), um `structuredContent.order` com o allowlist de campos usado pelo card.

### Fluxo típico do assistente

1. `search` para resolver nomes em IDs (cliente, dispositivo, serviço).
2. `create_order` usando exclusivamente os IDs retornados por `search`.
3. `update_order_status` para aprovar ou concluir.
4. `add_order_comment` / `add_order_item` para detalhar a OS conforme a conversa avança.

Toda chamada de escrita gera uma linha `mcp_write` no log, e toda chamada passa pelo mesmo isolamento multi-tenant (`companyId` de `req.userContext`) que o restante do sistema.
