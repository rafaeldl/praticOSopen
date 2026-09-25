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
| `router.ts` | Monta `POST /t/:token` em `/mcp` (`app.use('/mcp', mcpLimiter, mcpRouter)` em `src/index.ts`). Aplica cabeçalhos `Cache-Control: no-store, no-transform` antes de `mcpAuth`, inclusive na resposta 401, para que o token nunca fique em cache de CDN. Cria o `StreamableHTTPServerTransport` por requisição (stateless) e conecta o `McpServer`. Qualquer outro método em `/t/:token` (`GET`, `DELETE`, ...) recebe `405` com `Allow: POST` e erro JSON-RPC, sem passar pelo `token-guard` nem por `mcpAuth`: em modo stateless não há stream SSE para abrir nem sessão para encerrar, e os clientes MCP sondam `GET` esperando `405`. |
| `token-guard.ts` (`createUnknownTokenGuard`) | Teto global por instância (300/min) para requisições com token que não autenticou recentemente nessa instância, aplicado antes de `mcpAuth`. Tokens que autenticaram na última hora passam direto. |
| `auth.ts` (`mcpAuth`) | Resolve o token do path (`req.params.token`) em `apiKeys` (`where('key', '==', token)`), valida `active`, `type === 'mcp'` e expiração, e popula `req.auth` e `req.userContext` - o mesmo formato que os handlers `/bot` já esperam. Usuário, empresa e papel vêm de `resolveUserContext` (`services/user-context.service.ts`), o mesmo helper do ramo `bearer` de `resolveCompanyContext`. Responde 401 (`Invalid or expired connection token`) sem revelar qual dessas condições falhou. Grava `lastUsedAt` no documento do token (ver abaixo). |
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

- Rate limiting antes da consulta ao Firestore em `mcpAuth`, em duas camadas:
  - `mcpLimiter` (`src/index.ts`): 120/min por token, para limitar um token vazado.
  - `token-guard.ts`: 300/min por instância para tokens desconhecidos. Uma enxurrada de tokens forjados (cada um com cota própria no `mcpLimiter`) esgota só esse teto, e os clientes já conectados continuam sendo atendidos.
- Não há limitador por IP no `/mcp`, e isso é intencional. Os chamadores legítimos (ChatGPT e Claude) compartilham os IPs de saída da OpenAI e da Anthropic. Além disso, não há IP de cliente confiável nessa rota. Medição em produção (2026-09-15): pelo rewrite do Hosting chega `X-Forwarded-For: <cliente>, <borda do Hosting>`. Com `TRUST_PROXY_HOPS = 1`, o `req.ip` vira um IP de borda do Google que muda a cada requisição. Confiar em 2 hops só no `/mcp` não resolve, porque a URL direta da function também atende `/mcp` e ali essa posição do `X-Forwarded-For` é controlada pelo cliente. Ver `src/utils/trust-proxy.utils.ts`.
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
| `upload_order_photo` | Anexa uma foto à OS informada. Suporta arquivos do ChatGPT via `_meta.openai/fileParams` (`file.download_url`), URL direta (`fileUrl`) ou Base64 (`photoBase64`), com descrição e nome opcionais. |
| `delete_order_photo` | Exclui uma foto da OS pelo `photoId` (`destructiveHint: true`). |

### Limites de listagem

Toda tool de listagem usa `DEFAULT_LIMIT = 20` e `MAX_LIMIT = 50` (`tools/read.ts`): sem `limit` explícito, retorna até 20; qualquer valor pedido acima de 50 é reduzido para 50.

### Card MCP Apps e degradação

- Recurso `ui://praticos/order-card`, mime `text/html;profile=mcp-app` (exigido pela spec MCP Apps `ext-apps 2026-01-26`).
- A ligação tool → card é feita por `_meta.ui.resourceUri` (padrão MCP Apps, funciona em ChatGPT e Claude) e pelo alias `_meta['openai/outputTemplate']` (compatibilidade com runtimes mais antigos do ChatGPT).
- `ui.visibility` é deliberadamente omitido: o padrão (`["model", "app"]`) mantém a tool chamável tanto pelo modelo quanto pelo card.
- O card conversa com o host via `postMessage` (JSON-RPC, spec `ext-apps 2026-01-26`), implementado em `widgets/src/bridge.ts`.
- Handshake: o `ui/initialize` do card envia `appInfo`, `appCapabilities` e `protocolVersion` (`buildInitializeParams()` em `widgets/src/bridge-protocol.ts`). O campo é `appInfo`, **não** `clientInfo`: os exemplos com `clientInfo` no texto da spec são do `initialize` comum do MCP. O ChatGPT valida o `ui/initialize` com o schema do SDK `@modelcontextprotocol/ext-apps`, que exige os três campos; sem `appInfo` o host responde com erro, o resultado da tool nunca chega e o card aparece como um quadro vazio.
- Botões do card: **Aprovar**, **Concluir** (ambos passam por um estado de confirmação dentro do próprio card antes de disparar a escrita) e **Abrir no PraticOS** e **Compartilhar**. Os botões de status só aparecem quando o status atual da OS permite a ação (`availableActions` em `card-state.ts`); uma falha de rede deixa a OS como estava, sem assumir nada sobre o estado do servidor.
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
- Datas ausentes no documento do token chegam como `null` (nunca string vazia): o `fromJson` gerado no Flutter só trata `null`.

