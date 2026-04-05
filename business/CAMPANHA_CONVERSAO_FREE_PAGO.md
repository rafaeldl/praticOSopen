# Plano de Campanhas de Conversão Free → Pago

**Criado por:** Head of Growth
**Data:** 2026-04-04
**Status:** PRONTO PARA ATIVAR — aguardando billing (IAP + RevenueCat)
**Referência:** Issue #2eb5dbde

---

## Contexto

Com o billing em implementação ativa (RevenueCat + IAP), precisamos ter tudo
pronto para ativar campanhas de conversão no dia que o sistema for ao ar.

**Meta:** 15–17 pagantes = R$1.000 MRR
**Planos alvo:** Starter R$59, Pro R$119

---

## Checklist de Pré-Lançamento (Growth)

### Antes de Ativar Qualquer Campanha

- [ ] IAP funcionando em produção (iOS + Android)
- [ ] Tela de planos publicada no app
- [ ] Feature gates ativos (limites reais funcionando)
- [ ] RevenueCat recebendo webhooks corretamente
- [ ] Evento de compra trackado no Firebase Analytics
- [ ] Evento de compra trackado no Google Ads (conversion action)
- [ ] Evento de compra trackado no Meta Ads (pixel)

### Assets de Growth Já Prontos

- [x] `PERSONAS.md` — 4 personas definidas
- [x] `EMAIL_SEQUENCES.md` — 13 emails (onboarding, upgrade, re-engajamento)
- [x] `CONTEUDO_ROI.md` — 10 posts + calculadora de ROI
- [x] `POSICIONAMENTO_COMPETITIVO.md` — guia de objeções
- [x] `pricing.html` — página de preços publicada
- [x] Landing pages de segmento — 17 segmentos em 3 idiomas

---

## Campanha 1: In-App Upgrade (Limite Atingido)

**Canal:** Push notification + tela in-app
**Gatilho:** Usuário atingiu 80% ou 100% do limite do plano Free
**Objetivo:** Converter Free → Starter (R$59)

### Mensagem — 80% do Limite

**Push notification:**
> "Você está usando 80% das suas fotos. Upgrade para continuar sem interrupção."

**Tela in-app (modal):**
```
Você usou 24 de 30 fotos do mês.

Quando chegar no limite, novas fotos ficam bloqueadas.

Para continuar sem parar:
  ✅ Starter — R$59/mês
  • 200 fotos/mês
  • PDF sem marca d'água
  • Suporte WhatsApp

[Fazer Upgrade]   [Continuar com Free]
```

### Mensagem — Limite Atingido (100%)

**Push notification:**
> "Limite de fotos atingido. Assine o Starter para continuar."

**Tela in-app (tela cheia, bloqueio):**
```
Você atingiu o limite do plano Free.

Não é possível adicionar mais fotos este mês.

Para continuar seu trabalho:
  🚀 Starter — R$59/mês
  • Fotos ilimitadas
  • OS ilimitadas
  • PDF profissional

[Assinar Agora — R$59/mês]
─────────────────────
[Ver todos os planos]
```

**Taxa de conversão esperada:** 15–25% no momento de bloqueio

---

## Campanha 2: Emails de Upgrade (RevenueCat Webhook → Firebase → Email)

**Canal:** Email (Brevo ou Customer.io)
**Gatilho:** Firebase Function detecta usuário perto do limite
**Sequência:** Ver `EMAIL_SEQUENCES.md` — Emails 8 e 9

### Fluxo Técnico

```
RevenueCat webhook → Firebase Function → 
  if (photos_used >= 0.8 * limit) → enviar Email 8
  if (photos_used >= limit) → enviar Email 9
```

### Configuração Brevo (gratuito até 300/dia)

```
API Key: [configurar]
Lista: "PraticOS Free Users"
Segmento: "Próximos do Limite"
Template: Email 8 e Email 9 do EMAIL_SEQUENCES.md
```

---

## Campanha 3: Google Ads — Campanha de Conversão (Upgrade)

**Canal:** Google Ads — nova campanha Search
**Objetivo:** Converter usuários que pesquisam "melhor plano" ou "upgrade"
**Budget:** R$20/dia (adicional ao budget de install atual)

### Keywords-alvo

```
[EXACT] praticos upgrade
[EXACT] praticos plano pago
[PHRASE] "app ordem de serviço plano"
[PHRASE] "sistema OS premium"
[BROAD] melhor plano para assistência técnica
[BROAD] vale a pena pagar sistema OS
```

