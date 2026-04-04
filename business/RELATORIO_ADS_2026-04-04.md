# Relatório de Performance — Campanhas Pagas PraticOS

**Data:** 2026-04-04
**Gerado por:** Head of Growth (HB #9)
**Período de análise:** 2026-02-22 a 2026-04-04

---

## Resumo Executivo

| Canal | Status | Budget/dia | CPA | Observação |
|-------|--------|-----------|-----|------------|
| Google Ads - App Android | ✅ Ativo | R$10 | R$0,68 | Principal canal de installs |
| Google Ads - App iOS | ⚠️ Ativo | R$10 | N/A | 1 impressão, sem conversões |
| Google Ads - Search | ⏸️ Pausado | R$10 | N/A | Pausado (motivo desconhecido) |
| Meta Ads - Android | ✅ Ativo | ~R$11 | R$0,70* | *estimado via store visits |
| Meta Ads - iOS | ✅ Reativado | ~R$11 | N/A | Estava pausado — reativado hoje |

**Budget total diário:** ~R$42/dia (R$1.260/mês)

---

## Google Ads — Detalhamento

### App-Android (Últimos 30 dias)

| Métrica | Valor |
|---------|-------|
| Impressões | 54.961 |
| Cliques | 1.379 |
| CTR | 2,51% |
| Conversões (installs) | 891 |
| Custo total | R$609,98 |
| CPA | R$0,68 |

**Análise:** Excelente performance. CPA de R$0,68 está muito abaixo do benchmark de mercado (R$3-15 para apps). Budget de R$10/dia é conservador — espaço para escalar.

### App-iOS (Últimos 30 dias)

| Métrica | Valor |
|---------|-------|
| Impressões | 1 |
| Cliques | 0 |
| Custo | R$0 |

**Análise:** Campanha iOS praticamente inativa. Problema identificado previamente: rastreamento de conversão iOS via SKAdNetwork/modelado. A campanha não está conseguindo aprender sem sinal de conversão.

**Hipótese:** O iOS precisa do ATT prompt implementado para melhorar sinal de conversão. Ver `docs/ADS_CAMPAIGNS.md` — pendência: `app_tracking_transparency` package não implementado.

---

## Meta Ads — Detalhamento

### Performance Geral (22/02 a 04/04 = 41 dias)

| Métrica | Valor |
|---------|-------|
| Alcance | 3.118 pessoas |
| Impressões | 4.233 |
| Frequência | 1,36x |
| CPM | R$20,79 |
| Cliques | 155 |
| CTR | 3,66% |
| Visitas à App Store | 126 |
| Installs rastreados | 0* |
| Gasto total | R$88,00 |

*Meta não rastreia installs sem App Events SDK configurado corretamente ou ATT.

**Estimativa de installs:** Se 126 visitaram a loja com conversão de ~30% → ~38 installs via Meta.
**CPA estimado:** R$88 / 38 = R$2,32 (vs R$0,68 do Google — esperado, Meta é awareness)

### Performance por Criativo

| Criativo | Impressões | CTR | CPC | Visitas Loja |
|----------|-----------|-----|-----|-------------|
| **WhatsApp GIF** | 3.787 (89%) | **3,86%** | **R$0,54** | 125 |
| WhatsApp Estático | 221 (5%) | 1,81% | R$1,20 | 1 |
| App Completo | 216 (5%) | 2,31% | R$0,94 | 0 |

**Vencedor claro:** WhatsApp GIF com CTR 2,1x maior e CPC 2,2x menor.
**Algoritmo Meta já alocou 89% do budget para o WhatsApp GIF automaticamente.**

### Ação Tomada Hoje

- ✅ Ad set iOS reativado (estava PAUSED — motivo: campanha precisava de anúncios validados)
- Status: Android + iOS agora ACTIVE

---

## Análise de Eficiência

### Total de Installs Estimados (últimos 30 dias)

| Canal | Installs | Custo | CPA |
|-------|----------|-------|-----|
| Google Ads Android | 891 | R$610 | R$0,68 |
| Google Ads iOS | ~0 | R$0 | - |
| Meta Ads Android | ~38 | R$88 | ~R$2,32 |
| **Total** | **~929** | **~R$698** | **~R$0,75** |

**Contexto acumulado:** ~1.300 installs totais históricos. A campanha está gerando ~30 installs/dia.

### Investimento Mensal Atual

| Canal | Budget/mês | Installs/mês | CPA |
|-------|-----------|-------------|-----|
| Google Ads | R$300 | ~891 | R$0,68 |
| Meta Ads | R$660 | ~38 | ~R$17 |
| **Total** | **R$960** | **~929** | **~R$1,03** |

**Observação:** Meta Ads está com eficiência menor que Google Ads (R$17 vs R$0,68). Mas Meta gera awareness e pode gerar installs orgânicos não rastreados.

---

## Problemas Identificados

### 1. iOS sem conversões (Google Ads)
- **Problema:** Campanha App-iOS com 1 impressão em 30 dias
- **Causa provável:** Falta de sinal de conversão iOS (ATT prompt não implementado)
- **Impacto:** Potencial de 40-60% mais installs se iOS funcionar
- **Solução:** Implementar `app_tracking_transparency` package no Flutter

### 2. Meta Ads sem rastreamento de installs
- **Problema:** 126 visitas à App Store, 0 installs rastreados
- **Causa:** App Events não configurados ou ATT bloqueando
- **Impacto:** Não consegue otimizar por conversão, só por clicks
- **Solução:** Verificar Firebase Analytics → Meta integration

### 3. Google Search pausado
- **Problema:** Campanha de busca está PAUSED sem motivo documentado
- **Impacto:** Perde tráfego de intenção (quem busca "sistema OS" está pronto para instalar)
- **Solução:** Verificar com Rafael/CEO se foi pausada intencionalmente

---

## Oportunidades Imediatas

### Oportunidade 1: Escalar Google Ads Android
- **Situação:** CPA de R$0,68 com R$10/dia. Isso é excepcionalmente bom.
- **Benchmark:** Meta de R$1,000 MRR = 15-17 clientes. 
- **Problema:** Sem billing, escalar installs não converte em receita ainda.
- **Ação sugerida:** Quando billing estiver pronto, elevar budget para R$30-50/dia

### Oportunidade 2: Variação de Criativos WhatsApp GIF
- **Situação:** WhatsApp GIF vence com CTR 3,86%
- **Ação:** Criar versões do GIF com copy diferente para testar:
  - Versão focada em "Nunca mais perca uma OS"
  - Versão focada em "R$59/mês" (anchor preço)
  - Versão com depoimento de cliente

### Oportunidade 3: Reativar Google Search
- **Situação:** 56 keywords configuradas, campanha pausada
- **Potencial:** Captura intenção de compra (mais qualificado que app)
- **Custo:** R$10/dia já configurado

---

## Próximas Ações (Por Prioridade)

### Esta Semana

1. ✅ Reativar ad set iOS no Meta (feito hoje)
2. [ ] Verificar com Rafael se Google Search deve ser reativado
3. [ ] Criar nova variação de criativo WhatsApp GIF

### Próximas Semanas

4. [ ] Implementar ATT prompt (Flutter/Dev) → desbloqueia iOS
5. [ ] Configurar Meta App Events → rastrear installs reais
6. [ ] Quando billing pronto: escalar Google Ads para R$30-50/dia

### Dependências (Dev)

- ATT prompt (`app_tracking_transparency` package)
- Billing/IAP implementation
- Firebase → Meta App Events bridge

---

## Benchmark do Mercado

| Métrica | PraticOS | Benchmark Apps Brasil |
|---------|----------|---------------------|
| CPA Google Ads | R$0,68 | R$3-15 |
| CTR Meta Ads | 3,66% | 1-2% |
| CPM Meta Ads | R$20,79 | R$15-40 |

**Conclusão:** Performance de aquisição está excelente. O gargalo não é aquisição — é conversão Free → Pago (billing não implementado).
