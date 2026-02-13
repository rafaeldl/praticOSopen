# Aba de Oportunidades — Marketplace de Servicos no PraticOS

## Visao Geral

Feature para transformar o PraticOS de "ferramenta de gestao de OS" em **marketplace de servicos + gestao**, agregando demandas de servicos de fontes publicas e privadas e conectando contratantes a prestadores (MEIs).

## Contexto

O programa federal **Contrata+ Brasil** (Lei 14.133/2021) permite que prefeituras contratem MEIs para pequenos servicos (ate R$ 12.545) sem licitacao. A plataforma gov.br conecta demanda com oferta, mas **nao ajuda na gestao da execucao** — que e exatamente o core do PraticOS.

**Oportunidade identificada:** Criar uma aba de "Oportunidades" no PraticOS que:

1. Agrega demandas do Contrata+ Brasil (scraping)
2. Permite que empresas privadas tambem publiquem demandas
3. Prestadores podem ver, filtrar e responder a oportunidades
4. Apos ganhar o contrato, o fluxo segue como OS normal no PraticOS

## Visao do Produto

```
┌──────────────────────────────────────────────────────────┐
│                   ABA OPORTUNIDADES                       │
│                                                           │
│  Fontes de demanda:                                       │
│  1. Contrata+ Brasil (scraping automatico)                │
│  2. Empresas privadas (publicam direto no app)            │
│  3. Prefeituras (criam no PraticOS → publica no gov)     │
│  4. [Futuro] Outras plataformas gov                       │
│                                                           │
│  Para prestadores (MEIs):                                 │
│  - Feed filtrado por cidade/categoria                     │
│  - Notificacao (push + WhatsApp) de novas                 │
│  - Enviar orcamento                                       │
│  - Apos ganhar → OS automatica                            │
│                                                           │
│  Para contratantes (empresas):                            │
│  - Publicar demanda de servico                            │
│  - Receber orcamentos                                     │
│  - Avaliar por preco + rating                             │
│  - Acompanhar execucao                                    │
│                                                           │
│  Para prefeituras (sistema unico):                        │
│  - Criar demanda no PraticOS                              │
│  - PraticOS publica automaticamente no Contrata+          │
│  - Receber propostas e selecionar MEI                     │
│  - Acompanhar execucao (OS, fotos, checklists)            │
│  - Gerar prestacao de contas automaticamente              │
│  - PraticOS envia dados de volta ao sistema gov           │
│                                                           │
│  Diferencial PraticOS:                                    │
│  - Ciclo completo: demanda → execucao → compliance        │
│  - Prefeitura usa UM SO sistema para tudo                 │
│  - Documentacao fotografica                               │
│  - Checklists de vistoria                                 │
│  - Portfolio do prestador                                 │
│  - Tudo acessivel via WhatsApp (bot)                      │
└──────────────────────────────────────────────────────────┘
```

### Ciclo Completo para Prefeituras (PraticOS como sistema unico)

A prefeitura **nunca precisa abrir o site do Contrata+**. Todo o processo acontece dentro do PraticOS:

```
┌─ PraticOS ──────────────────────────────────────────────┐
│                                                          │
│  1. CRIAR DEMANDA                                        │
│     Prefeitura preenche formulario no PraticOS           │
│     (servico, valor max, prazo, local, categoria)        │
│                         │                                │
│                         ▼                                │
│  2. PUBLICAR NO GOVERNO                                  │
│     PraticOS preenche automaticamente o Contrata+        │
│     (automacao de formulario ou API futura)              │
│     Status: "Publicado" ✓                                │
│                         │                                │
│                         ▼                                │
│  3. RECEBER PROPOSTAS                                    │
│     MEIs enviam propostas (via PraticOS ou Contrata+)    │
│     Scraper sincroniza propostas do Contrata+ → PraticOS │
│     Painel unificado com ranking                         │
│                         │                                │
│                         ▼                                │
│  4. SELECIONAR PRESTADOR                                 │
│     Prefeitura escolhe no PraticOS                       │
│     PraticOS atualiza status no Contrata+                │
│     OS criada automaticamente                            │
│                         │                                │
│                         ▼                                │
│  5. ACOMPANHAR EXECUCAO                                  │
│     Prestador executa via PraticOS (fotos, checklists)   │
│     Fiscal acompanha em tempo real                       │
│                         │                                │
│                         ▼                                │
│  6. PRESTAR CONTAS                                       │
│     PraticOS gera pacote de compliance automaticamente   │
│     PraticOS envia dados ao sistema gov                  │
│     Contrato encerrado ✓                                 │
│                                                          │
└──────────────────────────────────────────────────────────┘
```

