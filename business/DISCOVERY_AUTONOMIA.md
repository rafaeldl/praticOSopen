# Discovery: evolução autônoma do PraticOS

**Data:** 2026-10-04
**Pergunta:** como fazer o PraticOS evoluir mais rápido sem depender do Rafael em cada passo?

---

## 1. Diagnóstico em uma frase

Não falta código nem ideia; falta **uma fila única de trabalho priorizado** e **um jeito de o agente provar sozinho que o trabalho está certo**. Sem isso, toda entrega volta para o Rafael — e quando ele para, o projeto para.

---

## 2. O que encontrei

### 2.1 Ritmo: o projeto anda em rajadas

| Mês | PRs mergeados |
|-----|---------------|
| dez/25 | 24 |
| jan/26 | 60 |
| fev/26 | 48 |
| mar/26 | 23 |
| abr/26 | 15 |
| mai/26 | 2 |
| jun–ago/26 | **0** |
| set/26 | 36 |

Quatro meses parados. Setembro mostrou que o fluxo atual (spec → plano → issues → PR com Claude Code) entrega muito **quando o Rafael está presente**. O gargalo é a presença, não a capacidade.

### 2.2 Não existe roadmap vivo

- `business/LAUNCH_ROADMAP.md` e `business/STATUS_ATUAL.md` são de **jan/2026** e estão desatualizados (billing já foi implementado, MCP foi entregue, etc.).
- `docs/AJUSTES_PRATICOS.md` tem um backlog antigo "Em Planejamento".
- 25 issues abertas, a maioria de **jan–mar/2026**, sem ordem clara. Prioridades marcadas (`priority:high`) incluem itens que já não fazem sentido do jeito que foram escritos (ex.: #96/#97 de billing).
- Não há uma métrica norte escrita (usuários ativos? OS criadas/semana? MRR?).

### 2.3 A tentativa anterior de autonomia (Paperclip, abril/2026)

Em abril rodou uma "empresa de agentes" no Paperclip (`~/.paperclip`): CEO, CTO, Flutter Engineer, CS.

- Gerou **~990 arquivos .md em ~1 semana** — diretivas, escalações "URGENTE", respostas entre agentes, playbooks.
- Exemplo: `BOARD_ESCALATION_2026-04-04.md` — o "CEO" escalando para o Rafael porque o "CTO" não respondeu.
- Entregou código real de billing (PRs #225–#231), mas travou em passos **manuais** (conta RevenueCat, produtos nas lojas, secrets).
- **Nenhuma atividade depois de 10/abr.** Morreu junto com o ritmo do projeto.

**Lições:**
1. Hierarquia de agentes conversando entre si produz burocracia, não produto.
2. Agente sem acesso a passos manuais (lojas, consoles, credenciais) fica bloqueado e escala para o humano — volta a depender do Rafael.
3. A medida de sucesso tem que ser **PR mergeado / release publicada**, nunca documento gerado.

### 2.4 O agente não consegue se auto-verificar

| Camada | Tamanho | Verificação automática |
|--------|---------|------------------------|
| App Flutter (`lib/`) | ~71k linhas | `flutter analyze` no CI. **15 arquivos de teste, nenhum roda no CI.** |
| Cloud Functions | — | `lint` no CI. Jest existe (35 testes) mas **não roda no CI.** |
| Fluxos E2E | 5 fluxos Maestro (billing) | Manuais. |
| Site Eleventy | — | Só build no deploy. |

Consequência: todo PR precisa de olho humano para saber se quebrou algo. É isso que impede auto-merge.

### 2.5 Pontas soltas

- PRs abertos parados: #159 (bot, fev), #194 (web portal, fev, +1100 linhas), #295 (segurança, set).
- Bot do WhatsApp com VM parada e sync desligado.
- Monetização: billing pronto no código, mas **recursos pagos removidos do iOS** (guideline 3.1.1, PR #292). Hoje não há caminho de receita no iOS.
- MCP (ChatGPT/Claude) fase 1 entregue; fases 2–4 (OAuth, diretórios, RBAC) pendentes.
- ~80 arquivos em `docs/`, vários são planos já executados ou abandonados. Ruído para humanos e agentes.

---

## 3. Proposta: um loop enxuto, não um organograma

Em vez de "empresa de agentes", **um ciclo simples com dois papéis**: o Rafael decide *o quê*, o agente faz *o como* e prova que funciona.

```
        ┌──────────────── semanal ────────────────┐
        │  Agente de PRODUTO (rotina agendada)     │
        │  lê: métricas, Crashlytics, reviews,     │
        │  ads, issues, ROADMAP.md                 │
        │  propõe: até 3 issues prontas            │
        └──────────────────┬───────────────────────┘
                           ▼
        Rafael: aprova com 1 label (`agent-ready`)   ← único ponto obrigatório
                           ▼
        ┌──────────────── diário ─────────────────┐
        │  Agente de ENGENHARIA (rotina agendada)  │
        │  pega a issue `agent-ready` do topo      │
        │  branch → código → testes → PR           │
        └──────────────────┬───────────────────────┘
                           ▼
        CI verde + baixo risco → auto-merge
        CI verde + alto risco  → Rafael revisa
                           ▼
        auto-version → TestFlight/Internal (já existe)
```

### 3.1 Peças

**A. `ROADMAP.md` na raiz (fonte única)**
Curto. Três colunas: *Agora* (máx. 3 itens), *Próximo*, *Depois*. Uma linha de métrica norte no topo. Substitui `LAUNCH_ROADMAP.md`, `STATUS_ATUAL.md` e `AJUSTES_PRATICOS.md`.

**B. Issues como contrato**
Template de issue com: problema, critério de aceite verificável, risco (`risk:low` / `risk:high`), arquivos prováveis. Label `agent-ready` = aprovado para o agente pegar. Limite de WIP: **no máximo 2 PRs de agente abertos** — se acumular, o agente para de abrir e vai revisar/consertar os existentes.

**C. Rede de segurança no CI (pré-requisito do auto-merge)**
1. Rodar `flutter test` e `npm test` (functions) no CI.
2. Todo PR de agente traz teste novo para o que mudou.
3. Opcional depois: Maestro/screenshot em PR que mexe em UI.

**D. Política de risco**

| Pode auto-mergear (`risk:low`) | Sempre passa pelo Rafael (`risk:high`) |
|---|---|
| Bug fix com teste | `firestore.rules`, `storage.rules` |
| Testes, refatoração local | Auth, billing, assinatura, IAP |
| Docs técnicas e site/SEO | Workflows de CI/release, fastlane |
| i18n, ajustes de UI isolados | Migrações de dados, modelos compartilhados |
| Dependências patch | Qualquer coisa que toque produção fora do fluxo de release |

**E. Rotinas agendadas (Claude Code `/schedule`, na nuvem)**
- *Diária – engenharia:* pega issue, abre PR, conserta CI vermelho dos próprios PRs.
- *Semanal – produto:* relatório curto (o que saiu, o que os dados dizem, 3 issues propostas).
- *Semanal – higiene:* dependências, issues velhas, PRs parados, docs obsoletas.

Rodar na nuvem, não no Mac, para não depender da máquina ligada.

### 3.2 O que fica com o Rafael (e só isso)

1. Definir a métrica norte e o *Agora* do roadmap (1x por mês).
2. Pôr `agent-ready` em issues (≈10 min/semana).
3. Revisar PRs `risk:high`.
4. Passos que exigem a pessoa: lojas, consoles, contas, promover release para produção.

---

## 4. Plano de arranque (2 semanas)

| # | Passo | Quem | Esforço |
|---|-------|------|---------|
| 1 | Decidir métrica norte e os 3 itens de *Agora* | Rafael | 30 min |
| 2 | Criar `ROADMAP.md`, arquivar roadmaps antigos | Agente | 1 PR |
| 3 | Triar as 25 issues: fechar, reescrever ou marcar `agent-ready` | Agente propõe, Rafael aprova | 1 sessão |
| 4 | Resolver PRs parados (#159, #194, #295): mergear ou fechar | Rafael decide | 15 min |
| 5 | Adicionar `flutter test` + `npm test` no CI e corrigir o que falhar | Agente | 1–2 PRs |
| 6 | Template de issue + labels `agent-ready`, `risk:low`, `risk:high` | Agente | 1 PR |
| 7 | Seção "Modo autônomo" no `CLAUDE.md` (regras de risco, WIP, definição de pronto) | Agente | 1 PR |
| 8 | Criar rotina diária de engenharia, começar **sem auto-merge** | Agente + Rafael | 1 sessão |
| 9 | Após ~10 PRs bons: ligar auto-merge para `risk:low` | Rafael | — |
| 10 | Criar rotina semanal de produto | Agente | 1 sessão |

---

## 5. Decisões tomadas (2026-10-04)

1. **Métrica norte:** empresas ativas por semana (criaram ≥1 OS nos últimos 7 dias). Métrica secundária, e a mais urgente: **receita mensal**.
2. **Direção principal: monetização.** Hoje o app só gera custo. Ver seção 6.
3. **Escopo da autonomia:** tudo — código, site/SEO, conteúdo e ads.
4. **Bot do WhatsApp: desligado.** Custo de VM + LLM sem receita. O MCP (ChatGPT/Claude) cobre o caso de uso sem custo de LLM para nós: quem paga o modelo é o usuário.

---

## 6. Monetização

### 6.1 Onde estamos

- **Uso (Firestore, 2026-10-04):**

  | Janela | Empresas novas | Empresas ativas (≥1 OS) |
  |--------|----------------|--------------------------|
  | 7 dias | 11 | **27** |
  | 30 dias | 84 | 67 |
  | 90 dias | 225 | 129 |
  | 365 dias | 510 | 243 |

  744 empresas no total, ~25,5 mil OS criadas.
- **Aquisição orgânica:** Google Ads está pausado e com gasto zero nos últimos 30 dias, e mesmo assim entram ~84 empresas/mês. Só ~1 em cada 3 cadastradas no ano segue ativa.
- **Receita: zero.** Planos (Free/Starter/Pro/Business) implementados via RevenueCat, ativos só no Android/web.
- **iOS sem nenhum recurso pago** desde a 1.52.3: a Apple rejeitou 3 versões pela guideline 3.1.1 (recurso pago sem IAP).
- **Custos:** bot do WhatsApp **apagado em 2026-10-04** (VM + disco; conversas salvas em `gs://praticos-bot-archive`). Restam Cloud Run (`api`, `praticos-web`), Functions, Firestore/Storage. Google Ads pausado. Meta Ads: token da API expirou em abr/2026, status a confirmar.

- **Aprendizados do bot do WhatsApp (mar–ago/2026, agregados):** ~95 contatos, só ~5 com uso recorrente. O uso que pegou foi **orçamento rápido por texto/foto em funilaria e estética automotiva** (placa + peças + preço → orçamento → "aprovado"). Custo de LLM ~US$ 178, ~US$ 0,09 por mensagem — causado pela arquitetura (agente genérico executando shell, ~160 mil tokens/mensagem), não pelo canal. Análise completa fica fora do repositório (contém dados de clientes).

**Leitura honesta:** o modelo atual cobra por *limite* (fotos, formulários, usuários, marca d'água). Limite incomoda, mas não cria vontade de pagar. Mesmo no Android, onde a cobrança está ligada, não há receita. O problema não é só técnico (IAP), é de **proposta de valor**.

### 6.2 Opções

| # | Aposta | Como ganha | Por que pode funcionar | Risco / custo | Apple |
|---|--------|-----------|------------------------|---------------|-------|
| A | **Cobrar a OS pelo link (Pix/cartão)** via Asaas com split | % por transação (ex.: 0,99% + taxa do Asaas) | Dor real: o técnico já manda o link da OS; receber ali mesmo é óbvio. Não depende de convencer a assinar. | KYC de subcontas, suporte a estorno. Receita proporcional ao volume. | **Fora do IAP**: pagamento de serviço físico (3.1.3(e)/3.1.5) |
| B | **IA que economiza tempo** — maior evidência de uso no bot (OS/orçamento por áudio/foto, orçamento sugerido, mensagem pronta para o cliente, resumo do dia) | Plano Pro com créditos de IA | Diferencial que o concorrente de planilha não tem. Valor visível em 1 uso. | Custo por chamada (Haiku/Jev barato, mas tem que medir). | Recurso digital → **IAP no iOS** |
| C | **Conectar ao ChatGPT/Claude (MCP)** como recurso Pro | Assinatura | Já está pronto. Custo de LLM é do usuário. Canal de aquisição nos diretórios. | Público que usa ChatGPT/Claude ainda é pequeno entre técnicos. | IAP no iOS |
| D | **Assistente no WhatsApp pago** (o bot, mas como add-on) | Add-on ~R$49/mês | O bot já existia e funcionava; o problema foi dar de graça. 3–4 clientes pagam a VM + LLM. | Operação (VM, sessões). | Serviço externo; vendido fora do app |
| E | **NFS-e integrada** (via Asaas) | Por nota ou no plano | Obrigação fiscal; dor recorrente em MEI/oficina. | Variação por município. | Fora do IAP se cobrado no Asaas |
| F | **Oportunidades / leads** (Contrata+ Brasil, diretório público) | Por lead ou destaque | Traz cliente novo para o prestador — o que ele mais quer. | Precisa de liquidez dos dois lados. Longo prazo. | — |

### 6.3 Recomendação

**Não construir antes de validar.** Ordem:

1. **Semana 1–2 — validar disposição a pagar (sem código).** Agente monta lista das empresas mais ativas; Rafael (ou agente, com aprovação) fala com 10–20 delas. Pergunta única: *"se você pudesse receber o pagamento pelo link da OS e emitir a nota ali, pagaria X?"* e *"se a OS se preenchesse sozinha a partir de um áudio, pagaria Y?"*. Landing page de pré-venda com botão "quero" para medir clique.
2. **Aposta principal: A (cobrança na OS) + E (NFS-e) no Asaas.** Escapa da Apple, monetiza pelo uso real e vira motivo para o técnico abrir o app todo dia. Receita escala com o volume dos clientes, não com convencer cada um a assinar.
3. **Aposta secundária: B + C no plano Pro**, com IAP no iOS feito direito (produtos na App Store via RevenueCat). Código de assinatura já existe; falta configurar as lojas e trocar os gatilhos de "limite" por "IA".
4. **D fica guardada:** só volta como add-on pago, quando houver ao menos 5 interessados.
5. **Custos:** VM do bot apagada e ads pausados (2026-10-04).

### 6.4 Dados que faltam

- Assinantes e receita no RevenueCat (Android).
- Status do Meta Ads.
- Fatura do GCP/Firebase do último mês.
