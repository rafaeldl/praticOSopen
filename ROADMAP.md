# Roadmap PraticOS

> Fonte única de prioridade. Agentes e humanos trabalham a partir daqui.
> Contexto e racional: [`business/DISCOVERY_AUTONOMIA.md`](business/DISCOVERY_AUTONOMIA.md).
> Atualizado: 2026-10-04

**Métrica norte:** empresas ativas por semana (≥1 OS nos últimos 7 dias). Base em 2026-10-04: **27** (13 com uso recorrente/regular; 1 delas é a âncora da família).
**Direção do trimestre:** gerar a primeira receita recorrente.

---

## Agora (máx. 3)

1. **Base para trabalho autônomo** — testes no CI, template de issue, labels `agent-ready` / `risk:*`, regras do modo autônomo no `CLAUDE.md`, rotina diária de engenharia.
2. **Validar disposição a pagar** — conversar com as 12 empresas de uso real (lista privada), landing de pré-venda para cobrança na OS + NFS-e e para IA.
3. **Ativação e retenção** — só ~1/3 das empresas cadastradas segue ativa; descobrir onde as novas (~84/mês, orgânicas) abandonam.

## Próximo

- **Cobrança na OS (Pix/cartão) via Asaas com split** — receita por transação, fora do IAP da Apple.
- **NFS-e integrada** (Asaas).
- **Plano Pro com IA** — OS por áudio/foto, orçamento sugerido, mensagem pronta para o cliente; MCP (ChatGPT/Claude) como recurso Pro.
- **IAP no iOS configurado de verdade** (produtos na App Store + RevenueCat) para reabrir planos no iOS.
- **Canal Omie.Store** (loja de apps da Omie cobra o app junto com a mensalidade dela) — #198. Depois, Bling.

## Depois

- MCP fases 2–4 (OAuth, diretórios do ChatGPT/Claude, RBAC) — #267.
- Portal web (#192 / PR #194).
- Oportunidades / marketplace de leads.
- Assistente no WhatsApp como add-on pago (só com ≥5 interessados).

## Feito

- 2026-10-04: bot do WhatsApp desligado (VM e disco apagados; conversas em `gs://praticos-bot-archive`). Google Ads pausado.

## Fora (decidido não fazer agora)

- Bot do WhatsApp gratuito — custo de VM + LLM sem receita.
- Novos limites de plano (fotos/formulários) como gatilho principal de upgrade.
