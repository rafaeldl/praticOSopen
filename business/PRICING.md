# Precificação PraticOS

**Data:** 2026-11-13
**Status:** Aprovado (épico #721). Código na master desde 13/11/2026, atrás de `config/paidPlans.enabled` desligada. Substitui a tabela de 2026-11-05.
**Cobrança:** App Store e Google Play (mensal ou anual); pela web com Asaas (#664), atrás de `config/webCheckout.enabled`.
**Fonte única dos números:** `docs/plans/plans.json`. Este arquivo explica o porquê; se divergir, vale o JSON.

---

## Planos

Cada plano é uma fase do negócio. O plano exigido é o maior entre OS por mês, pessoas e CNPJs da nota.

| | Grátis | Starter | Pro | Business |
|---|---|---|---|---|
| **Para quem** | Está começando | Autônomo | Equipe pequena | Empresa |
| **Preço por mês** | R$ 0 | R$ 59,90 | R$ 119,90 | R$ 249,90 |
| **Anual (paga 10 meses)** | - | R$ 599 | R$ 1.199 | R$ 2.499 |
| **OS por mês** | 10 | 50 | 150 | 500 |
| **Pessoas** | 1 | 2 | 5 | 20 |
| **CNPJs na nota** | - | 1 | 2 | sem limite |
| **Fotos** | sem limite | sem limite | sem limite | sem limite |
| **IA** | incluída | incluída | incluída | incluída |

Acima de 20 pessoas ou de 500 OS por mês: "Fale com a gente" (proposta de pacotes extras na #737).

**Recursos, "tudo do plano anterior, mais":**

- **Grátis:** OS, clientes, catálogo, agenda, financeiro, orçamento pelo WhatsApp e link, aprovação pelo link, checklists do ramo, IA, celular e computador. PDF com a marca PraticOS.
- **Starter:** nota fiscal (1 CNPJ), PDF só com a sua marca, checklists próprios, cobrança e lembrete, pedir avaliação.
- **Pro:** perfis e permissões, agenda e responsável por pessoa, etapas, Modo TV, contratos, IA no financeiro, relatório em planilha, 2 CNPJs.
- **Business:** ações em lote, ChatGPT/Claude e API, CNPJs sem limite.

Nunca bloquear o básico: abrir OS, mandar ao cliente, aprovação pelo link, agenda e importar dados ficam em todos os planos.

---

## Regras

### OS e pessoas
- Limite suave: aviso a 80% e 100%, um mês de folga (olha o mês anterior), nunca trava OS aberta.

### IA
- Incluída em todos os planos, sem contador para o cliente; uso justo nos termos.
- Teto interno contra abuso: **50 / 1.000 / 3.000 / 6.000 usos por mês**; por dia, 20 no Grátis e 200 no Starter e no Pro. No teto, a IA pausa sem cobrar.
- Custo estimado: ~R$ 0,004 por uso no Haiku (padrão).

### Nota fiscal (NFS-e direta)
- Notas ilimitadas; o limite é por CNPJ emissor (issue #574).

### Transição
- Empresa nova nasce no Grátis, sem teste. No lugar, garantia de 7 dias com dinheiro de volta (na App Store o reembolso é decisão da Apple).
- Quem já assina e a cortesia (até 07/12/2026) mantêm o que têm (tabela versão 1). Até a chave ligar, compra e troca de plano também gravam a versão 1.

---

## Gatilhos de upgrade

| De → Para | Gatilho |
|---|---|
| Grátis → Starter | 11ª OS no mês, nota fiscal, PDF com a sua marca, checklists próprios |
| Starter → Pro | 51ª OS, terceira pessoa, segundo CNPJ, perfis, etapas, contratos |
| Pro → Business | 151ª OS, sexta pessoa, terceiro CNPJ, ações em lote, ChatGPT/Claude, API |

---|---|
| Free → Starter | Passar de 10 OS no mês, IA sem limite de amostra, PDF sem marca, nota fiscal |
| Starter → Pro | Terceira pessoa, segundo CNPJ, IA financeira, contratos |
| Pro → Business | Sexta pessoa, terceiro CNPJ, ChatGPT e Claude, API |

---

## Por que assim

- **Fotos não separam ninguém.** Quase nenhum usuário chegava no limite, a foto custa quase nada e quase nenhum concorrente limita quantidade.
- **OS separa quem testa de quem usa.** Na base ativa, poucas empresas passam de 50 OS por mês, então limite de OS acima do Free não muda a decisão de ninguém. 10 OS por mês é o grátis do nicho (ReparoPRO, AutoERP).
- **IA com cota atrapalha.** 150 usos dão para cerca de 60 OS, menos que o uso normal. Nenhum concorrente de campo publica cota de assistente em plano pago.
- **Nota no Starter é vantagem.** A ReparoPRO só inclui nota no plano de R$ 119,90.

---

## Concorrentes brasileiros (preços públicos lidos em 02/11 e 05/11/2026)

| Concorrente | Entrada | Meio | Topo | Observação |
|---|---|---|---|---|
| ReparoPRO | R$ 49,90 (1 login, sem nota) | R$ 69,90 (3) | R$ 119,90 (10 logins, com nota) | Grátis: 10 OS e 5 orçamentos por mês |
| Portal Técnico | R$ 49,90 (2 usuários, 100 OS) | R$ 99,90 (5, OS sem limite) | R$ 149,90 (usuários ilimitados, IA) | Ver abaixo |
| OrdemCerta | R$ 49 | - | - | Plano único; dado de trecho de busca |
| AutoERP | R$ 99,90 (2 usuários) | até 5 (preço não encontrado) | - | Grátis: 10 OS, sem fotos |
| byTechOS | R$ 89 (~80 OS) | R$ 149 | R$ 249 a R$ 349 | Usuários ilimitados em todos |
| Oficina Integrada | R$ 129 (MEI, 1) | R$ 185 (2) | R$ 339 a R$ 379 | Por faixa de usuários |
| Multi Foco | R$ 50 por usuário | R$ 35 por usuário (3+) | - | Gestor não paga |
| Field Control | R$ 525 (3 técnicos) | R$ 759 | - | Licença por técnico |

**Portal Técnico Premium (R$ 149,90):** usuários e OS ilimitados, robô com IA no WhatsApp, copiloto e diagnóstico com Gemini, catálogo, DRE, auditoria e suporte prioritário. Não encontramos cobrança extra publicada nem nota fiscal. É sistema web (PWA instalável); não encontramos app nas lojas.

**Leitura:**
- **Starter:** R$ 10 acima do piso do nicho, mas o único com nota e IA nessa faixa.
- **Pro:** a ReparoPRO dá 10 logins pelo mesmo preço. Se a equipe pesar na venda, o ajuste mais barato é dar mais pessoas sem mudar o preço.
- **Business:** perde para o Portal Técnico Premium em preço e pessoas. Ganha em nota com vários CNPJs, app nativo, ChatGPT e Claude e API.

---

## Produtos nas lojas

| ID | Plano | Preço |
|---|---|---|
| `praticos_starter_monthly` / `praticos_starter_annual` | Starter | R$ 59,90 / R$ 599 |
| `praticos_pro_monthly` / `praticos_pro_annual` | Pro | R$ 119,90 / R$ 1.199 |
| `praticos_business_monthly` / `praticos_business_annual` | Business | R$ 249,90 / R$ 2.499 |

O servidor já reconhece os IDs anuais; falta conferir se os produtos anuais existem no App Store Connect e no Google Play. Comissão das lojas: 15% no Small Business Program.

---

## Próximos passos

- [ ] Limites novos no servidor e no app: 10 OS no Free, tetos internos, fim do limite de fotos e de checklists contados.
- [ ] Travas por função: checklist próprio, CNPJs da nota (#574), contratos, ChatGPT e Claude.
- [ ] Tela do plano e textos do paywall com a tabela nova.
- [ ] Página de preços no site: um quadro por plano, "tudo do plano anterior, mais", tema Campo, chave mensal e anual. Só vai ao ar com os limites no app.
- [ ] Tirar "sem limite de OS nem de clientes" do FAQ dos segmentos no site.
- [ ] Abrir o app no computador para todos (hoje fechado por lista de acesso).
- [ ] Conferir `Purchase Options` no App Store Connect (venda em quantidade vem ligada por padrão).
- [ ] A mudança precisa sair numa versão antes do aviso de fim da cortesia; senão, mudar o aviso e a data de corte junto.
