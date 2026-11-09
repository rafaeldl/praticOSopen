# SITE_STAGE_SCENES.md

## Visão Geral

Cenas do produto no site (Eleventy): telas do app desenhadas em React com o kit da skill
[Stageshow](../.claude/skills/stageshow/SKILL.md), animadas como uma demonstração. A primeira é o
hero da home: o iPhone com a tela "Nova OS", o toque em "Falar", a fala aparecendo e a IA
preenchendo cliente, veículo, serviços e total, com o ✦ e o aviso "Desfazer" do app.

Substitui as fotos e o cartão HTML que ficavam no hero. As fotos continuam nos dados
(`hero.tiles`), sem uso, até decidirmos o destino delas.

## Arquitetura

```
firebase/hosting/
├── stage/                      # Pacote React próprio (não entra no build do Eleventy)
│   ├── kit/                    # Cópia do kit do Stageshow (MIT, ver kit/LICENSE e kit/NOTICE.md)
│   ├── scenes/hero/            # HeroScene.tsx, hero.css, mount.tsx, REHEARSAL.md
│   ├── preview/index.html      # Prévia local da cena sobre o azul do hero
│   ├── vite.config.ts          # Build: uma entrada por cena → ../src/assets/stage/
│   └── vite.preview.config.ts  # Servidor da prévia (porta 5174)
└── src/assets/stage/           # Saída do build (hero.js, hero.css), commitada
```

- O build do site continua só com Eleventy: os arquivos de `src/assets/stage/` vão no commit.
  Mudou a cena, rode `npm run build` em `stage/` e commite a saída.
- Cada cena importa as peças do kit pelo arquivo (`../../kit/phone`), não pelo `kit/index.ts`,
  que puxaria o CSS de todas as peças. O hero fica em ~69 KB gzip de JS (a maior parte é React)
  e ~10 KB de CSS, carregados só na home.
- Cores dentro da cena são as do app (`lib/theme/app_colors.dart`), modo claro.

## Fluxo de Dados

```
_data/homepage.json → hero.stage (pt, en, es)
        ↓  {{ hero.stage | dump }} num <script type="application/json">
components/hero.njk → <div data-stage="hero">
        ↓  assets/stage/hero.js (mount.tsx)
HeroScene (Stage + Phone do kit)
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
```

Nova cena: crie `scenes/<nome>/` com o componente e um `mount.tsx`, some a entrada em
`vite.config.ts` e monte no template com `<div data-stage="<nome>">`.