### Último uso (`lastUsedAt`)

`mcpAuth` grava `lastUsedAt` no documento de `apiKeys` depois de uma autenticação bem-sucedida, para o dono saber qual conexão está ativa antes de revogar.

- **Fire-and-forget**: a escrita não é aguardada; a resposta não espera o Firestore.
- **Throttle de uma escrita por hora por token** (`LAST_USED_WRITE_INTERVAL_MS`): não grava se o `lastUsedAt` já salvo tem menos de uma hora (vale entre instâncias) nem se a própria instância já gravou naquela hora (segura rajadas antes da primeira escrita chegar ao Firestore). A data exibida tem, portanto, precisão de uma hora.
- **Falha não derruba a autenticação**: erro na escrita (síncrono ou assíncrono) só é logado, sem o token.
- Erros do backend chegam por `code` (`FORBIDDEN`, `NOT_FOUND`), nunca pela mensagem de diagnóstico em inglês do backend.

## Segurança - limites conhecidos da fase 1

O token viaja na própria URL, porque nem o ChatGPT nem o claude.ai permitem cabeçalho customizado num connector (comentário de `mcpAuth`). A aplicação redige o token dos próprios logs, mas os logs de plataforma do Cloud Run e do Firebase Hosting registram a URL completa, e nenhum código de aplicação consegue mudar isso. A Fase 2 substitui o token na URL por OAuth ("Conectar com PraticOS"), eliminando esse ponto.

### Token nos logs de plataforma

**Situação verificada em 2026-09-15 (projeto `praticos`):**

- A function `api` é gen2, então roda como serviço Cloud Run `api`. O log `run.googleapis.com/requests` grava `httpRequest.requestUrl` com o caminho completo, token incluso. O filtro `httpRequest.requestUrl:"/mcp/t/"` já encontra entradas reais.
- A integração do Firebase Hosting com o Cloud Logging **não** está ligada (não existe log `firebasehosting.googleapis.com/webrequests`). Se for ligada, o filtro abaixo cobre esse log também, porque ele usa o mesmo campo `httpRequest.requestUrl`.
- O sink `_Default` não tem exclusões, e o bucket `_Default` retém logs por 30 dias.
- Os logs da própria aplicação (stdout) já saem com o token redigido (`redactSensitivePath` em `utils/log-redaction.utils.ts`) e, em produção, sem query, corpo da requisição nem da resposta (`isPayloadLoggingEnabled`). Ainda assim registram rota, headers mascarados, status e duração, então a observabilidade das chamadas MCP não depende do log de requisição da plataforma.

**Opções avaliadas:**

| Opção | Efeito | Decisão |
|---|---|---|
| Exclusão no sink `_Default` | Entradas com `/mcp/t/` deixam de ser armazenadas. Não custa nada e não depende de quem tem acesso ao projeto. | **Recomendada** |
| Restringir acesso ao Logs Viewer | O token continua armazenado; qualquer papel `roles/logging.viewer`, `roles/viewer`, `roles/editor` ou `roles/owner` ainda lê o log de requisição. `roles/logging.privateLogViewer` não protege esse log, porque ele não é um log de acesso a dados. | Só como complemento |
| Bucket dedicado com acesso restrito | Mantém as entradas para diagnóstico, mas exige sink e bucket novos, além de IAM por view. Mais infraestrutura para um problema que some na fase 2. | Não adotada |

**Status:** exclusão `mcp-token-urls` aplicada e verificada no sink `_Default` do projeto `praticos` em 2026-09-16. A métrica opcional do passo 1 não foi criada.

**O filtro precisa ser regex.** A primeira tentativa usou o operador de substring, `httpRequest.requestUrl:"/mcp/t/"`. Esse filtro encontra as entradas numa leitura, mas como exclusão não surtiu efeito: requisições de teste feitas 42 s, 3,5 min e 8,7 min depois continuaram sendo gravadas. Com `httpRequest.requestUrl=~"/mcp/t/"`, restrito a `LOG_ID("run.googleapis.com/requests")`, a exclusão passou a valer. Não dá para separar com certeza o efeito do regex do de uma propagação mais demorada, mas o comando abaixo é o que está em produção e verificado.

**Passo a passo (aplicar manualmente, fora do repositório):**

