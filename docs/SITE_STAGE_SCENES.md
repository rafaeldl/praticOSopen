# SITE_STAGE_SCENES.md

## Visão Geral

Cenas do produto no site (Eleventy): telas do app desenhadas em React com o kit da skill
[Stageshow](../.claude/skills/stageshow/SKILL.md), animadas como uma demonstração. A primeira é o
hero da home: o iPhone com a tela "Nova OS", o toque em "Falar", a fala aparecendo e a IA
preenchendo cliente, veículo, serviços e total, com o ✦ e o aviso "Desfazer" do app.

As abas de "Como funciona" usam o mesmo kit, com uma tela parada por aba: corrigir falando
("o alinhamento é 100"), checklist de entrada com fotos, a OS aberta no celular do cliente com
"Aprovar orçamento", a Agenda com o lembrete chegando e o Financeiro com quem deve e o botão de
cobrança.

**Em teste (2026-11-09):** o hero é o de fotos com o cartão da fala. Com `?hero=app` na home,
o cartão dá lugar ao celular da Nova OS em versão curta (só cliente, veículo e serviços,
`data-short` na cena), sobre as mesmas fotos, e a aba "Falar" volta para a tela parada da correção.
Sem o parâmetro, a aba "Falar" toca a mesma animação curta. Em português, com `flags.nfsePage`, a
última aba é "Nota fiscal" (`homepage.json` → `pt.nfse.tab`, cena `invoice`).

## Arquitetura

```
firebase/hosting/
├── stage/                      # Pacote React próprio (não entra no build do Eleventy)
│   ├── kit/                    # Cópia do kit do Stageshow (MIT, ver kit/LICENSE e kit/NOTICE.md)
│   ├── scenes/hero/            # HeroScene.tsx, hero.css, mount.tsx, REHEARSAL.md
│   ├── scenes/tabs/            # TabScenes.tsx (5 telas paradas), tabs.css, mount.tsx, REHEARSAL.md
│   ├── preview/index.html      # Prévia do hero sobre o azul do hero
│   ├── preview/tabs.html       # Prévia das 5 abas (?only=talk|record|approve|schedule|receive)
│   ├── vite.config.ts          # Build: uma entrada por cena → ../src/assets/stage/
│   └── vite.preview.config.ts  # Servidor da prévia (porta 5174)
└── src/assets/stage/           # Saída do build, commitada: shared.js e shared.css (React, kit
                                # e o CSS de todas as cenas) + hero.js e tabs.js (poucos KB cada)
```

- O build do site continua só com Eleventy: os arquivos de `src/assets/stage/` vão no commit.
  Mudou a cena, rode `npm run build` em `stage/` e commite a saída.
- Cada cena importa as peças do kit pelo arquivo (`../../kit/phone`), não pelo `kit/index.ts`,
  que puxaria o CSS de todas as peças. Hero e abas juntos dão ~70 KB gzip de JS (a maior parte
  é React) e ~10 KB de CSS, carregados só na home. A página linka `shared.css` uma vez e o
  módulo de cada cena.
- Cores dentro da cena são as do app (`lib/theme/app_colors.dart`), modo claro.

## Fluxo de Dados

```
_data/homepage.json → hero.stage (pt, en, es)
        ↓  {{ hero.stage | dump }} num <script type="application/json">
components/hero.njk → <div data-stage="hero">
        ↓  assets/stage/hero.js (mount.tsx)
HeroScene (Stage + Phone do kit)

_data/homepage.json → workflow.stages[i].scene (kind: talk | record | approve | schedule | receive)
        ↓  components/workflow.njk → <div data-stage="tab" data-icon="…logo-96.png">
assets/stage/tabs.js → TabScene
```

Os textos da cena (`hero.stage`) vêm das strings reais do app (`lib/l10n/app_*.arb`): "Ouvindo…",
"Desfazer", "O que vai ser feito", "Preenchi o que está marcado. Confira e salve." etc. O total
é uma lista (`totals`) com o valor depois de cada item, já formatado por idioma.

## Regras de Negócio

- A cena toca uma vez quando aparece na tela e para no quadro final (`play="once"`).
  O link "Ver de novo" (`data-stage-replay="hero"`) remonta a cena.
- Com "reduzir movimento" ligado, mostra direto o quadro final (`poster`).
- Só mostra o que o app faz: a IA preenche cliente, veículo e itens; "Fica pronto" e
  "O que o cliente pediu" ficam vazios.
- As abas são telas paradas (sem animação): só o hero se move na página.
- Cada aba mostra um momento diferente do hero, para a página não repetir a mesma cena.

## Exemplos de Uso

```bash
cd firebase/hosting/stage
npm install
npm run dev          # prévia em http://127.0.0.1:5174 (?lang=en|es)
npm run typecheck
npm run build        # gera ../src/assets/stage/

# Filmar e passar no gate da skill (pede o Chrome instalado e o npm install da skill)
node ../../../.claude/skills/stageshow/scripts/film.mjs 'http://127.0.0.1:5174/' \
  --select '.ph-hero' --states --states-for 16000 --gate
node ../../../.claude/skills/stageshow/scripts/film.mjs 'http://127.0.0.1:5174/' \
  --select '.ph-hero' --states --states-for 16000 --gate --width 390
node ../../../.claude/skills/stageshow/scripts/film.mjs 'http://127.0.0.1:5174/tabs.html' \
  --select '.ph-tab' --still --gate --width 2300
node ../../../.claude/skills/stageshow/scripts/film.mjs 'http://127.0.0.1:5174/tabs.html' \
  --select '.ph-tab' --still --gate --width 406
```

Nova cena: crie `scenes/<nome>/` com o componente e um `mount.tsx`, some a entrada em
`vite.config.ts` e monte no template com `<div data-stage="<nome>">`, `shared.css` e o módulo
da cena.
