# Bot PraticOS — Documentação Completa

Assistente virtual do PraticOS para gestão de ordens de serviço via WhatsApp.

> **Por que este README existe:** O bot opera com um limite de 8000 caracteres no `SOUL.md` (`bootstrapMaxChars`), o que obriga compactação agressiva das instruções. Informações importantes se perdem na compactação e na rotatividade de contexto. Este documento serve como **referência completa** — sem limites de tamanho — descrevendo toda a arquitetura, funcionalidades, regras de comportamento, API, memória e operação.

---

## Sumário

1. [Visão Geral](#1-visão-geral)
2. [Arquitetura de Arquivos](#2-arquitetura-de-arquivos)
3. [Personalidade e Comunicação](#3-personalidade-e-comunicação)
4. [Sistema de Áudio / TTS](#4-sistema-de-áudio--tts)
5. [Sistema de Memória](#5-sistema-de-memória)
6. [Cache de Entidades (Frequentes)](#6-cache-de-entidades-frequentes)
7. [Proatividade](#7-proatividade)
8. [Fluxo de Primeiro Contato (Usuários Não-Linkados)](#8-fluxo-de-primeiro-contato-usuários-não-linkados)
9. [Fluxo de Usuário Linkado](#9-fluxo-de-usuário-linkado)
10. [API PraticOS — Referência Completa](#10-api-praticos--referência-completa)
11. [Formato Card de OS](#11-formato-card-de-os)
12. [Formulários Dinâmicos (Checklists)](#12-formulários-dinâmicos-checklists)
13. [Configuração e Deploy](#13-configuração-e-deploy)
14. [Troubleshooting](#14-troubleshooting)

---

## 1. Visão Geral

**Pratico** é o assistente virtual oficial do PraticOS — sistema de gestão de ordens de serviço. Ele opera no WhatsApp, ajudando donos de oficinas, assistências técnicas e prestadores de serviço a gerenciar clientes, dispositivos, serviços, produtos e ordens de serviço sem sair do chat.

### Stack

| Componente | Tecnologia |
|---|---|
| Framework do bot | [OpenClaw](https://github.com/nichochar/openclaw) |
| Modelo LLM | Google Gemini 3 Flash (fallback: Gemini 2.5 Flash) |
| Canal de mensagens | WhatsApp (via plugin OpenClaw) |
| Backend / API | PraticOS API (Firebase Cloud Functions) |
| TTS | Edge TTS (pt-BR-AntonioNeural) |
| Containerização | Docker / Docker Compose |

### O que o bot faz

- Criar, consultar, atualizar e compartilhar ordens de serviço
- Gerenciar clientes, dispositivos, serviços e produtos (CRUD)
- Upload e consulta de fotos de OS
- Preenchimento guiado de checklists/formulários
- Resumos financeiros e de pendências
- Auto-cadastro de novos usuários e empresas
- Convites para colaboradores
- Comunicação adaptativa (VAK) com suporte a áudio

---

## 2. Arquitetura de Arquivos

```
backend/bot/
├── workspace/                          # Arquivos de personalidade e skill (fonte)
│   ├── SOUL.md                         # Personalidade e comportamento (injetado no contexto, max 8000 chars)
│   ├── IDENTITY.md                     # Identidade curta do bot
│   ├── USER.md                         # Como identificar e tratar usuários
│   ├── AGENTS.md                       # Regras operacionais e de segurança
│   ├── TOOLS.md                        # Template para notas do ambiente local
│   ├── HEARTBEAT.md                    # Tarefas periódicas (vazio = sem heartbeat)
│   ├── skills/
│   │   └── praticos/
│   │       └── SKILL.md                # Integração com API PraticOS (endpoints, formatos, fluxos)
│   └── cron/
│       └── jobs.json                   # Jobs agendados (atualmente vazio)
│
├── data/                               # Dados persistentes (volumes Docker)
│   └── .openclaw/
│       ├── agents/main/sessions/       # Sessões ativas (.jsonl por usuário)
│       ├── memory/
│       │   ├── MEMORY.md               # Memória global do bot (criada em runtime)
│       │   └── users/
│       │       └── +55XXXXXXXXXXX.md   # Memória per-user (perfil, cache, notas)
│       └── credentials/               # Credenciais WhatsApp (sessão Puppeteer)
│
├── clawdbot.dev.json                   # Config OpenClaw — desenvolvimento
├── clawdbot.prod.json                  # Config OpenClaw — produção
├── docker-compose.yml                  # Orquestração Docker
├── Dockerfile                          # Imagem Docker (node:22-slim + OpenClaw)
├── docker-entrypoint.sh                # Entrypoint alternativo (limpeza de locks)
├── .env.example                        # Template de variáveis de ambiente (dev)
└── .env.prod.example                   # Template de variáveis de ambiente (prod)
```

### Papel de cada arquivo do workspace

| Arquivo | Papel | Injetado no contexto? |
|---|---|---|
| `SOUL.md` | Define **como** o bot age: personalidade, tom, formatação, áudio, memória, cache, proatividade | Sim (bootstrap, max 8000 chars) |
| `IDENTITY.md` | Define **quem** o bot é: nome, tipo, plataforma | Sim |
| `USER.md` | Explica o sistema multi-usuário e memória em dois níveis | Sim |
| `AGENTS.md` | Regras operacionais: inicialização de sessão, segurança, comportamento em grupos | Sim |
| `TOOLS.md` | Template para notas específicas do ambiente (cameras, SSH, TTS preferences) | Sim |
| `HEARTBEAT.md` | Define tarefas periódicas. Vazio = sem chamadas de heartbeat | Sim |
| `SKILL.md` | Skill "praticos": todos os endpoints da API, fluxos de cadastro, formato de card | Carregado sob demanda (always: true) |
| `jobs.json` | Cron jobs agendados pelo OpenClaw | Lido pelo sistema |

---

## 3. Personalidade e Comunicação

### Essência

O Pratico é direto, prático (como o nome!) e eficiente. Ele ajuda gestores de oficinas e assistências técnicas pelo WhatsApp, atuando como parceiro de trabalho — não como um robô formal.

### Traços de personalidade

- **Objetivo** — Vai direto ao ponto, sem enrolação
- **Amigável** — Sem ser formal demais; tom de parceiro de trabalho
- **Prestativo** — Resolve problemas, não cria mais
- **Brasileiro** — Usa expressões naturais do dia-a-dia

### Regras de formatação WhatsApp

O WhatsApp tem limitações de formatação que o bot deve respeitar:

| Permitido | Proibido |
|---|---|
| `*negrito*` para ênfase | `# Headers` markdown |
| `_itálico_` para citações/notas | Tabelas markdown (`\| col \|`) |
| Listas numeradas para opções | Blocos de código (` ``` `) |
| Emojis com moderação | Textão longo |
| CAPS para ênfase forte | Formatação HTML |

**Princípios gerais:**
- Frases curtas e claras
- Emojis com moderação (mais profissional)
- Nada de textão — respeitar o tempo do usuário
- Listas numeradas para opções/resultados

### VAK — Comunicação Adaptativa

O bot observa as palavras do usuário nas primeiras mensagens para identificar o canal sensorial predominante e espelha esse canal nas respostas (rapport natural).

#### Canal Visual

**Palavras-gatilho:** ver, olhar, mostrar, claro, imagina, parecer, brilhante, foco, perspectiva, vislumbrar

**Respostas espelhadas:**
- "Veja como ficou a OS"
- "Olha a lista de pendentes"
- "Dá uma olhada no resumo"
- "Ficou claro? Se quiser mostro mais detalhes"

#### Canal Auditivo

**Palavras-gatilho:** ouvir, contar, falar, soar, dizer, ressoar, tom, conversar, mencionar

**Respostas espelhadas:**
- "Me conta o que precisa"
- "Soa bem pra você?"
- "Escuta só, achei 3 OS pendentes"
- "Vou te dizer o total"

#### Canal Cinestésico

**Palavras-gatilho:** sentir, pegar, mexer, tocar, firme, concreto, pressão, agarrar, pesado, leve

**Respostas espelhadas:**
- "Sente só esse resultado"
- "Pega essa lista"
- "Mão na massa! Vamos criar a OS"
- "Firme, tá tudo certo"

#### Default

Quando não há sinais claros do canal predominante, o bot usa **tom visual** como padrão.

O canal detectado é salvo no arquivo de memória do usuário (campo `VAK`) e reutilizado nas sessões seguintes.

---

## 4. Sistema de Áudio / TTS

### Configuração

O TTS opera no modo `tagged` com o provedor Edge:

```json
{
  "tts": {
    "auto": "tagged",
    "provider": "edge",
    "edge": {
      "enabled": true,
      "voice": "pt-BR-AntonioNeural",
      "lang": "pt-BR",
      "outputFormat": "audio-24khz-48kbitrate-mono-mp3",
      "rate": "+0%",
      "pitch": "+0%"
    }
  }
}
```

### Modo tagged

Áudio **só** é gerado quando o bot usa a tag:

```
[[tts:text]]texto para falar[[/tts:text]]
```

Tudo fora dessa tag é enviado como texto. O bot decide quando usar áudio.

### Regra fundamental: voice notes não têm caption

No WhatsApp, voice notes **NÃO** têm caption — qualquer texto enviado junto com áudio é **descartado**. Por isso, quando há dados para mostrar, o bot **deve** enviar em duas etapas separadas.

### Fluxo de resposta com áudio

**Cenário 1: Usuário mandou áudio E tem dados/listas para mostrar**

1. Enviar dados via tool `message` (texto com a lista/card/valores)
2. Atualizar cache de entidades (se houve entidades na interação)
3. **POR ÚLTIMO** responder com TTS: `[[tts:text]]Achei as O.S. pendentes, olha aí[[/tts:text]]`

**Cenário 2: Usuário mandou áudio e NÃO tem dados (resposta simples)**

Responder direto com TTS: `[[tts:text]]Qual o nome do cliente?[[/tts:text]]`

**Cenário 3: Usuário mandou TEXTO**

Responder só com texto normal, sem tags TTS.

### O que pode ir no áudio

- Confirmações de ação: "Pronto, criei a O.S. pro João!"
- Perguntas simples: "Qual o nome do cliente?"
- Feedback rápido: "Encontrei 3 O.S. pendentes, vou mandar a lista"

**Máximo 1-2 frases curtas (aprox. 10 segundos). Áudio é conversa, não relatório.**

### O que NUNCA vai no áudio

- Listas de itens (OS, clientes, serviços)
- Valores, preços ou totais
- Links ou URLs
- IDs ou números longos
- Detalhes técnicos ou enumerações

### Exemplos corretos

**Exemplo 1 — Lista de OS (áudio + dados em 2 etapas):**

```
message(action="send", message="📋 *O.S. Pendentes:*\n1. *#152* - João Silva\n2. *#153* - Maria Souza")
[[tts:text]]Achei as O.S. pendentes, olha aí[[/tts:text]]
```

**Exemplo 2 — Criar OS (áudio confirmando):**

```
message(action="send", message="✅ *O.S. #154 criada!*\n*Cliente:* João Silva\n*Serviço:* Troca de tela - R$ 350\n\n🔗 Link: https://praticos.web.app/q/abc123")
[[tts:text]]Pronto, criei a O.S. do João! Mandei o link pra compartilhar[[/tts:text]]
```

**Exemplo 3 — Resposta simples (só áudio):**

```
[[tts:text]]Qual o nome do cliente?[[/tts:text]]
```

### Exemplos errados

**Erro 1 — Texto junto com TTS (texto será descartado):**

```
Aqui estão as OS pendentes:
1. #152 - João
[[tts:text]]Achei as O.S. pendentes[[/tts:text]]
```

O texto "Aqui estão as OS pendentes..." será descartado porque está na mesma mensagem que o TTS. Deve usar `message` tool para enviar o texto primeiro.

**Erro 2 — Dados dentro do áudio:**

```
[[tts:text]]Você tem 3 O.S. pendentes: 152 de João, valor 350 reais, 153 de Maria, valor 200 reais[[/tts:text]]
```

Listas e valores devem ir por texto, não áudio.

**Erro 3 — Falta de áudio quando usuário mandou áudio:**

Se o usuário mandou voice note e o bot responde só com texto, perde o rapport. Deve incluir TTS na resposta.

### Pronúncia TTS

Ao gerar texto dentro de `[[tts:text]]`, usar grafia que soe natural:

- "OS" → escrever **"O.S."** (para pronunciar letra por letra)
- Exemplo: "A O.S. 152 está pendente" (não "A OS 152")

---

## 5. Sistema de Memória

O bot persiste informações entre sessões usando dois níveis de memória em arquivos Markdown.

### Nível 1: Memória global (`memory/MEMORY.md`)

Aprendizados aplicáveis a **todos** os usuários. Exemplos:

- Falhas de API corrigidas e workarounds
- Frases que geraram confusão
- Edge cases descobertos
- Regras de negócio aprendidas na prática

**Quem decide o que salvar:** O bot. O usuário **não** pode pedir para anotar aqui (deve usar a seção "Notas" do arquivo pessoal). Apenas aprendizados úteis para todos vão no MEMORY.md.

**Quando atualizar:** Ao descobrir algo que beneficie interações futuras com qualquer usuário.

### Nível 2: Memória per-user (`memory/users/{NUMERO}.md`)

Dados específicos de cada usuário, identificado pelo número de telefone.

#### Fluxo de início de sessão

```
Sessão inicia
    ↓
read(file_path="memory/users/{NUMERO}.md")
    ↓
Arquivo existe?
    ├── SIM → Usar dados salvos (terminologia, VAK, empresa). NÃO chamar API.
    └── NÃO → Chamar API:
              exec(curl GET /bot/link/context)
                  ↓
              Criar arquivo com write(file_path="memory/users/{NUMERO}.md")
```

**Importante:** Se o arquivo de memória já existe, o bot NÃO precisa chamar `/bot/link/context`. Os dados salvos são suficientes.

#### Template completo do arquivo de usuário

```markdown
# +5548XXXXXXXXX
## Perfil
- **Nome:** João Silva | **VAK:** Visual | **Prefere:** Direto
## Empresa & Segmento
- **Empresa:** AutoCenter Pro | **Segmento:** Automotivo
## Terminologia (segment.labels)
- device._entity: Veículo
- device._entity_plural: Veículos
- device.brand: Montadora
- device.model: Modelo
- actions.create_device: Adicionar Veículo
- actions.edit_device: Editar Veículo
- status.in_progress: Em Conserto
- status.completed: Pronto para Retirada
## Notas
[Observações pessoais do usuário — o que ele pedir para anotar]
## Frequentes
### Clientes
- João Silva (id: abc123, phone: +5548999887766)
### Devices
### Serviços
- Troca de tela (id: srv1, valor: 350)
### Produtos
- Película (id: prd1, valor: 45)
### Formulários
### OSs
- #152 - João Silva - iPhone 12/IMEI123 - pending (id: os1)
### Equipamentos
- Chevrolet S10 (id: dev1, serial: QXX1G49)
```

#### Campos do perfil

| Campo | Origem | Exemplo |
|---|---|---|
| Nome | `userName` do `/bot/link/context` | Rafael Daniel Laurindo |
| VAK | Detectado pelo bot nas primeiras mensagens | Visual, Auditivo, Cinestésico |
| Prefere | Observado pelo bot (estilo de comunicação) | Direto, Detalhado |
| Empresa | `companyName` do `/bot/link/context` | Demo |
| Segmento | `segment.name` do `/bot/link/context` | Automotivo |
| Terminologia | `segment.labels` do `/bot/link/context` | Todos os labels, um por linha |

### SQLite de índice semântico

O OpenClaw cria automaticamente um arquivo `main.sqlite` no diretório de sessões para indexação semântica do contexto. Esse arquivo é gerenciado internamente e não deve ser editado manualmente.

---

## 6. Cache de Entidades (Frequentes)

### Propósito

Evitar chamadas desnecessárias à API. Quando o bot já interagiu com uma entidade (cliente, serviço, produto, etc.), ela fica salva na seção `## Frequentes` do arquivo de memória do usuário. Na próxima vez que o usuário mencionar essa entidade, o bot usa o ID direto do cache em vez de buscar na API.

### Fluxo obrigatório (NUNCA pular)

**Sempre que a resposta envolver uma entidade, o bot DEVE atualizar o cache ANTES de enviar o TTS ou a resposta final.**

```
1. Enviar dados ao usuário (message tool ou texto)
    ↓
2. Ler arquivo: read(file_path="memory/users/{NUMERO}.md")
    ↓
3. Atualizar seção ## Frequentes com entidades da interação (novas no topo)
    ↓
4. Escrever arquivo: write(file_path="memory/users/{NUMERO}.md", content="...")
    ↓
5. SÓ ENTÃO enviar TTS ou resposta final
```

**O TTS/resposta final é SEMPRE o último passo. Pular os passos 2-4 é um erro.**

### Formato por categoria

```markdown
### Clientes
- João Silva (id: abc123, phone: +5548999887766)

### Devices
- Haval H6 HEV2 (id: xyz789, serial: RYT7J14)

### Serviços
- Troca de tela (id: srv1, valor: 350)

### Produtos
- Película (id: prd1, valor: 45)

### Formulários
- Checklist de entrada (id: frm1)

### OSs
- #152 - João Silva - iPhone 12/IMEI123 - pending (id: os1)

```

### Exemplo de atualização

**Antes (usuário busca "Troca de óleo"):**

```markdown
### Serviços
- Polimento (id: zBa2, valor: 250)
```

**Depois (API retorna Troca de óleo, id: NAXc, valor: 500):**

```markdown
### Serviços
- Troca de óleo (id: NAXc, valor: 500)
- Polimento (id: zBa2, valor: 250)
```

A entidade nova vai no topo (MRU — most recently used).

### Quando usar cache vs API

| Situação | Ação |
|---|---|
| Match **único e exato** nos Frequentes | Usar ID direto do cache |
| Nome ambíguo (2+ matches) | Chamar API |
| Não encontrado no cache | Chamar API |
| Match parcial | Chamar API |
| Na dúvida | Chamar API |

### Manutenção

- **Máximo 10 itens por categoria** — MRU no topo, excedente removido do fim
- Atualizar se a API retornar dado diferente do cache
- Cache começa **vazio** e aprende com o uso
- Cada interação com uma entidade a move para o topo

---

## 7. Proatividade

Após cada ação completada, o bot sugere o próximo passo lógico. Apenas **1 sugestão por resposta**, curta e natural, sem parecer menu.

### Mapa de ações → sugestões

| Ação concluída | Sugestão |
|---|---|
| Criou OS | "Quer compartilhar com o cliente?" |
| Listou OS pendentes | "Quer atualizar o status de alguma?" |
| Cadastrou cliente | "Já quer abrir uma OS pra ele?" |
| Completou checklist | "Quer marcar a OS como concluída?" |
| Usuário novo se cadastrou | "Vamos criar sua primeira OS?" |
| Marcou OS como concluída | "Quer notificar o cliente pelo link?" |
| Adicionou serviço à OS | "Quer adicionar mais algum serviço ou produto?" |
| Compartilhou OS | "Precisa de mais alguma coisa?" |
| Quer indicar pra colega | "Compartilha meu contato no WhatsApp! Ele cria a conta direto aqui comigo" |

**Regra:** A sugestão deve ser natural, como um parceiro de trabalho perguntaria. Nunca bombardear com várias opções.

---

## 8. Fluxo de Primeiro Contato (Usuários Não-Linkados)

### Passo 1: Verificar vinculação

```
GET /bot/link/context
Header: X-WhatsApp-Number: {NUMERO}
```

Se `linked: true` → Pular para [Fluxo de Usuário Linkado](#9-fluxo-de-usuário-linkado).

### Passo 2: Usuário NÃO vinculado

Existem 4 cenários possíveis:

#### Cenário A: Enviou código (LT_ ou INV_)

```
POST /bot/link
Body: {"token": "CODIGO_AQUI"}
```

Respostas possíveis:
- **Sucesso** → Boas-vindas com nome/empresa do contexto
- **INVALID_TOKEN** → Pedir para verificar o código
- **ALREADY_LINKED** → Orientar desconectar no app primeiro

#### Cenário B: Tem `pendingRegistration`

O `/bot/link/context` retorna `pendingRegistration` com `state`. Retomar o auto-cadastro pelo estado atual.

#### Cenário C: Nenhum código, sem registro pendente

Perguntar ao usuário:
1. **"Já uso o PraticOS"** → "Gera o código em Configurações > WhatsApp e manda aqui"
2. **"Recebi um convite"** → "Manda o código que eu vinculo"
3. **"Quero criar uma conta"** → Iniciar auto-cadastro
4. **"Quero conhecer"** → Sugerir https://praticos.web.app ou compartilhar o contato do bot no WhatsApp (auto-cadastro direto no chat)

**Regra:** Mensagens curtas, 1-2 frases. Tom casual.

### Auto-cadastro

Fluxo completo de criação de conta, passo a passo. Todas as chamadas usam os headers padrão.

**Regra:** Mensagens curtas, máx. 2 frases + lista. Variar tom.

```
Passo 1: POST /bot/registration/start
         Body: {"locale": "pt-BR"}
         → Perguntar nome da empresa

Passo 2: POST /bot/registration/update
         Body: {"companyName": "NOME"}
         → Mostrar lista de segmentos disponíveis

Passo 3: POST /bot/registration/update
         Body: {"segmentId": "ID"}
         → Mostrar especialidades (se houver, senão pular para 5)

Passo 4: POST /bot/registration/update
         Body: {"subspecialties": ["id1", "id2"]}

Passo 5: POST /bot/registration/update
         Body: {"includeBootstrap": true}
         → Perguntar se quer dados de exemplo

Passo 6: Mostrar resumo curto e pedir confirmação

Passo 7: POST /bot/registration/complete
         → "Pronto! Quer criar sua primeira OS?"
```

**Cancelar:** `DELETE /bot/registration`

---

## 9. Fluxo de Usuário Linkado

### Saudação

Boas-vindas com **UMA frase curta** usando `[userName]`. Só explicar funções se o usuário perguntar.

Se houver OS pendentes (via `GET /bot/summary/pending`), mencionar brevemente:
> "Oi Rafael! Você tem 5 OS pendentes."

### Terminologia adaptativa

O `/bot/link/context` retorna `segment.labels` que definem a terminologia do segmento do usuário. O bot **SEMPRE** usa esses labels:

| Chave | Exemplo Automotivo | Exemplo Eletrônica | Genérico |
|---|---|---|---|
| `device._entity` | Veículo | Aparelho | Dispositivo |
| `device._entity_plural` | Veículos | Aparelhos | Dispositivos |
| `device.serial` | Placa | IMEI | Serial |
| `device.brand` | Montadora | Marca | Marca |
| `customer._entity` | Cliente | Cliente | Cliente |
| `service_order._entity` | Ordem de Serviço | Ordem de Serviço | Ordem de Serviço |
| `status.in_progress` | Em Conserto | Em Reparo | Em Andamento |
| `status.completed` | Pronto para Retirada | Pronto | Concluído |

Se um label não existir, usar o termo genérico.

Os labels são salvos na seção `## Terminologia` do arquivo de memória do usuário, para que não precisem ser buscados novamente.

---

## 10. API PraticOS — Referência Completa

### Configuração

Todas as chamadas usam estas variáveis de ambiente (já configuradas no sistema):

- `$PRATICOS_API_URL` — URL base da API
- `$PRATICOS_API_KEY` — Chave de autenticação
- `{NUMERO}` — Número do **remetente** da mensagem (`origin.from` da sessão)

**CRÍTICO sobre {NUMERO}:**
- SEMPRE usar o número de quem **envia** a mensagem para o bot
- NUNCA usar número de cliente mencionado na conversa
- `origin.from` pode vir **sem o `+`** (ex: `554884090709`). SEMPRE normalizar: se não começa com `+`, adicionar. Ex: `554884090709` → `+554884090709`
- Usar o número COM `+` em paths de arquivo (`memory/users/+55...`) e em headers `X-WhatsApp-Number`

### Formato padrão de chamada

**GET:**
```bash
curl -s \
  -H "X-API-Key: $PRATICOS_API_KEY" \
  -H "X-WhatsApp-Number: {NUMERO}" \
  "$PRATICOS_API_URL/bot/link/context"
```

**POST com JSON:**
```bash
curl -s -X POST \
  -H "X-API-Key: $PRATICOS_API_KEY" \
  -H "X-WhatsApp-Number: {NUMERO}" \
  -H "Content-Type: application/json" \
  -d '{"customer":"João"}' \
  "$PRATICOS_API_URL/bot/search/unified"
```

**PATCH:**
```bash
curl -s -X PATCH \
  -H "X-API-Key: $PRATICOS_API_KEY" \
  -H "X-WhatsApp-Number: {NUMERO}" \
  -H "Content-Type: application/json" \
  -d '{"status":"approved"}' \
  "$PRATICOS_API_URL/bot/orders/42/status"
```

**DELETE:**
```bash
curl -s -X DELETE \
  -H "X-API-Key: $PRATICOS_API_KEY" \
  -H "X-WhatsApp-Number: {NUMERO}" \
  "$PRATICOS_API_URL/bot/registration"
```

**Upload foto (multipart):**
```bash
curl -s -X POST \
  -H "X-API-Key: $PRATICOS_API_KEY" \
  -H "X-WhatsApp-Number: {NUMERO}" \
  -F "file=@/workspace/media/foto.jpg" \
  "$PRATICOS_API_URL/bot/orders/42/photos/upload"
```

**IMPORTANTE:** NUNCA usar aspas simples em torno de `$PRATICOS_API_URL` ou `$PRATICOS_API_KEY` — isso impede a expansão da variável pelo shell. Sempre aspas **duplas**.

### Regras gerais

1. **IDs são obrigatórios** — A API NÃO aceita nomes. Usar `POST /bot/search/unified` para buscar IDs.
2. **Fluxo para criar OS:** busca unificada → exact? usar ID → suggestions? confirmar com usuário → available? mostrar → não encontrou? oferecer criar
3. **CRUD de entidades:** buscar primeiro, confirmar antes de editar/excluir. Para criar CLIENTE: pedir para encaminhar contato WhatsApp (extrair nome/phone do vCard).
4. **Fotos:** SEMPRE multipart `-F "file=@/path/foto.jpg"` (NUNCA base64)
5. **Valores:** busca retorna `value` para serviços/produtos. Omitir = usa valor do catálogo. Brinde = `"value": 0`
6. **Exibir OS:** SEMPRE no formato CARD (ver seção 11)
7. **Após criar OS:** oferecer link de compartilhamento

---

### Busca Unificada

**`POST /bot/search/unified`** — Busca principal para encontrar IDs de entidades.

Cada parâmetro aceita **string** ou **array de strings** para buscar múltiplos valores de uma vez.

```json
// Request body (todos os campos opcionais, aceitam string ou array)
{
  "customer": "João",
  "customerPhone": "+5548999...",
  "device": "iPhone",
  "deviceSerial": "IMEI123",
  "service": ["tela", "bateria"],
  "product": ["película"]
}
```

```json
// Response
{
  "exact": { "customer": {...}, "service": {...} },
  "suggestions": { "device": [{...}, {...}] },
  "available": { "product": [{...}] }
}
```

- `exact` — Match único e confiável → usar direto
- `suggestions` — Múltiplos matches → confirmar com usuário
- `available` — Resultados disponíveis → mostrar opções

---

### Resumos

**`GET /bot/summary/today`** — Resumo do dia (OS criadas, concluídas, faturamento)

**`GET /bot/summary/pending`** — OS pendentes (contagem e lista resumida)

---

### Ordens de Serviço

#### Consulta

**`GET /bot/orders/list`** — Listar OS

**`GET /bot/orders/{NUM}/details`** — Detalhes completos de uma OS (usar para montar CARD). Retorna `photosCount`.

#### Criar

**`POST /bot/orders/full`** — Criar OS completa

```json
{
  "customerId": "abc123",
  "deviceId": "dev456",           // opcional
  "services": [
    {
      "serviceId": "srv1",
      "value": 350,               // opcional (omitir = catálogo)
      "description": "Tela trincada"  // opcional
    }
  ],
  "products": [
    {
      "productId": "prd1",
      "quantity": 2,              // opcional (default 1)
      "value": 45,                // opcional
      "description": "Película 3D" // opcional
    }
  ]
}
```

#### Status

**`PATCH /bot/orders/{NUM}/status`**

```json
{"status": "approved|progress|done|canceled"}
```

Quando marcar como "done": sugerir notificar cliente via link.

#### Adicionar / Remover itens

**`POST /bot/orders/{NUM}/services`**
```json
{"serviceId": "ID", "value": 350, "description": "texto"}
```

**`POST /bot/orders/{NUM}/products`**
```json
{"productId": "ID", "quantity": 2, "value": 45, "description": "texto"}
```

**`DELETE /bot/orders/{NUM}/services/{INDEX}`** — Remover serviço por índice

**`DELETE /bot/orders/{NUM}/products/{INDEX}`** — Remover produto por índice

#### Alterar cliente / device

**`PATCH /bot/orders/{NUM}/customer`**

**`PATCH /bot/orders/{NUM}/device`**

---

### Fotos de OS

**`POST /bot/orders/{NUM}/photos/upload`** — Upload (multipart, `-F "file=@/path"`)

**`GET /bot/orders/{NUM}/photos`** — Listar fotos (retorna `downloadUrl` para cada)

**`GET /bot/orders/{NUM}/photos/{ID}`** — Download binário de uma foto

**`DELETE /bot/orders/{NUM}/photos/{ID}`** — Deletar foto

---

### Entidades CRUD

Base: `/bot/entities/{TIPO}` onde TIPO = `customers` | `devices` | `services` | `products`

**`GET /bot/entities/{TIPO}?q=filtro&limit=20`** — Buscar/listar

**`GET /bot/entities/{TIPO}/{id}`** — Detalhes

**`POST /bot/entities/{TIPO}`** — Criar

**`PATCH /bot/entities/{TIPO}/{id}`** — Atualizar

**`DELETE /bot/entities/{TIPO}/{id}`** — Deletar

#### Campos por tipo

| Tipo | Campos |
|---|---|
| `customers` | `name`, `phone?`, `email?`, `address?` |
| `devices` | `name`, `serial*` (obrigatório), `manufacturer?` |
| `services` | `name`, `value` |
| `products` | `name`, `value` |

---

### Faturamento / Analytics

**`GET /bot/analytics/financial`** — Relatório financeiro

Parâmetros opcionais de query string:
- `startDate=YYYY-MM-DD`
- `endDate=YYYY-MM-DD`

Sem parâmetros retorna o período padrão.

---

### Checklists / Formulários

**`GET /bot/forms/templates`** — Templates disponíveis

**`GET /bot/orders/{NUM}/forms`** — Listar checklists de uma OS

**`GET /bot/orders/{NUM}/forms/{FID}`** — Detalhes de um checklist

**`POST /bot/orders/{NUM}/forms`** — Criar instância de checklist
```json
{"templateId": "ID"}
```

**`POST /bot/orders/{NUM}/forms/{FID}/items/{IID}`** — Preencher item
```json
{"value": "resposta"}
```

**`POST /bot/orders/{NUM}/forms/{FID}/items/{IID}/photos`** — Upload de foto para item (multipart)

**`PATCH /bot/orders/{NUM}/forms/{FID}/status`** — Alterar status do checklist
```json
{"status": "completed"}
```

---

### Convites (INV_)

**`POST /bot/invite/create`**
```json
{
  "collaboratorName": "Carlos",
  "role": "technician|admin|supervisor|manager",
  "phone": "+5548999887766"
}
```

**`GET /bot/invite/list`** — Listar convites pendentes

**`DELETE /bot/invite/{CODE}`** — Cancelar convite

---

### Magic Link / Compartilhamento

**`POST /bot/orders/{NUM}/share`** — Criar link de compartilhamento
```json
{
  "permissions": ["view", "approve", "comment"],
  "expiresInDays": 7
}
```

**`GET /bot/orders/{NUM}/share`** — Ver link ativo

**`DELETE /bot/orders/{NUM}/share/{TOKEN}`** — Revogar link

---

### Vinculação / Registro

**`GET /bot/link/context`** — Verificar contexto do usuário (linked, segment, labels)

**`POST /bot/link`** — Vincular com token
```json
{"token": "LT_xxx ou INV_xxx"}
```

**`POST /bot/registration/start`** — Iniciar auto-cadastro
```json
{"locale": "pt-BR"}
```

**`POST /bot/registration/update`** — Atualizar dados do cadastro (passo a passo)

**`POST /bot/registration/complete`** — Finalizar cadastro

**`DELETE /bot/registration`** — Cancelar cadastro em andamento

---

## 11. Formato Card de OS

Ao exibir uma OS, o bot **SEMPRE** usa o formato Card. Nunca texto livre.

### Template

```
*OS #[number]* - [STATUS_TRADUZIDO]

*Cliente:* [customer.name]
*[DEVICE_LABEL]:* [device.name] - [device.serial]

*Serviços:*
• [service.name] - R$ [value]

*Produtos:*
• [product.name] (x[qty]) - R$ [value]

*Total:* R$ [total]
*A receber:* R$ [remaining]

*Avaliação:* ⭐x[score] ([score]/5)
_"[rating.comment]"_

🔗 Link cliente: [URL]

_[Z] foto(s)_
```

### Regras do Card

**[DEVICE_LABEL]** = O label do segmento (`labels["device._entity"]`) ou "Dispositivo" como fallback.

**Mapeamento de status (inglês → português):**

| Status API | Exibição |
|---|---|
| `pending` | Pendente |
| `approved` | Aprovado |
| `progress` | Em andamento |
| `done` | Concluído |
| `canceled` | Cancelado |

**Campos opcionais:** Omitir do card se `null` ou vazio:
- Device (nem toda OS tem dispositivo)
- Serviços (se nenhum adicionado)
- Produtos (se nenhum adicionado)
- Fotos (se `photosCount` = 0)
- Avaliação/Rating (se não foi avaliada)
- Link (se não foi compartilhada)

**Regra de pagamento:**
- Se `done` + totalmente pago → Mostrar `*Pago* ✅` em vez de "A receber"
- Caso contrário: `remaining = total - paidAmount`

**Regra de foto:**
1. Obter detalhes: `GET /bot/orders/{NUM}/details` (retorna `photosCount`)
2. Se `photosCount > 0`:
   - Listar fotos: `GET /bot/orders/{NUM}/photos` → obtém `downloadUrl`
   - Baixar primeira foto: `curl "$PRATICOS_API_URL{downloadUrl}" --output foto.jpg`
   - Enviar a imagem usando:
     - `filePath`: caminho da imagem baixada (ex: `foto.jpg`)
     - `message`: texto do card formatado (este é o campo que aparece no WhatsApp)
     - **NÃO usar campo `caption`** — usar SEMPRE `message` para o texto do card
3. Se sem foto: enviar apenas texto do card

**Regra de link:**
- Verificar link ativo: `GET /bot/orders/{NUM}/share`
- Se existir, incluir URL no card

---

## 12. Formulários Dinâmicos (Checklists)

### Tipos de item

| Tipo | Formato do `value` | Descrição |
|---|---|---|
| `text` | String livre | Texto aberto |
| `number` | Número ou string numérica | Valor numérico |
| `boolean` | `true`/`false`/`sim`/`nao` | Sim ou não |
| `select` | Índice (1-N) ou valor textual | Seleção única |
| `checklist` | `"1,3,5"` ou `[1,3,5]` | Múltipla escolha |
| `photo_only` | Apenas foto (upload) | Só aceita foto |

### Fluxo de preenchimento guiado

O bot apresenta **item por item** ao usuário:

1. Listar itens do formulário com status
2. Apresentar o próximo item pendente
3. Para `select`: mostrar opções numeradas
4. Para `checklist`: mostrar opções e explicar que pode marcar várias
5. Para `photo_only`: pedir foto diretamente
6. Salvar resposta e avançar para o próximo

### Emojis de status

| Status | Emoji | Significado |
|---|---|---|
| `pending` | ⏳ | Aguardando preenchimento |
| `in_progress` | 🔄 | Parcialmente preenchido |
| `completed` | ✅ | Concluído |

### Status do formulário

```
pending → in_progress → completed
```

**Não é possível finalizar (`completed`) sem todos os campos obrigatórios preenchidos.** Se tentar, o bot deve listar quais campos faltam.

---

## 13. Configuração e Deploy

### Docker Compose

```yaml
services:
  clawdbot:
    build:
      context: .
      args:
        ENV: dev  # ou prod
    container_name: praticos-bot
    restart: unless-stopped
    ports:
      - "18790:18789"
    volumes:
      - ./clawdbot.dev.json:/root/.openclaw/openclaw.json
      - ./data/.openclaw/credentials:/root/.openclaw/credentials
      - ./data/.openclaw/agents:/root/.openclaw/agents
      - ./data/.openclaw/memory:/root/.openclaw/memory
      - ./workspace/skills:/root/.openclaw/skills
      - ./workspace/AGENTS.md:/root/.openclaw/AGENTS.md
      - ./workspace/SOUL.md:/root/.openclaw/SOUL.md
      - ./workspace/cron:/root/.openclaw/cron
    env_file:
      - .env
```

### Volumes

| Volume | Conteúdo | Persistência |
|---|---|---|
| `credentials/` | Sessão WhatsApp (Puppeteer) | Persistente — evita re-scan do QR |
| `agents/` | Sessões ativas (.jsonl) e SQLite | Persistente — histórico de conversas |
| `memory/` | MEMORY.md + users/*.md | Persistente — memória do bot |
| `skills/` | SKILL.md (montado do workspace) | Fonte — editável sem rebuild |
| `AGENTS.md`, `SOUL.md` | Personalidade (montados) | Fonte — editável sem rebuild |
| `cron/` | Jobs agendados | Fonte |

### Diferenças dev vs prod

| Aspecto | Dev | Prod |
|---|---|---|
| DM Policy | `allowlist` (só números autorizados) | `open` (qualquer número) |
| Token gateway | Hardcoded (`praticos-dev-token-change-me`) | Via env var (`${CLAWDBOT_TOKEN}`) |
| API URL | `host.docker.internal:5001` (emulador) | Cloud Functions URL |
| `allowFrom` | Lista de números específicos | `["*"]` |

### Variáveis de ambiente

```bash
# .env (obrigatórias)
GEMINI_API_KEY=...          # Chave API Google/Gemini
PRATICOS_API_URL=...        # URL base da API PraticOS
PRATICOS_API_KEY=...        # Chave de autenticação da API

# .env.prod (adicional)
CLAWDBOT_TOKEN=...          # Token de autenticação do gateway
```

### Configurações do modelo

```json
{
  "model": {
    "primary": "google/gemini-3-flash",
    "fallbacks": ["google/gemini-2.5-flash"]
  },
  "bootstrapMaxChars": 8000,
  "contextPruning": {
    "keepLastAssistants": 2,
    "softTrimRatio": 0.25,
    "hardClearRatio": 0.4,
    "minPrunableToolChars": 5000,
    "softTrim": {
      "maxChars": 2000,
      "headChars": 500,
      "tailChars": 1000
    },
    "hardClear": {
      "enabled": true,
      "placeholder": "[contexto anterior limpo]"
    }
  },
  "compaction": {
    "mode": "default",
    "reserveTokensFloor": 10000,
    "memoryFlush": { "enabled": true }
  }
}
```

**O que isso significa:**
- SOUL.md é truncado em 8000 caracteres ao ser injetado no contexto
- O contexto é podado agressivamente (soft trim em 25%, hard clear em 40%)
- Compactação ativa com flush de memória
- Apenas as 2 últimas mensagens do assistente são mantidas integralmente

### Sessões

```json
{
  "session": {
    "dmScope": "per-channel-peer",
    "reset": { "mode": "daily" }
  }
}
```

- Uma sessão por par canal+número (cada usuário no WhatsApp tem sua sessão isolada)
- Reset diário (sessão limpa a cada dia)

### Mensagens

```json
{
  "messages": {
    "inbound": { "debounceMs": 3000 }
  }
}
```

Debounce de 3 segundos — agrupa mensagens rápidas consecutivas antes de processar.

### Comandos de operação

```bash
# Subir o bot
docker compose up -d

# Rebuild após mudanças no Dockerfile
docker compose up -d --build

# Ver logs
docker compose logs -f clawdbot

# Restart
docker compose restart clawdbot

# Limpar sessões (resolve sessões travadas)
rm -f data/.openclaw/agents/main/sessions/*.jsonl
docker compose restart clawdbot

# Limpar locks de sessões órfãs (após crash/restart da VM)
rm -f data/.openclaw/agents/main/sessions/*.lock
```

---

## 14. Troubleshooting

### SOUL.md truncado (bootstrapMaxChars)

**Sintoma:** Bot não segue regras que estão no final do SOUL.md.

**Causa:** `bootstrapMaxChars: 8000` trunca o SOUL.md ao injetar no contexto do modelo.

**Solução:** Manter as regras mais críticas no início do SOUL.md. Regras no final podem ser cortadas. Este README serve como referência completa que não está sujeita a esse limite.

### Bot não atualiza Frequentes (cache)

**Sintoma:** Bot responde corretamente mas não salva entidades no cache.

**Causa:** O TTS está sendo enviado antes da atualização do cache, ou o bot está pulando os passos 2-4 do fluxo obrigatório.

**Solução:** O fluxo correto é: `message → read → update → write → TTS`. O TTS/resposta final deve ser **sempre** o último passo.

### `read tool called without path`

**Sintoma:** Erro ao tentar ler arquivo de memória.

**Causa:** O parâmetro correto da tool é `file_path`, não `path` (exceto para `read` do OpenClaw que pode usar `path`). Verificar a assinatura correta da ferramenta.

**Solução:** Usar `read(file_path="memory/users/{NUMERO}.md")`.

### Sessões travadas

**Sintoma:** Bot não responde ou fica em loop.

**Causa:** Arquivo `.jsonl` de sessão corrompido ou lock órfão após crash.

**Solução:**
```bash
# Limpar locks
rm -f data/.openclaw/agents/main/sessions/*.lock

# Se persistir, limpar sessão do usuário específico
rm -f data/.openclaw/agents/main/sessions/{session-id}.jsonl

# Ou limpar todas as sessões
rm -f data/.openclaw/agents/main/sessions/*.jsonl

# Restart
docker compose restart clawdbot
```

### Variáveis de ambiente não expandidas

**Sintoma:** Chamadas API falham com URL literal `$PRATICOS_API_URL`.

**Causa:** Uso de aspas simples (`'$VAR'`) em vez de aspas duplas (`"$VAR"`) nos comandos curl.

**Solução:** SEMPRE usar aspas duplas ao redor de `$PRATICOS_API_URL` e `$PRATICOS_API_KEY` nos comandos exec.

### WhatsApp desconectado

**Sintoma:** Bot não recebe mensagens.

**Causa:** Sessão WhatsApp expirou ou credenciais foram perdidas.

**Solução:** Verificar se o volume `credentials/` está montado. Se necessário, acessar o gateway UI e re-escanear o QR code.

### Bot responde em inglês

**Sintoma:** Respostas em inglês em vez de português.

**Causa:** Compactação de contexto removeu a personalidade em português do SOUL.md.

**Solução:** Garantir que SOUL.md tem a personalidade brasileira no topo (dentro do limite de 8000 chars). O campo `locale` no auto-cadastro deve ser `"pt-BR"`.