## Arquitetura

### Novos Models

```
Opportunity (oportunidade/demanda)
├── id
├── source: 'contrata_plus' | 'praticos'    // origem
├── externalId: string?                      // ID no Contrata+ (se aplicavel)
├── title: string
├── description: string
├── category: string                         // pintura, eletrica, hidraulica...
├── maxBudget: double?
├── location: OpportunityLocation
│   ├── state: string
│   ├── city: string
│   ├── address: string?
│   └── coordinates: GeoPoint?
├── deadline: DateTime                       // prazo para envio de proposta
├── executionDeadline: DateTime?             // prazo para execucao
├── status: 'open' | 'evaluating' | 'awarded' | 'completed' | 'expired' | 'canceled'
├── contractor: ContractorAggr              // quem publicou (empresa/prefeitura)
│   ├── id, name, type ('government' | 'private')
├── winner: ProviderAggr?                   // prestador selecionado
├── proposals: [subcollection]
├── paymentMethod: string?
├── paymentTerm: string?
├── tags: [string]
├── govSync: GovernmentSync?                // estado da sincronizacao com sistema gov
│   ├── publishedToGov: bool               // ja publicado no Contrata+?
│   ├── publishedAt: DateTime?
│   ├── govExternalId: string?             // ID gerado pelo Contrata+
│   ├── govUrl: string?                    // link direto no Contrata+
│   ├── lastSyncAt: DateTime?
│   ├── syncStatus: 'pending' | 'published' | 'synced' | 'error'
│   └── syncErrors: [string]?             // erros de sincronizacao
├── createdAt, updatedAt
└── expiresAt: DateTime

Proposal (proposta/orcamento do prestador)
├── id
├── opportunityId: string
├── provider: ProviderAggr                   // MEI/prestador
│   ├── id, name, rating, completedJobs
├── value: double
├── description: string                      // descricao da proposta
├── estimatedDays: int?
├── status: 'submitted' | 'accepted' | 'rejected'
├── createdAt
└── orderId: string?                         // OS criada apos aceite

ProviderProfile (perfil publico do prestador)
├── userId: string
├── companyId: string
├── name: string
├── categories: [string]                     // especialidades
├── location: city/state
├── rating: double                           // media das avaliacoes
├── completedJobs: int
├── portfolio: [PortfolioItem]               // servicos anteriores com fotos
└── active: bool

GovernmentReport (pacote de prestacao de contas)
├── id
├── opportunityId: string                    // ref a oportunidade original
├── orderId: string                          // ref a OS executada
├── externalId: string?                      // ID no Contrata+
├── contractorId: string                     // prefeitura
├── providerId: string                       // MEI que executou
├── status: 'draft' | 'ready' | 'submitted' | 'accepted' | 'rejected'
├── submittedAt: DateTime?
├── submittedBy: UserAggr?                   // fiscal que enviou
├── reportData: GovernmentReportData
│   ├── contractValue: double
│   ├── executedValue: double
│   ├── startDate: DateTime
│   ├── completionDate: DateTime
│   ├── serviceDescription: string
│   ├── photoUrls: [string]                  // fotos com metadados
│   ├── checklistSummary: [ChecklistResult]  // resultado das vistorias
│   ├── fiscalApproval: FiscalApproval       // aprovacao do fiscal
│   │   ├── approved: bool
│   │   ├── approvedBy: UserAggr
│   │   ├── approvedAt: DateTime
│   │   └── notes: string?
│   └── invoiceUrl: string?                  // nota fiscal (se anexada)
├── pdfUrl: string?                          // PDF gerado
├── exportedCsvUrl: string?                  // CSV para upload
├── createdAt, updatedAt
└── deadline: DateTime                       // prazo para envio ao governo
```

### Firestore Structure

