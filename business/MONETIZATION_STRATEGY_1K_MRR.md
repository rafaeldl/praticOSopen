# Estratégia de Monetização: De R$0 a R$1K MRR

**Data:** 2026-04-03
**Status:** Em revisão
**Autor:** CEO Agent
**Meta:** R$ 1.000 MRR (Receita Recorrente Mensal)

---

## Sumário Executivo

O PraticOS está publicado nas lojas (iOS/Android) como app gratuito com ~1.300 instalações recentes via Google Ads (CPA de R$0,74). Temos precificação definida (PRICING.md) mas ainda não implementada.

**Para atingir R$ 1K MRR:**
- Com ticket médio de R$ 59 (Starter): **17 clientes pagantes**
- Com ticket médio de R$ 89 (mix Starter/Pro): **12 clientes pagantes**

Este documento detalha como implementar a monetização e converter usuários gratuitos em pagantes.

---

## 1. Modelo de Monetização Recomendado

### Freemium com Upgrade por Valor

**Por que freemium funciona para nosso público:**
- Donos de oficinas e técnicos são cautelosos com investimentos
- Precisam ver valor antes de pagar
- Competimos com papel/planilha (custo zero)
- PLG (Product-Led Growth) tem CAC menor

**Estrutura aprovada (manter):**

| Plano | Preço | Público-alvo |
|-------|-------|--------------|
| Free | R$ 0 | Autônomos, teste |
| Starter | R$ 59/mês | MEI, 1-2 pessoas |
| Pro | R$ 119/mês | Pequena empresa, 3-5 pessoas |
| Business | R$ 249/mês | Empresa média, 5+ pessoas |

### Gatilhos de Upgrade (Features Gate)

| Limite Free | Gatilho de Upgrade |
|-------------|-------------------|
| 30 fotos/mês | "Limite de fotos atingido" |
| 1 formulário | "Crie formulários ilimitados" |
| PDF com marca d'água | "Remova a marca d'água" |
| 1 usuário | "Adicione sua equipe" |

---

## 2. O que Deve Ser Gratuito vs Pago

### Grátis (Free Forever)
- ∞ Clientes cadastrados
- ∞ Ordens de serviço
- ∞ Equipamentos
- Histórico completo
- Financeiro básico (contas a receber)
- Dashboard e relatórios básicos
- Link mágico para cliente acompanhar OS
- 30 fotos/mês
- 1 formulário customizado
- 1 usuário

**Racional:** O Free precisa entregar valor real para criar hábito de uso. Sem valor, não há upgrade.

### Pago (Starter+)
- Mais fotos (200+/mês)
- Mais formulários (3+)
- PDF sem marca d'água
- Múltiplos usuários
- Backup em nuvem avançado
- Suporte prioritário

### Pago (Pro/Business)
- API de integração
- Multi-empresa
- Relatórios avançados
- Customização de campos

---

## 3. Preço e Justificativa de Mercado

### Benchmark de Concorrentes (SaaS para PMEs)

| Concorrente | Entrada | Médio | Observação |
|-------------|---------|-------|------------|
| Contele OS | R$ 89 | R$ 199 | Mínimo 4 usuários |
| Field Control | R$ 79 | R$ 149 | Foco em equipes externas |
| Optima OS | R$ 99 | R$ 199 | Menos features |
| Assistec | R$ 49 | R$ 99 | Interface datada |

### Nossa Posição

**Starter R$ 59/mês** está ~25% abaixo da média do mercado, o que é estratégico para:
- Atrair first-timers em SaaS
- Competir com "custo zero" do papel
- Facilitar decisão de upgrade

### Ticket Médio Projetado

Assumindo mix de planos no primeiro ano:
- 70% Starter (R$ 59) = R$ 41,30
- 25% Pro (R$ 119) = R$ 29,75
- 5% Business (R$ 249) = R$ 12,45
- **Ticket médio ponderado: R$ 83,50**

---

## 4. Meta: Quantos Clientes para R$ 1K MRR

### Cenário Conservador (100% Starter)
- R$ 1.000 ÷ R$ 59 = **17 clientes**

### Cenário Realista (Mix de planos)
- R$ 1.000 ÷ R$ 83,50 = **12 clientes**

### Cenário Otimista (Upsell forte)
- R$ 1.000 ÷ R$ 100 = **10 clientes**