1. (Opcional) Se quiser contar as requisições MCP pela plataforma depois da exclusão, crie uma métrica baseada em logs **antes** do passo 2. Exclusões não afetam métricas definidas pelo usuário, que continuam contando as entradas excluídas ([Google Cloud: Control Dataflow log ingestion](https://docs.cloud.google.com/dataflow/docs/guides/filter-logs)):

   ```bash
   gcloud logging metrics create mcp_platform_requests \
     --project=praticos \
     --description="Requisicoes em /mcp/t/ (entradas excluidas do _Default)" \
     --log-filter='LOG_ID("run.googleapis.com/requests") AND httpRequest.requestUrl=~"/mcp/t/"'
   ```

2. Adicione a exclusão ao sink `_Default`:

   ```bash
   gcloud logging sinks update _Default \
     --project=praticos \
     --add-exclusion='name=mcp-token-urls,filter=LOG_ID("run.googleapis.com/requests") AND httpRequest.requestUrl=~"/mcp/t/"'
   ```

   Pelo console: **Logging → Log Router → `_Default` → Editar sink → Escolher registros para filtrar do sink → Adicionar exclusão**, com nome `mcp-token-urls` e o filtro `LOG_ID("run.googleapis.com/requests") AND httpRequest.requestUrl=~"/mcp/t/"`.

3. Confira que a exclusão foi gravada:

   ```bash
   gcloud logging sinks describe _Default --project=praticos --format='yaml(exclusions)'
   ```

4. Confira com dois pedidos na URL direta do serviço Cloud Run, um em `/mcp/t/` e outro fora dele. O segundo é o controle: sem ele, uma leitura vazia também poderia ser falha de leitura. Use um token falso, e o formato imprime só a hora:

   ```bash
   B=https://api-m4d2l34a3a-rj.a.run.app
   curl -s -o /dev/null "$B/mcp/t/token_falso_de_teste"
   curl -s -o /dev/null "$B/controle-sem-mcp"
   sleep 180
   # Esperado: vazio
   gcloud logging read 'httpRequest.requestUrl:"token_falso_de_teste"' \
     --project=praticos --freshness=15m --limit=5 --format='value(timestamp)'
   # Esperado: uma entrada
   gcloud logging read 'httpRequest.requestUrl:"controle-sem-mcp"' \
     --project=praticos --freshness=15m --limit=5 --format='value(timestamp)'
   ```

   Não use um caminho qualquer em `praticos.web.app` como controle: o Hosting responde estático sem chegar ao Cloud Run, e aí o controle não aparece no log de jeito nenhum. Dê margem de propagação: mudanças no sink levam alguns minutos para valer.

5. **Entradas já gravadas não são apagadas pela exclusão.** Elas somem quando vencem os 30 dias de retenção do bucket `_Default`. Para fechar essa janela antes, revogue e recrie as conexões em Ajustes → Integrações. Não use `gcloud logging logs delete run.googleapis.com/requests`: esse comando apaga o log de requisição de **todos** os serviços Cloud Run do projeto, incluindo `praticos-web`.

6. Qualquer sink novo que exporte logs de requisição (BigQuery, Cloud Storage, Pub/Sub) precisa da mesma exclusão.

7. Quando o OAuth da fase 2 substituir o token na URL, remova a exclusão: `gcloud logging sinks update _Default --project=praticos --remove-exclusions=mcp-token-urls`.

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

### Card redesenhado e compartilhamento

As capas aceitam os domínios `storage.googleapis.com` e `firebasestorage.googleapis.com` no CSP do resource, incluindo URLs geradas pelo SDK Firebase. A permissão `web-share` do iframe é controlada pelo host, não pelo card.

O card usa `widgets/DESIGN.md`, estilos em `src/card.css`, ícones SVG e textos PT/EN/ES em `src/card-locale.ts`. O idioma vem de `hostContext.locale`, do navegador ou do fallback PT; a moeda continua BRL conforme o contrato atual da OS. O FormatService Flutter não está disponível no widget React, que usa Intl centralizado. Foto de capa quadrada ao lado da identificação, status suave, grupos de serviços/produtos e faixa de total compõem o layout. Imagem ausente ou com erro libera o espaço para os dados.

Compartilhar usa Web Share API (`navigator.share`) com título, resumo e `shareUrl`. A pessoa escolhe o aplicativo e destinatário. Se a API não existir ou for bloqueada no iframe, o card oferece WhatsApp, Telegram e cópia de link; cada destino só abre após escolha explícita via `ui/open-link`. O bloqueio do menu nativo não exibe erro. O link manual só aparece se a cópia ou abertura da OS falhar. Cancelamento não é erro. Abrir no PraticOS usa `ui/open-link` para abrir a página web pública da OS; não é um deep link nativo. Recusa/erro/timeout exibe alternativa de cópia. Não adiciona dados ao allowlist nem altera Firestore, permissões ou isolamento por empresa.

O build do widget agora embute JS **e CSS** em `bundle.ts`. Sempre rodar `npm run build` em `firebase/functions/widgets` antes do build/deploy das Functions. A documentação pública é gerada por Eleventy a partir de `firebase/hosting/src/_data/docs/integracoes.json` nos três idiomas, não editada no diretório de saída `public`.

Referência do protocolo: https://github.com/modelcontextprotocol/ext-apps/blob/main/specification/2026-01-26/apps.mdx (Open External Links).