```
/opportunities/{opportunityId}                                // demandas (publicas)
/opportunities/{opportunityId}/proposals/{id}                 // propostas dos prestadores
/providers/{userId}                                           // perfis publicos dos prestadores

// Para oportunidades internas (empresa contratante usa PraticOS):
/companies/{companyId}/opportunities/{id}                     // demandas privadas
/companies/{companyId}/opportunities/{id}/proposals/{id}

// Prestacao de contas para prefeituras:
/companies/{companyId}/governmentReports/{reportId}            // pacotes de compliance
```

### Componentes do Sistema

#### 1. Scraper do Contrata+ Brasil (Firebase Function / Cloud Run)

- Cron job (a cada 1h ou 30min)
- Scrape `contratamaisbrasil.sistema.gov.br/oportunidades/`
- Parse HTML → extrair campos de cada oportunidade
- Filtros: por UF/municipio configuravel
- Salva em `/opportunities/` com `source='contrata_plus'`
- Detecta oportunidades novas → dispara notificacoes

#### 2. Gov Publisher — Publicacao de Demandas no Contrata+ (Cloud Run)

Permite que a prefeitura crie a demanda no PraticOS e o sistema publique
automaticamente no Contrata+ Brasil, sem precisar acessar o site do governo.

**Mapeamento de campos PraticOS → Contrata+:**

| Campo PraticOS | Campo Contrata+ |
|----------------|-----------------|
| `title` | Objeto da contratacao |
| `description` | Descricao detalhada |
| `category` | Natureza do servico (CATSER) |
| `maxBudget` | Valor estimado (max R$ 12.545) |
| `location.city` / `state` | Municipio / UF |
| `deadline` | Prazo para recebimento de propostas |
| `executionDeadline` | Prazo de execucao |
| `contractor` (prefeitura) | Orgao contratante (CNPJ, UASG) |

**Estrategia de publicacao (progressiva):**

1. **Nivel 1 — Rascunho assistido (sem integracao)**
   - PraticOS gera um documento com todos os campos preenchidos
   - Servidor da prefeitura faz copy-paste no site do Contrata+
   - Baixa complexidade, funciona imediatamente

2. **Nivel 2 — Automacao de formulario (Puppeteer/Playwright)**
   - Cloud Run com browser headless
   - Prefeitura fornece credenciais gov.br (armazenadas com criptografia)
   - PraticOS preenche o formulario automaticamente no Contrata+
   - Prefeitura recebe preview e confirma antes do envio
   - Captura o ID/URL gerado e salva em `govSync.govExternalId`

3. **Nivel 3 — API direta (quando disponivel)**
   - Integracao via API oficial do Contrata+
   - Publicacao e sync de status em tempo real

**Dados adicionais que a prefeitura precisa informar (especificos do governo):**

```
GovernmentPublishData
├── uasg: string                    // codigo da unidade gestora
├── catserCode: string?             // codigo CATSER do servico
├── fundingSource: string           // fonte de recurso (orcamento)
├── legalBasis: string              // fundamentacao legal (Lei 14.133/2021, Art. 75, II)
├── fiscalOfficer: UserAggr         // fiscal designado
├── contractType: string            // tipo de contrato
└── additionalRequirements: string? // requisitos especificos
```

**Sync bidirecional (apos publicacao):**

```
PraticOS                              Contrata+ Brasil
   │                                        │
   ├── Publica demanda ──────────────────► Oportunidade criada
   │                                        │
   │◄── Scraper detecta propostas ─────── MEIs enviam propostas
   │                                        │
   ├── Seleciona vencedor ───────────────► Atualiza status
   │                                        │
   ├── OS concluida ─────────────────────► Prestacao de contas
   │                                        │
   └── Encerra contrato ────────────────► Contrato finalizado
```

#### 3. Tela de Criacao de Demanda para Prefeituras (App Flutter)

Formulario especifico para prefeituras criarem demandas, com campos do PraticOS
+ campos obrigatorios do governo (UASG, CATSER, fundamentacao legal).

- Wizard guiado: dados do servico → dados governamentais → revisao → publicar
- Validacao automatica (valor max R$ 12.545, campos obrigatorios do Contrata+)
- Preview de como ficara no site do governo
- Botao "Publicar no Contrata+" com confirmacao
- Status de publicacao visivel na tela (pendente → publicado → com propostas)
- Historico de demandas anteriores como template (reutilizar dados recorrentes)