**Meta operacional: 15 clientes pagantes**

---

## 5. Funil de Conversão

### Estado Atual (Estimado)
```
Impressões (Ads)    →  100.000/mês
Instalações         →  ~1.300/mês (CPA R$0,74)
Cadastros           →  ~500/mês (38% das instalações)
Usuários ativos     →  ~150/mês (30% dos cadastros)
Pagantes            →  0 (billing não implementado)
```

### Funil Meta (Mês 3)
```
Instalações         →  1.500/mês
Cadastros           →  600/mês (40%)
Usuários ativos     →  250/mês (42%)
Trial/Upgrade       →  50/mês (20% dos ativos)
Conversão paga      →  15/mês (30% dos trials)
Churn               →  2/mês (13%)
MRR líquido         →  +R$ 767/mês
```

### Conversão Necessária
- Com 150 usuários ativos/mês
- Conversão de 10% para pago
- = 15 pagantes/mês
- = R$ 1.237 MRR (com ticket de R$ 82,50)

---

## 6. Ações Concretas de Conversão

### Fase 1: Implementação Técnica (Semana 1-2)

| Ação | Responsável | Prioridade |
|------|-------------|------------|
| Criar produtos de assinatura na App Store | Dev | P0 |
| Criar produtos de assinatura no Google Play | Dev | P0 |
| Integrar `in_app_purchase` no Flutter | Dev | P0 |
| Implementar controle de fotos/mês | Dev | P1 |
| Adicionar marca d'água no PDF (Free) | Dev | P1 |
| Tela de planos/upgrade no app | Dev | P1 |

### Fase 2: Paywall Inteligente (Semana 3-4)

| Ação | Descrição |
|------|-----------|
| Soft paywall | Quando usuário atinge limite, mostrar upgrade suave |
| Trial de 7 dias | Oferecer trial do Starter após 7 dias de uso |
| Push notifications | "Você atingiu 25 fotos este mês" |
| In-app messages | Educar sobre valor do Pro durante uso |

### Fase 3: Campanhas de Conversão (Semana 5+)

| Canal | Ação |
|-------|------|
| Email | Sequência de onboarding + upgrade |
| Push | Lembretes de limite + ofertas |
| In-app | Banner de "Experimente Pro por 7 dias" |
| WhatsApp | Mensagem personalizada para power users |

---

## 7. Estratégia de Pricing Communication

### No App

```
┌─────────────────────────────────────┐
│ 🎉 Você criou 28 OS este mês!       │
│                                     │
│ Com o plano Starter você pode:      │
│ ✓ Adicionar 200 fotos/mês           │
│ ✓ Criar 3 formulários               │
│ ✓ PDF sem marca d'água              │
│                                     │
│ Por apenas R$ 59/mês                │
│                                     │
│ [Experimentar 7 dias grátis]        │
│ [Talvez depois]                     │
└─────────────────────────────────────┘
```

### Página de Preços (Site)

- Preços transparentes (diferencial vs concorrência)
- Calculadora "Quanto sua oficina precisa"
- FAQ sobre cobrança
- Comparativo com concorrentes

---

## 8. Cronograma de Implementação

### Semana 1-2: Fundação Técnica
- [ ] Criar produtos nas lojas (IAP)
- [ ] Implementar RevenueCat ou solução similar
- [ ] Tela de planos no app
- [ ] Webhook de assinatura → Firebase

### Semana 3-4: Gates de Valor
- [ ] Contador de fotos/mês
- [ ] Limite de formulários
- [ ] Marca d'água no PDF
- [ ] Paywall suave

### Semana 5-6: Campanhas
- [ ] Sequência de email de onboarding
- [ ] Push notifications de limite
- [ ] A/B test de paywall
- [ ] Trial de 7 dias

### Semana 7-8: Otimização
- [ ] Análise de conversão
- [ ] Ajuste de preços se necessário
- [ ] Upsell de Starter → Pro
- [ ] Redução de churn

---

## 9. Delegação de Tarefas

### Para Equipe de Desenvolvimento (CTO/Flutter Engineer)

1. **P0 - Billing Infrastructure**
   - Integrar In-App Purchase (iOS/Android)
   - Implementar RevenueCat ou solução nativa
   - Sincronizar status de assinatura com Firebase
   - Tela de gerenciamento de assinatura

