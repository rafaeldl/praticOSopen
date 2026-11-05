# Precificação PraticOS

**Data:** 2026-11-05
**Status:** Aprovado, ainda não implementado. Substitui a tabela de 2026-01-25 (fotos e usuário extra).
**Cobrança:** App Store e Google Play (assinatura mensal ou anual). Preços mantidos.

---

## Planos

| | Free | Starter | Pro | Business |
|---|---|---|---|---|
| **Para quem** | Testar ou fazer bico | Autônomo que vive do serviço | Oficina ou assistência organizada | Equipe grande |
| **Preço por mês** | R$ 0 | R$ 59,90 | R$ 119 | R$ 249 |
| **Anual (paga 10 meses)** | - | R$ 599 | R$ 1.190 | R$ 2.490 |
| **OS** | 10 por mês | incluída | incluída | incluída |
| **Pessoas** | 1 | 2 | 5 | 20 |
| **Fotos** | sem limite | sem limite | sem limite | sem limite |
| **IA na OS** | 10 usos por mês | incluída | incluída | incluída |
| **PDF sem marca** | não | sim | sim | sim |
| **Checklists prontos do ramo** | sim | sim | sim | sim |
| **Checklists próprios** | não | sim | sim | sim |
| **Nota fiscal de serviço** | não | 1 CNPJ | até 2 CNPJs | CNPJs sem limite |
| **IA financeira** | não | não | sim | sim |
| **Contratos recorrentes** | não | não | sim | sim |
| **App no computador** | sim | sim | sim | sim |
| **Conectar ao ChatGPT e Claude** | não | não | não | sim |
| **API** | não | não | não | sim |

Acima de 20 pessoas: **sob consulta**, em torno de R$ 30 por pessoa. Por enquanto é só uma frase na página ("Mais de 20 pessoas? Fale com a gente"); nada é construído antes de aparecer um cliente assim.

**Em todos os planos:** OS e orçamento, clientes, aparelhos, catálogo, agenda, financeiro e link para o cliente.

**Quadro "tudo do plano anterior, mais":**

- **Free:** 10 OS por mês, 1 pessoa, fotos sem limite, 10 usos de IA, app no computador, checklists do ramo.
- **Starter = Free +** OS incluídas, 2 pessoas, IA incluída, PDF sem marca, checklists próprios, nota fiscal por 1 CNPJ.
- **Pro = Starter +** 5 pessoas, nota por até 2 CNPJs, IA financeira, contratos recorrentes.
- **Business = Pro +** 20 pessoas, CNPJs sem limite, conexão com ChatGPT e Claude, API.

---

## Regras

### OS
- Limite visível só no Free: 10 OS por mês. Aviso na 8ª e 3 OS de folga depois da 10ª, para não travar no meio do serviço. OS antigas seguem editáveis.
- Nos pagos, a OS é "incluída", com uso justo nos termos (nunca "ilimitado"). Teto interno contra abuso: **500 / 2.000 / 5.000 OS por mês** (Starter / Pro / Business). No teto, a pessoa fala com o suporte, sem perder o que fez.

### IA
- Free: 10 usos por mês, como amostra.
- Pagos: incluída, sem contador visível. Teto interno: **1.000 / 3.000 / 6.000 usos por mês**, com 200 por dia no Starter e no Pro (Business sem teto diário). No teto, a IA pausa sem cobrar e o resto do app segue normal.
- Custo medido em 02/11/2026: cerca de R$ 0,03 por OS no Gemini 2.5 Flash (2,5 usos por OS) e cerca de R$ 0,004 no Claude Haiku 5.5 (estimativa pelo preço oficial). Haiku será o padrão no futuro; áudio segue no Gemini.
- Crédito de IA comprado pela loja não pode expirar na Apple (3.1.1), por isso não há pacote de IA avulso.

### Nota fiscal (NFS-e direta, Emissor Nacional)
- Notas ilimitadas; o limite é por **CNPJ emissor** (certificado A1 de cada um). Regras na issue #574.
- Free: "Emitir nota" abre a tela do plano. Starter: o segundo CNPJ pede o Pro. Pro: o terceiro pede o Business.
- Quem baixa de plano mantém os emitentes, mas só emite pelo padrão. O piloto é liberado por chave, sem depender do plano.
- Esta regra substitui a decisão 13 de `docs/superpowers/specs/2026-11-05-nfse-direta-design.md` (Pro com CNPJs ilimitados).

### Fora da tabela por enquanto
- **Asaas:** sem nota pelo Asaas e sem cobrança por Pix, boleto ou cartão.
- **Usuário extra:** sai da tabela. Compra por assento nas lojas ainda não abriu de vez, e a terceira pessoa já leva ao Pro.
- **Várias empresas numa assinatura:** cada empresa tem a própria assinatura.

### Transição
- Empresa nova começa com 30 dias de Pro.
- Quem já assina mantém o que tem.

---

## Gatilhos de upgrade

| De → Para | Gatilho |
|---|---|
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
| `praticos_pro_monthly` / `praticos_pro_annual` | Pro | R$ 119 / R$ 1.190 |
| `praticos_business_monthly` / `praticos_business_annual` | Business | R$ 249 / R$ 2.490 |

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