#### 4. Aba Oportunidades no App Flutter

- Nova tab na navegacao principal
- Lista de oportunidades com filtros (cidade, categoria, valor)
- Detalhe da oportunidade
- Botao "Enviar Proposta" (para demandas PraticOS)
- Link externo para Contrata+ (para demandas governamentais)
- Badge de novas oportunidades

#### 5. Fluxo do Contratante (empresa/prefeitura)

- Tela de criacao de oportunidade (similar a criar OS, mas invertido)
- Painel de propostas recebidas (ranking por preco + rating)
- Aceitar proposta → cria OS automaticamente
- Acompanhar execucao via OS

#### 6. Fluxo do Prestador (MEI)

- Feed personalizado (baseado em categorias + localizacao)
- Enviar proposta com valor e descricao
- Notificacao quando ganhar
- OS criada automaticamente
- Perfil publico com portfolio

#### 7. Bot WhatsApp

- Notificar novas oportunidades na cidade do MEI
- Permitir enviar proposta via conversa
- Consultar status das propostas

#### 8. Compliance Gov — Prestacao de Contas para Prefeituras

O Contrata+ Brasil exige que prefeituras reportem a execucao dos contratos ao sistema federal.
O PraticOS ja captura todos os dados necessarios durante a execucao normal da OS. Este componente
empacota esses dados no formato exigido pelo governo, eliminando retrabalho manual.

**Problema que resolve:**
Hoje a prefeitura contrata via Contrata+, gerencia a execucao em planilha/papel, e depois precisa
preencher manualmente os dados de volta no sistema gov. Com o PraticOS, a execucao ja gera os
dados prontos para envio.

**Dados que o PraticOS ja captura e que o governo exige:**

| Dado exigido pelo governo | Fonte no PraticOS |
|---------------------------|-------------------|
| Status do contrato | `Order.status` |
| Data de inicio/conclusao | `Order.startDate` / `Order.completedDate` |
| Valor executado | `Order.totalValue` |
| Descricao do servico | `Order.description` + `OrderService[]` |
| Evidencia fotografica | Fotos da OS (Firebase Storage) |
| Checklist de vistoria | Forms/Checklists preenchidos |
| Dados do prestador (MEI) | `ProviderProfile` (CNPJ, nome, etc) |
| Nota fiscal | Anexo da OS (quando disponivel) |
| Avaliacao do servico | Rating do prestador |

**Funcionalidades:**

1. **Relatorio de Prestacao de Contas (PDF)**
   - Gerado automaticamente ao concluir a OS
   - Inclui: dados do contrato, servicos executados, fotos com timestamp/geolocalizacao, checklists assinados, valor total
   - Formato alinhado com as exigencias do Contrata+ / TCU
   - Assinatura digital do fiscal responsavel

2. **Exportacao Estruturada (CSV/JSON)**
   - Dados formatados para upload em lote no sistema do governo
   - Mapeamento de campos PraticOS → campos Contrata+
   - Permite exportar periodo (mensal, trimestral)
   - Inclui codigos de referencia cruzada (externalId da oportunidade)

3. **Preenchimento Assistido (Automacao de Formulario)**
   - Browser automation (Puppeteer) que preenche o formulario do Contrata+ com dados da OS
   - Prefeitura revisa e confirma antes de submeter
   - Alternativa: gerar um "rascunho" com todos os campos preenchidos para copy-paste
   - Util enquanto nao houver API oficial

4. **Integracao Direta via API (futuro)**
   - Quando/se o governo disponibilizar API do Contrata+
   - Submissao automatica dos dados de execucao
   - Status sync bidirecional (Contrata+ ↔ PraticOS)

5. **Painel de Compliance para o Fiscal**
   - Dashboard mostrando contratos pendentes de prestacao de contas
   - Semaforo: verde (dados completos), amarelo (faltam itens), vermelho (prazo vencendo)
   - Alertas de prazo para envio ao sistema federal
   - Historico de envios anteriores

**Fluxo completo para a prefeitura:**