2. **P1 - Feature Gates**
   - Contador de fotos por período
   - Limite de formulários por plano
   - Marca d'água dinâmica no PDF
   - Controle de usuários por empresa

3. **P2 - Upgrade UX**
   - Tela de planos comparativos
   - Modal de upgrade contextual
   - Deep link para upgrade

### Para Equipe de Marketing (Head of Growth)

1. **Campanhas de Conversão**
   - Sequência de email de trial
   - Segmentação de power users
   - Retargeting de usuários Free

2. **Comunicação de Preço**
   - Página de preços no site
   - FAQ de billing
   - Conteúdo sobre ROI do app

3. **Análise**
   - Dashboard de MRR
   - Funil de conversão
   - Cohort de retenção

### Para Customer Success

1. **Onboarding de Pagantes**
   - Checklist de primeiro uso
   - Tutorial de features Pro
   - Suporte prioritário

2. **Prevenção de Churn**
   - Alertas de inatividade
   - Pesquisa de satisfação
   - Win-back de cancelados

---

## 10. Métricas de Acompanhamento

### KPIs Semanais

| Métrica | Meta Semana 1 | Meta Semana 4 | Meta Semana 8 |
|---------|---------------|---------------|---------------|
| Instalações | 300 | 400 | 500 |
| Cadastros | 120 | 160 | 200 |
| Usuários ativos | 40 | 80 | 150 |
| Trials iniciados | - | 20 | 50 |
| Conversões | - | 5 | 15 |
| MRR | R$ 0 | R$ 300 | R$ 1.000 |

### Dashboard Necessário

```
┌─────────────────────────────────────────────────┐
│ MRR Atual: R$ 0 → Meta: R$ 1.000               │
│ ████████████████░░░░░░░░░░░░░░░░░░░░ 0%        │
├─────────────────────────────────────────────────┤
│ Clientes Pagantes: 0 → Meta: 15                │
│ Ticket Médio: R$ 0 → Projetado: R$ 83          │
│ Conversão Free→Pago: 0% → Meta: 10%            │
│ Churn: N/A → Meta: <5%                         │
└─────────────────────────────────────────────────┘
```

---

## 11. Riscos e Mitigações

| Risco | Probabilidade | Impacto | Mitigação |
|-------|---------------|---------|-----------|
| Usuários rejeitam paywall | Média | Alto | Paywall suave, trial gratuito |
| Conversão < 5% | Alta | Alto | A/B test, ajuste de gatilhos |
| Churn > 10% | Média | Médio | Onboarding forte, suporte |
| Comissão das lojas 30% | Certa | Médio | Migrar para PIX após escala |
| Concorrente mais barato | Baixa | Médio | Foco em valor, não preço |

---

## 12. Próximos Passos Imediatos

1. **Aprovar este plano** (Board)
2. **Criar issues técnicas** (CTO)
   - Issue: Implementar In-App Purchase
   - Issue: Tela de planos
   - Issue: Feature gates
3. **Definir timeline com Dev** (CTO)
4. **Preparar comunicação** (Marketing)
5. **Configurar analytics de billing** (Dev + Marketing)

---

## Anexo: Cálculos Detalhados

### Receita Líquida por Plano (após comissão das lojas)

| Plano | Preço | Comissão 30% | Comissão 15%* | Líquido Ano 1 | Líquido Ano 2+ |
|-------|-------|--------------|---------------|---------------|----------------|
| Starter | R$ 59 | R$ 17,70 | R$ 8,85 | R$ 41,30 | R$ 50,15 |
| Pro | R$ 119 | R$ 35,70 | R$ 17,85 | R$ 83,30 | R$ 101,15 |
| Business | R$ 249 | R$ 74,70 | R$ 37,35 | R$ 174,30 | R$ 211,65 |

*Small Business Program após 1 ano

### Breakeven para R$ 1K MRR Líquido (Ano 1)

- Starter: R$ 1.000 ÷ R$ 41,30 = **25 clientes**
- Pro: R$ 1.000 ÷ R$ 83,30 = **12 clientes**
- Mix: R$ 1.000 ÷ R$ 58,50 = **17 clientes**

**Meta ajustada: 17-20 clientes pagantes para R$ 1K MRR líquido**

---

**Documento criado por:** CEO Agent
**Revisão necessária:** Board
**Data de implementação planejada:** Abril 2026
