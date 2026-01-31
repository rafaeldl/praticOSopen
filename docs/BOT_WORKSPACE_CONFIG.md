# BOT_WORKSPACE_CONFIG.md

Documentação técnica da estrutura de configuração do workspace do bot PraticOS, baseado no [OpenClaw](https://docs.openclaw.ai/).

## Visão Geral

O **workspace** é o diretório de trabalho do agente de IA. Contém os arquivos de configuração que definem a identidade, personalidade, habilidades e regras operacionais do bot.

### Conceito Fundamental

> "Arquivos são a fonte da verdade; o modelo só 'lembra' o que está escrito em disco."

O agente não possui memória persistente entre sessões. Tudo o que ele precisa "saber" deve estar documentado nos arquivos do workspace. Cada sessão começa com o carregamento desses arquivos no contexto.

### Localização

| Ambiente | Caminho |
|----------|---------|
| OpenClaw padrão | `~/.openclaw/workspace` |
| PraticOS | `backend/bot/workspace/` |

### Separação de Responsabilidades

```
workspace/           → Configuração do agente (commitável)
~/.openclaw/        → Credenciais e sessões (NÃO commitar)
    ├── openclaw.json
    ├── credentials/
    └── sessions/
```

---

## Arquivos de Bootstrap

Arquivos injetados automaticamente no início de cada sessão do agente.

| Arquivo | Propósito | Quando Carrega |
|---------|-----------|----------------|
| **IDENTITY.md** | QUEM é o bot: nome, emoji, avatar, tipo | Toda sessão |
| **SOUL.md** | COMO age: persona, tom, limites, valores | Toda sessão |
| **USER.md** | Sobre o USUÁRIO: nome, pronomes, timezone | Toda sessão |
| **AGENTS.md** | REGRAS operacionais, como usar memória | Toda sessão |
| **TOOLS.md** | Notas sobre ferramentas locais | Toda sessão |
| **BOOTSTRAP.md** | Ritual de primeira execução | Apenas 1ª vez |

### Comportamento do Sistema

- Arquivos em branco são ignorados
- Arquivos grandes são truncados automaticamente
- Arquivos faltantes geram marcador de "missing file"

---

## Descrição dos Arquivos

### IDENTITY.md

Define **quem** é o bot: nome, personalidade fundamental e contexto de trabalho.

```markdown
# IDENTITY.md - Quem Sou Eu

VOCÊ É O **PRATICO**, o assistente virtual oficial do PraticOS.

## Minha Essência
Sou direto, pratico e eficiente. Ajudo donos de oficinas...

## Personalidade
- **Objetivo**: Vou direto ao ponto
- **Amigável**: Sem ser formal demais
- **Prestativo**: Resolvo problemas
- **Brasileiro**: Uso expressões naturais

## Limites
- Nunca invento dados - sempre consulto a API
- Se não sei algo, admito e direciono
- Dados sigilosos ficam sigilosos
```

**Uso no PraticOS:** Consolidado com SOUL.md em um único arquivo.

---

### SOUL.md

Define **como** o bot age: tom, personalidade, valores e limites comportamentais.

**Status no PraticOS:** Conteúdo consolidado em `IDENTITY.md` para simplificação.

---

### USER.md

Informações sobre o usuário/humano que o bot atende.

```markdown
# USER.md - About Your Human

- **Name:**
- **What to call them:**
- **Pronouns:**
- **Timezone:**
- **Notes:**

## Context
(O que importa para eles? Projetos atuais? Preferências?)
```

**Uso no PraticOS:** Não utilizado diretamente. Contexto do usuário é obtido via API (`/bot/link/context`).

---

### AGENTS.md

Regras operacionais: como usar memória, segurança, quando responder.

```markdown
# AGENTS.md - Seu Workspace

## Cada Sessão
1. Leia SOUL.md - isso é quem você é
2. Leia skills/praticos/SKILL.md - suas instruções

## Memória
- Notas diárias: memory/YYYY-MM-DD.md
- Longo prazo: MEMORY.md

## Segurança
- Nunca exfiltre dados privados
- Não execute comandos destrutivos sem perguntar
- trash > rm

## Chats em Grupo
### Quando Responder
- Diretamente mencionado ou perguntado algo
- Pode adicionar valor genuíno

### Fique em silêncio quando:
- É apenas conversa casual
- Alguém já respondeu
```

---

### TOOLS.md

Notas específicas do ambiente local, não relacionadas a skills.

```markdown
# TOOLS.md - Local Notes

## O que vai aqui
- Nomes de câmeras e localizações
- Hosts SSH e aliases
- Vozes preferidas para TTS
- Nomes de dispositivos
- Qualquer coisa específica do ambiente
```

**Por que separado?** Skills são compartilháveis. Configurações locais são pessoais.

---

### HEARTBEAT.md

Checklist para execuções periódicas (cron/heartbeat).

```markdown
# HEARTBEAT.md

# Manter vazio para pular chamadas de heartbeat.
# Adicionar tarefas abaixo para verificações periódicas.
```

**Uso:** Quando o agente é chamado via heartbeat, executa as tarefas listadas aqui.

---

### BOOTSTRAP.md (Opcional)

Instruções de primeira execução. Deletado automaticamente após uso.

---

## Sistema de Skills

Skills são habilidades modulares que o agente pode utilizar.

### Estrutura do SKILL.md

```markdown
---
name: skill-name
description: Descrição breve da skill
homepage: https://exemplo.com
user-invocable: true
metadata: {"openclaw": {"emoji": "🔧", "requires": {"bins": ["curl"]}}}
---

# Nome da Skill

Instruções de uso aqui...
```

### Campos do Frontmatter

| Campo | Obrigatório | Descrição |
|-------|-------------|-----------|
| `name` | ✅ | Identificador único da skill |
| `description` | ✅ | Explicação funcional |
| `homepage` | ❌ | URL do projeto/documentação |
| `user-invocable` | ❌ | Expor como comando slash (default: true) |
| `metadata` | ❌ | JSON com requisitos e configuração |

### Metadata OpenClaw

```json
{
  "openclaw": {
    "emoji": "📨",
    "os": ["darwin", "linux"],
    "requires": {
      "bins": ["binary-name"],
      "env": ["ENV_VAR"],
      "config": ["path.to.setting"]
    },
    "always": true
  }
}
```

| Campo | Descrição |
|-------|-----------|
| `emoji` | Ícone visual da skill |
| `os` | Sistemas operacionais suportados |
| `requires.bins` | Binários necessários no PATH |
| `requires.env` | Variáveis de ambiente obrigatórias |
| `requires.config` | Configurações necessárias |
| `always` | Sempre carregar (não requer invocação) |

### Hierarquia de Carregamento

```
1. Workspace skills (<workspace>/skills/)     ← PRIORIDADE MÁXIMA
2. Managed skills (~/.openclaw/skills/)
3. Bundled skills (instalação)                ← PRIORIDADE MÍNIMA
```

Em conflitos de nome, workspace sempre vence.

---

## Sistema de Memória

O agente "acorda zerado" cada sessão. Os arquivos de memória fornecem continuidade.

### Duas Camadas

#### 1. Logs Diários (`memory/YYYY-MM-DD.md`)

- Formato append-only
- Contexto temporário e notas do dia
- Recomendação: ler hoje + ontem no início da sessão

```markdown
# memory/2025-01-09.md

## 14:30 - Sessão com João
- Criou 3 OS para mecânica
- Cliente recorrente: Auto Peças Silva

## 16:45 - Dúvida sobre faturamento
- Explicado relatório financeiro
```

#### 2. Memória de Longo Prazo (`MEMORY.md`)

- Curada manualmente
- Decisões, preferências, fatos duráveis
- Carregar apenas em sessões privadas (não em grupos)

```markdown
# MEMORY.md

## Preferências
- João prefere respostas curtas
- Sempre confirmar antes de deletar

## Decisões
- Formato de OS: sempre incluir fotos
```

### Memory Flush Automático

Quando os tokens se aproximam do limite do contexto:
1. Sistema identifica informações duráveis
2. Salva em MEMORY.md antes da compactação
3. Previne perda de dados importantes

---

## Estrutura de Diretórios

```
workspace/
├── IDENTITY.md          # Quem é o bot
├── SOUL.md              # Como age (opcional)
├── USER.md              # Sobre o usuário
├── AGENTS.md            # Regras operacionais
├── TOOLS.md             # Notas locais
├── HEARTBEAT.md         # Tarefas periódicas
├── MEMORY.md            # Memória de longo prazo
├── memory/              # Logs diários
│   └── YYYY-MM-DD.md
├── skills/              # Skills do workspace
│   └── praticos/
│       └── SKILL.md
├── media/               # Arquivos de mídia
│   └── inbound/         # Mídia recebida
├── canvas/              # Arquivos UI (opcional)
├── identity/            # Identificação do dispositivo
│   ├── device.json
│   └── device-auth.json
├── devices/             # Dispositivos pareados
│   ├── pending.json
│   └── paired.json
└── cron/                # Jobs agendados
    └── jobs.json
```

---

## O que NÃO está no Workspace

Estes arquivos ficam em `~/.openclaw/` e **NÃO devem ser commitados**:

| Caminho | Conteúdo |
|---------|----------|
| `openclaw.json` | Configuração global |
| `credentials/` | Tokens OAuth, API keys |
| `agents/<id>/sessions/` | Transcrições de sessões |
| `skills/` | Skills managed (instaladas) |

---

## Boas Práticas

### Git Backup

Recomendado manter workspace em repositório **PRIVADO**.

**.gitignore sugerido:**

```gitignore
# Sistema
.DS_Store

# Segredos
.env
**/*.key
**/*.pem
**/secrets*

# Arquivos temporários
media/inbound/*
*.bak

# Credenciais
identity/device-auth.json
devices/*.json
cron/*.json
```

### Segurança

1. Nunca commitar credenciais
2. Usar variáveis de ambiente para API keys
3. Arquivos de auth no `.gitignore`

---

## Adaptação para PraticOS

### Mapeamento Original → PraticOS

| Arquivo Original | PraticOS | Status |
|------------------|----------|--------|
| IDENTITY.md | IDENTITY.md | ✅ Em uso |
| SOUL.md | (em IDENTITY.md) | ✅ Consolidado |
| USER.md | USER.md | ⚪ Template vazio |
| AGENTS.md | AGENTS.md | ✅ Em uso |
| TOOLS.md | TOOLS.md | ⚪ Template vazio |
| skills/* | skills/praticos/SKILL.md | ✅ Em uso |

### Uso Simplificado

O PraticOS utiliza uma configuração enxuta:

1. **IDENTITY.md** → Personalidade completa do PRATICO
2. **AGENTS.md** → Regras operacionais e de segurança
3. **skills/praticos/SKILL.md** → API PraticOS e regras de negócio

### Contexto via API

Diferente do OpenClaw original, o PraticOS obtém contexto do usuário dinamicamente:

```bash
# Verificar vínculo e obter contexto
curl -s -H 'X-WhatsApp-Number: {NUMERO}' \
  '$BASE/bot/link/context'
```

Retorna informações da empresa vinculada, eliminando necessidade de USER.md preenchido.

---

## Skill PraticOS

A skill principal do bot, definida em `skills/praticos/SKILL.md`.

### Configuração

```yaml
---
name: praticos
description: Assistente PraticOS para gestao de OS via WhatsApp
user-invocable: false
metadata: {"moltbot": {"always": true}}
---
```

- `user-invocable: false` → Não aparece como comando slash
- `always: true` → Sempre carregada no contexto

### Conteúdo Principal

A skill define:

1. **Configuração da API** (BASE URL, headers)
2. **Passo inicial obrigatório** (verificar vínculo)
3. **Regras de uso** (IDs obrigatórios, fluxos)
4. **Endpoints disponíveis** (CRUD completo)
5. **Exemplos curl** (referência rápida)
6. **Formatação** (regras WhatsApp)
7. **Card de OS** (formato padrão de exibição)

---

## Referências

- [Documentação OpenClaw](https://docs.openclaw.ai/)
- [Workspace Configuration](https://docs.openclaw.ai/workspace)
- [Skills Development](https://docs.openclaw.ai/skills)

---

*Este arquivo documenta a estrutura de configuração do workspace do bot. Para alterações na API ou regras de negócio, edite `skills/praticos/SKILL.md`.*
