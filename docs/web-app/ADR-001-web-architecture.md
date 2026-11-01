# ADR-001: Arquitetura do app web

**Status:** aprovado pelo Rafael em 2026-10-31. A construção segue bloqueada até passar o Portão 0.
**Data:** 2026-10-31
**Evidência:** [`architecture-benchmarks.md`](architecture-benchmarks.md), [`business-rules-map.md`](business-rules-map.md), [`security-summary.md`](security-summary.md), [`business-red-team.md`](business-red-team.md).

## Decisão

Quando o web for construído, usar **Vue 3 + Vite, como SPA estática em `/app` no Firebase Hosting**, em pasta própria (`firebase/webapp/`). Nuxt continua servindo `/q`, `/pro` e `/admin`.

- **Leitura:** Firestore direto, para perfis que podem ver valores.
- **Leitura de quem não vê valores:** projeção da API.
- **Gravação de dinheiro, status e itens:** API, com a mesma regra para web e app.
- **Regras compartilhadas:** `docs/web-app/contract-cases/`, rodados contra Dart, Functions e web no CI.
- **Tokens:** uma fonte só, `firebase/hosting/src/css/tokens.css`.

Esta decisão diz **como** construir. **Se e quando** construir é outra decisão, tratada em [`discovery-report.md`](discovery-report.md).

## Opções medidas

Fast 4G, CPU 4x, 10 mil OS sintéticas, p75, build de produção.

| Critério | Flutter Web (melhor variante) | Nuxt como está | Nuxt enxuto | **Vue + Vite** |
|---|---|---|---|---|
| Lista visível, 1ª visita | 5.338 ms | 2.392 ms | 2.029 ms | **1.690 ms** |
| Lista visível, volta ao app | 1.927 ms | 1.563 ms | 1.369 ms | **580 ms** (cache primeiro) |
| INP sem / com leitor de tela | 124 / 200 ms | 168 ms | 32 ms | **32 ms** |
| 1ª visita em brotli | 2.751 KB | 1.309 KB | 181 KB | 194 KB |
| Ctrl+F e impressão com texto | Não | Sim | Sim | **Sim** |
| axe no protótipo | 3 violações com semântica, 58 ocorrências críticas | 2 | Não rodado | **0** |
| Cold start no caminho do HTML | Não | **Sim** (+1,8 s simulados) | **Sim** | **Não** |
| Código Dart reaproveitado | 7,8 mil linhas, zero de UI | 0 | 0 | 0 |
| Custo de manter (premissa do red team) | ~R$ 650/mês | ~R$ 1.250/mês | ~R$ 1.250/mês | ~R$ 1.250/mês |

## Por quê

**Flutter Web fica de fora.** O reuso é real, e é a maior vantagem dele: custo de manutenção perto da metade, sem duas verdades. Mas falha nas metas que justificam o projeto:

- 3,6 s a mais na primeira visita e INP acima da meta com leitor de tela.
- Sem Ctrl+F nem texto na impressão. Metade do valor de uma ferramenta de mesa é ser página de verdade.
- LCP não mede, então a meta de performance fica invisível em campo.
- Semântica é ligada por botão oculto. Leitor de tela no CanvasKit leva a rolagem a 38,5% de quadros lentos. WCAG AA fica caro.
- Reuso de UI é zero: as telas são Cupertino para telefone, então a tela de mesa seria nova de qualquer forma.

**Nuxt perde por pouco, e por entrega.** Depois de enxugado, empata em tudo menos no caminho do HTML. `praticos-web` escala a zero, com p75 de 2,4 s nas requisições dos últimos 14 dias. Para ficar no Nuxt seria preciso instância mínima (gasto recorrente) ou shell estático, e aí a entrega já é a da opção Vite. SSR não traz nada para tela autenticada.

**Vue + Vite, e não React ou outro.** Reaproveita 4,1 mil linhas de componentes Vue, tokens e o conhecimento já no repositório. Nenhuma alternativa traz ganho que pague ter dois frameworks web.

## Dados: como juntar as duas frentes

Os benchmarks recomendam Firestore direto. O mapa de regras recomenda API. Não há conflito depois de separar leitura e gravação:

| Operação | Caminho | Motivo |
|---|---|---|
| Listas e detalhe, quem vê valores | Firestore direto | Sem cold start, tempo real, cache. API não reduz leituras |
| Listas e detalhe, quem não vê valores | Projeção da API | `viewPrices` e `useFinancial` não existem nas regras |
| Pagamento, status, itens, totais | API | Regra e permissão ficam em um lugar. Evita perder itens com app e web abertos ao mesmo tempo |
| Cliente, veículo, catálogo, comentários | Firestore direto no início | Sem dinheiro. Mesmas regras do app |
| Cobrança, nota, equipe, convites | API existente | Já é assim |
| Busca global | Índice local no navegador | Ver abaixo |

**Busca global.** MiniSearch responde em 6,6 ms no p95. O difícil é montar o índice: 10 mil leituras e ~10 MB sem gzip na primeira carga, por REST com máscara de campos. Atualização por `updatedAt` usa o relógio do aparelho e não vê exclusão. Antes de escolher, vale lembrar que só uma empresa passa de 200 OS. O plano:

1. Varredura sobre o que já está carregado, mais `keywords` existentes, para quase todas as empresas.
2. Índice local só acima de um limite de OS, sem dados pessoais persistidos em computador compartilhado.
3. Projeção por empresa ou serviço externo só com aprovação. Projeção única vazaria OS e valores para técnico e consultor.

## Pré-requisitos

Estes itens exigem aprovação própria, porque mudam a API usada pelo app ou as regras:

1. `PATCH /v1/app/orders/:id` com transição validada por perfil.
2. `POST /v1/app/orders/:id/items`, com total calculado no servidor.
3. Regra única de quem recebe, em `/payments`.
4. Projeção de OS sem valores.
5. Contratos recorrentes em job agendado e idempotente. Hoje rodam ao abrir o app.
6. Limites de plano no servidor. Sem isso, o web vaza o Free.
7. Revisão de `firestore.rules` dentro da mesma empresa. Detalhe fora do repositório.

Sem 1 a 4, a fatia de escrita não sai. A fatia só de leitura precisa do item 4, ou fica restrita a quem vê valores.

## Consequências

**Boas:** site mais rápido, sem gasto recorrente novo, acessível de fábrica, sem SSR para manter, deploy junto com o Hosting.

**Ruins:**

- Duas bases de regra, Dart e TS, com ordem de 20 mil linhas em Dart. Parte não se aplica ao web, e a API absorve outra parte. Os casos de contrato limitam o risco, mas custam manutenção.
- Terceiro front no repositório (app, Nuxt, SPA).
- Mudança de tela no app pede decisão: repetir ou não no web.
- `firebase-hosting-deploy.yml` passa a compilar a SPA: mudança de CI, `risk:high`.

## O que não foi medido

Leitor de tela real (NVDA, VoiceOver), Firefox e Safari, GPU integrada de notebook comum (o M5 favorece o Flutter), economia real de cache, cold start real de `/app`, app Flutter completo em execução. Na opção Vite, a lista na 1ª visita em Fast 4G ainda erra a meta por 190 ms, por latência. O LCP do navegador passa (1.046 ms) porque credita o título, então a marca "lista visível" é a métrica a acompanhar.

## Rever esta decisão se

- O Portão 0 do red team falhar: nada é construído.
- O web tiver de ser só 3 telas sem meta de acessibilidade: o custo do Flutter volta a pesar.
- Um framework reduzir bastante a duplicação de regra, por exemplo gerando TS a partir de um contrato único.