```
Oportunidade publicada no Contrata+
        │
        ▼
Scraper importa para PraticOS
        │
        ▼
Prefeitura seleciona prestador (MEI)
        │
        ▼
OS criada automaticamente no PraticOS
        │
        ▼
Prestador executa (fotos, checklists, status)
        │
        ▼
Fiscal da prefeitura acompanha e aprova
        │
        ▼
PraticOS gera pacote de prestacao de contas:
├── PDF com relatorio completo
├── Fotos com metadados (timestamp, GPS)
├── Checklists preenchidos e assinados
└── Dados estruturados (CSV/JSON)
        │
        ▼
Envio ao sistema do governo:
├── Opcao A: Upload manual (CSV + PDF)
├── Opcao B: Preenchimento assistido (automacao)
└── Opcao C: API direta (quando disponivel)
        │
        ▼
Contrato encerrado no Contrata+ ✓
```

## Fluxo de Dados

```
  ENTRADA DE DEMANDAS (3 fontes)
  ══════════════════════════════

  Contrata+ (outras         Empresas Privadas        Prefeituras
  prefeituras)               (PraticOS)              (PraticOS → Contrata+)
        │                        │                        │
        ▼                        ▼                        ▼
   Scraper importa        Tela de Criacao          Tela de Criacao
   oportunidades          de Oportunidade          + Gov Publisher
        │                        │                   │         │
        ▼                        ▼                   ▼         ▼
   /opportunities/        /companies/{id}/      Firestore   Contrata+
   (Firestore)            opportunities/           │       (publicado)
        │                        │                  │          │
        ├────────────────────────┴──────────────────┘          │
        ▼                                                      │
   Aba Oportunidades (Flutter App)  ◄── Scraper sincroniza ───┘
        │                               propostas de volta
        ▼
   Prestador envia proposta
        │
        ▼
   Contratante/Prefeitura aceita
        │
        ▼
   OS criada automaticamente
        │
        ▼
   Execucao normal do PraticOS
   (fotos, checklists, status)
        │
        ▼
   Compliance Gov (se prefeitura)
   → Gera relatorio → Envia ao governo
```

## Fases de Implementacao

### Fase 1 — MVP: Feed de Oportunidades (Contrata+ Brasil)

**Objetivo:** Prestadores veem oportunidades do governo no app

- [ ] Model `Opportunity` (dados vindos do Contrata+)
- [ ] Scraper basico (Firebase Function com Puppeteer/Cheerio)
- [ ] Tela de listagem com filtros (UF, municipio, categoria)
- [ ] Tela de detalhe da oportunidade
- [ ] Link "Ver no Contrata+" para submissao externa
- [ ] Notificacao push para novas oportunidades

### Fase 2 — Perfil do Prestador + Portfolio

**Objetivo:** Prestador tem perfil publico com historico

- [ ] Model `ProviderProfile`
- [ ] Tela de perfil publico (magic link)
- [ ] Portfolio automatico baseado em OS concluidas
- [ ] Rating agregado

### Fase 3 — Marketplace PraticOS (Empresas Privadas)

**Objetivo:** Empresas publicam demandas e recebem propostas

- [ ] Model `Proposal`
- [ ] Fluxo de criacao de oportunidade pelo contratante
- [ ] Fluxo de envio de proposta pelo prestador
- [ ] Ranking automatico (preco + rating)
- [ ] Aceite → criacao automatica de OS
- [ ] Notificacoes de propostas

### Fase 4 — Gov Publisher: Prefeituras Criam Demandas pelo PraticOS

**Objetivo:** Prefeitura usa PraticOS como sistema unico — cria demanda aqui e publica no Contrata+

- [ ] Tela de criacao de demanda com campos gov (UASG, CATSER, fundamentacao legal)
- [ ] Wizard guiado: dados do servico → dados governamentais → revisao → publicar
- [ ] Validacao automatica (valor max R$ 12.545, campos obrigatorios)
- [ ] **Nivel 1:** Gerar documento/rascunho com campos preenchidos para copy-paste
- [ ] **Nivel 2:** Automacao de formulario (Puppeteer/Playwright em Cloud Run)
- [ ] Armazenamento seguro de credenciais gov.br (se automacao)
- [ ] Captura do `externalId` e `govUrl` apos publicacao
- [ ] Sync bidirecional: importar propostas do Contrata+ → painel unificado no PraticOS
- [ ] Atualizar status no Contrata+ quando prestador for selecionado
- [ ] Templates de demandas recorrentes (reutilizar dados)
- [ ] **Nivel 3:** Integracao via API oficial (quando disponivel)

