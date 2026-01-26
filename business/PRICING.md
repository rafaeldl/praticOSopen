# 💰 Precificação PraticOS

**Data:** 2026-01-25  
**Status:** ✅ Aprovado  
**Cobrança:** App Store / Google Play (assinatura mensal)

---

## Planos

| | **Free** | **Starter** | **Pro** | **Business** |
|--|----------|-------------|---------|--------------|
| **Preço** | R$ 0 | R$ 59/mês | R$ 119/mês | R$ 249/mês |
| **Usuários inclusos** | 1 | 2 | 3 | 5 |
| **Usuário extra** | ❌ | +R$ 25/mês | +R$ 29/mês | +R$ 35/mês |
| **Fotos/mês** | 30 | 200 | 1.000 | ∞ |
| **Formulários** | 1 | 3 | 10 | ∞ |
| **PDF** | Marca d'água | ✅ Limpo | ✅ Limpo | ✅ Limpo |
| **Multi-empresa** | ❌ | ❌ | ❌ | ✅ |
| **API** | ❌ | ❌ | ❌ | ✅ |

---

## Sem limites (todos os planos)

- ∞ Clientes
- ∞ Equipamentos
- ∞ Ordens de Serviço
- ∞ Histórico
- ✅ Financeiro completo
- ✅ Relatórios e Dashboard
- ✅ Link mágico para cliente

---

## Gatilhos de Upgrade

| De → Para | Gatilho |
|-----------|---------|
| Free → Starter | Mais fotos, mais formulários, ou remover marca d'água |
| Starter → Pro | Mais usuários, mais fotos, mais formulários |
| Pro → Business | API, multi-empresa, ou escala de usuários |

---

## Exemplos de Preço

| Perfil | Plano | Usuários | Cálculo | Total |
|--------|-------|----------|---------|-------|
| Autônomo | Free | 1 | R$ 0 | **R$ 0** |
| MEI crescendo | Starter | 2 | R$ 59 | **R$ 59** |
| Pequena empresa | Starter | 4 | R$ 59 + (2 × R$ 25) | **R$ 109** |
| Pequena empresa | Pro | 5 | R$ 119 + (2 × R$ 29) | **R$ 177** |
| Empresa média | Pro | 8 | R$ 119 + (5 × R$ 29) | **R$ 264** |
| Empresa média | Business | 10 | R$ 249 + (5 × R$ 35) | **R$ 424** |

---

## Diferenciais Competitivos

1. ✅ **Preços públicos** — 90% dos concorrentes escondem
2. ✅ **Plano grátis real** — Funcional, não só trial
3. ✅ **Aceita 1 usuário** — Contele exige mínimo 4
4. ✅ **Self-service** — Sem demo obrigatória
5. ✅ **Sem limite de clientes/OS** — Generoso vs concorrência

---

---

## Produtos nas Lojas (Subscription)

| ID do Produto | Plano | Preço | Líquido (~15%) |
|---------------|-------|-------|----------------|
| `starter_monthly` | Starter | R$ 59/mês | ~R$ 50 |
| `pro_monthly` | Pro | R$ 119/mês | ~R$ 101 |
| `business_monthly` | Business | R$ 249/mês | ~R$ 212 |

**Nota:** Comissão das lojas = 30% (primeiro ano) → 15% (após 1 ano no Small Business Program)

---

## Próximos Passos

- [ ] Criar produtos de assinatura na App Store
- [ ] Criar produtos de assinatura no Google Play
- [ ] Integrar `in_app_purchase` no Flutter
- [ ] Implementar controle de fotos/mês
- [ ] Implementar limite de formulários por plano
- [ ] Adicionar marca d'água no PDF (plano Free)
- [ ] Tela de upgrade/planos no app