### Anúncio

**Headline 1:** PraticOS Starter — R$59/mês
**Headline 2:** OS Ilimitadas. PDF Profissional.
**Headline 3:** Sem Contrato. Cancel Quando Quiser.
**Descrição 1:** Fotos ilimitadas, link mágico, suporte por WhatsApp. Cancele quando quiser.
**Descrição 2:** 15x mais barato que Contele. Sem fidelidade. Comece agora.

**URL:** praticos.web.app/pricing.html

---

## Campanha 4: Meta Ads — Retargeting de Usuários Ativos

**Canal:** Meta Ads — novo ad set de retargeting
**Audiência:** Custom Audience de usuários que abriram o app nos últimos 30 dias
**Objetivo:** APP_PROMOTION (compra, não install)
**Budget:** R$15/dia

### Criativos para Retargeting

**Ad 1 — Limite próximo:**
> "Você está usando o PraticOS. Que tal tirar o máximo dele?
> Starter: fotos ilimitadas, PDF profissional, suporte WhatsApp.
> R$59/mês. Menos de R$2/dia."

**Ad 2 — ROI:**
> "Nossos usuários Starter relatam:
> • -70% em ligações desnecessárias
> • R$400–900/mês recuperados em produtividade
> R$59/mês. ROI de 15x."

**Configuração técnica:**
- Custom Audience: App Activity (opened app, last 30 days)
- Exclusão: Custom Audience de pagantes (App Activity: purchase)
- CTA: "Ver Planos"

---

## Campanha 5: WhatsApp Bot — Upsell Contextual

**Canal:** WhatsApp Bot (já implementado)
**Gatilho:** Usuário cria OS número 45 (próximo do limite de 50 do Free)
**Mensagem automática:**

```
📊 Você já criou 45 OS no PraticOS!

Está indo bem. Mas o plano Free tem limite de 50 OS/mês.

Para continuar sem parar:

→ Starter: R$59/mês
   • OS ilimitadas
   • Fotos ilimitadas
   • PDF sem marca d'água

Digite PLANOS para ver todos os detalhes,
ou ASSINAR para fazer o upgrade agora.
```

---

## Métricas de Sucesso

### KPIs Primários

| Métrica | Meta Mês 1 | Meta Mês 3 |
|---------|-----------|-----------|
| Conversões Free→Starter | 10 | 30 |
| Conversões Free→Pro | 3 | 10 |
| MRR | R$590 | R$2.000 |
| Taxa de conversão app | 3% | 5% |

### KPIs Secundários

| Métrica | Meta |
|---------|------|
| Taxa abertura email upgrade | 40% |
| Taxa clique email upgrade | 15% |
| CTR anúncio retargeting | 5%+ |
| Taxa conversão tela de planos | 8% |

---

## Cronograma de Ativação

### Dia 0 (Billing Live)
- [ ] Verificar IAP funcionando (fazer compra de teste)
- [ ] Ativar emails 8 e 9 (Firebase Function + Brevo)
- [ ] Ativar mensagem WhatsApp Bot no OS #45

### Semana 1
- [ ] Criar Custom Audience no Meta (usuários ativos)
- [ ] Criar campanha retargeting Meta (Ad set: usuários ativos - pagantes)
- [ ] Monitorar taxa de conversão da tela de planos

### Semana 2
- [ ] Lançar Google Ads campanha de upgrade (se MRR > R$200)
- [ ] A/B test: tela de planos com 2 layouts diferentes
- [ ] Analisar funil: quem chega ao limite vs quem converte

### Mês 2
- [ ] Otimizar emails baseado em dados reais
- [ ] Escalar Meta retargeting se ROAS > 3x
- [ ] Testar preço anual vs mensal

---

## Dependências Técnicas

| Item | Responsável | Status |
|------|-------------|--------|
| IAP (App Store + Google Play) | Dev/CTO | In Progress |
| RevenueCat webhooks | Dev/CTO | In Progress |
| Feature gates (limites reais) | Dev/Flutter | In Progress |
| Tela de planos | Dev/Flutter | Todo |
| Firebase Function para email | Dev | Pendente |
| Brevo configurado | Growth | Pendente |
| Meta Custom Audience (app) | Growth | Pendente (depende de App Events) |
| Google Ads conversion action (purchase) | Growth | Pendente |