### Fase 5 — Integracao com Bot WhatsApp

**Objetivo:** MEI gerencia tudo via WhatsApp

- [ ] Skill de consulta de oportunidades
- [ ] Envio de proposta via conversa
- [ ] Notificacao proativa de novas demandas

### Fase 6 — Dashboard + Fiscalizacao + Compliance Gov

**Objetivo:** Ferramentas de gestao para contratantes e prestacao de contas ao governo

- [ ] Dashboard de oportunidades/contratos
- [ ] Checklists de fiscalizacao por tipo de servico
- [ ] Relatorio de execucao (PDF)
- [ ] Portal de transparencia (magic links publicos)
- [ ] Model `GovernmentReport` (pacote de prestacao de contas)
- [ ] Geracao automatica de PDF de prestacao de contas ao concluir OS
- [ ] Exportacao CSV/JSON com mapeamento de campos PraticOS → Contrata+
- [ ] Painel de compliance (semaforo de status, alertas de prazo)
- [ ] Preenchimento assistido do formulario do Contrata+ (Puppeteer)
- [ ] Integracao direta via API (quando disponivel)

## Consideracoes Tecnicas

### Scraping do Contrata+

- **Riscos:** Site pode mudar estrutura, rate limiting, bloqueio
- **Mitigacao:** User-agent adequado, intervalo entre requests, cache, monitoramento de falhas
- **Alternativa futura:** Se o governo abrir API publica, migrar para API
- **Juridico:** Dados sao publicos, scraping de dados publicos governamentais e permitido (Lei de Acesso a Informacao)

### Multi-Tenancy

- Oportunidades do Contrata+ sao **globais** (nao pertencem a um tenant)
- Oportunidades privadas pertencem a um **tenant** (empresa contratante)
- Propostas sao vinculadas ao prestador (`userId` + `companyId`)

### Monetizacao

| Tier | Inclui |
|------|--------|
| **Free** | Ver oportunidades do Contrata+, perfil basico |
| **Premium MEI** | Notificacoes prioritarias, portfolio destacado, relatorios |
| **SaaS Empresa** | Publicar oportunidades, receber propostas, gestao |
| **SaaS Prefeitura** | Fiscalizacao, dashboards, transparencia |

## Verificacao / Como Testar

### Fase 1 (MVP)

1. Executar scraper manualmente → verificar dados no Firestore
2. Abrir app → aba Oportunidades mostra lista
3. Filtrar por estado/cidade → resultados corretos
4. Clicar em oportunidade → detalhe com link para Contrata+
5. Verificar notificacao push quando nova oportunidade e inserida

### Fases subsequentes (Marketplace)

- Criar oportunidade como empresa → aparece no feed do prestador
- Enviar proposta → contratante ve no painel
- Aceitar proposta → OS criada automaticamente
- Concluir OS → aparece no portfolio do prestador

### Gov Publisher (Fase 4)

1. Prefeitura cria demanda no PraticOS com campos gov (UASG, CATSER) → validacao passa
2. **Nivel 1:** Gerar rascunho → documento contem todos os campos prontos para copy-paste
3. **Nivel 2:** Automacao preenche formulario do Contrata+ → preview correto → prefeitura confirma → publicado
4. `govSync.publishedToGov` = true, `govSync.govExternalId` preenchido apos publicacao
5. Propostas enviadas no Contrata+ aparecem sincronizadas no painel do PraticOS
6. Selecionar prestador no PraticOS → status atualizado no Contrata+
7. Reutilizar template de demanda anterior → campos pre-preenchidos corretamente

### Compliance Gov (Fase 6)

1. Concluir OS vinculada a oportunidade do Contrata+ → `GovernmentReport` criado automaticamente com status `draft`
2. Verificar que PDF contem: dados do contrato, fotos, checklists, valor
3. Painel de compliance mostra semaforo correto (verde/amarelo/vermelho)
4. Exportar CSV → campos mapeados corretamente para formato Contrata+
5. Preenchimento assistido → formulario do governo preenchido com dados da OS
6. Alerta disparado quando prazo de envio esta proximo
