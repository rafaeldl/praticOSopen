# WEB_APP.md

## Visão Geral

O app web do PraticOS é a ferramenta de mesa para as mesmas contas e os mesmos dados do app móvel. Quem entra no computador vê as mesmas OS, clientes, agenda e dinheiro, com as mesmas permissões, e o que muda num lado aparece no outro.

| | |
|---|---|
| Endereço | **https://praticos.app/web** (ver [Domínios](#domínios)) |
| Código | `firebase/webapp/` (Vue 3 + Vite, SPA estática, TypeScript) |
| Acesso | Fechado por lista de acesso (`config/webApp`, ver [Lista de acesso](#lista-de-acesso)) |
| Deploy | Junto com o site, pelo `firebase-hosting-deploy.yml` |
| Idiomas | pt, en e es |
| Ajuda pública | `/docs/computador.html` (pt, en, es), fora do hub e do índice enquanto `site.flags.webApp` for `false` |

Documentos relacionados:

- `docs/WEB_APP_DESIGN.md`: padrão visual e de interação (tema Campo, painel ao lado, teclado).
- `docs/WEB_API.md`: rotas `/v1/app/*` que o web usa.
- `docs/web-app/ADR-001-web-architecture.md`: por que Vue + Vite estático em `/web`.
- `docs/web-app/parity-matrix.yaml`: cada capacidade do app e onde ela está no web.
- `docs/web-app/discovery-report.md`: uso real e roteiro que levaram ao web.

O que existe: entrada (Google, Apple, e-mail), convites, escolha de empresa, primeiro acesso; Início com lista, quadro, lote e a OS no painel; Nova OS; clientes e aparelhos; catálogo; mandar, receber e cobrar; agenda; checklists; contratos; Financeiro (Resumo, Receber, Relatório) e notas fiscais; avisos e manutenções; equipe, empresa, plano, conta e integrações; PDF, impressão, paleta `⌘K` e importação de planilhas. Cada área tem a sua seção em [Funcionalidades](#funcionalidades).

## Arquitetura

```
firebase/webapp/
├── index.html              # 3 scripts inline (domínio antigo, tema, preload), com hash na CSP
├── scripts/
│   ├── gen.mjs             # contrato: permissões e textos → src/generated/ (fora do git)
│   ├── check-budget.mjs    # orçamento de tamanho, roda no build
│   ├── check-csp.mjs       # hashes dos scripts inline batem com firebase.json
│   ├── check-hosting.mjs   # /web no emulador de Hosting com o firebase.json real
│   └── copy-to-hosting.mjs # dist → firebase/hosting/public/web
├── src/
│   ├── main.ts, App.vue, router.ts, navigation.ts
│   ├── i18n/               # t(), web_{pt,en,es}.json
│   ├── lib/                # firebase, api, session, permissions, format, zone, segments, phone, tax-id
│   │   └── <área>/         # orders, customers, catalog, receive, agenda, finance, nfse, forms,
│   │                       # contracts, onboarding, settings, notifications, pdf
│   │                       #   model.ts = regras puras (testadas), data.ts = chamadas
│   ├── components/         # Layer, Combobox, MoneyInput, DateField, StatusLabel, Menu… e por área
│   ├── views/              # casca e telas, por área
│   └── styles/             # app.css (casca), foundation.css e um arquivo por área
├── tests/                  # vitest: regras puras e casos de contrato
└── e2e/                    # Playwright contra o Emulator Suite, seed, perf
```

Regras de código:

- **Regra de negócio em `lib/<área>/model.ts`**, pura e testada. A tela só decide o que mostrar; quem protege é o servidor e as regras do Firestore.
- **Dinheiro em centavos**, lido como digitado (`parseMoney`: `150` é 150). Moeda, datas e fuso pelo **país da empresa** (`lib/format.ts`, `lib/zone.ts`), nunca pelo idioma nem pelo computador.
- **Rótulos do ramo** por `resolveLabel` (`lib/segments.ts`), com a mesma prioridade do app. Campos do segmento (`segments/{id}.customFields`) por `lib/segment-fields.ts`.
- **Telefone e CPF/CNPJ** por `lib/phone.ts` e `lib/tax-id.ts`, que passam pelos mesmos casos de contrato do app e do servidor.

### Contrato gerado

`npm run gen` lê a matriz de permissões (`firebase/functions/src/__tests__/rbac/app-permissions.json`) e os textos (`lib/l10n/app_{pt,en,es}.arb` e `src/i18n/web_{pt,en,es}.json`), compila o ICU (placeholders e plurais) e grava em `src/generated/`. Falha se os idiomas divergirem em chave ou parâmetro, se uma chave web não começar com `web.` ou se repetir uma do app.

`src/generated/` fica **fora do git**: são cerca de 1.800 textos em 3 idiomas que mudariam a cada alteração nos `.arb`, e a fonte já está versionada. `dev`, `build`, `test` e `typecheck` rodam o gerador antes.

No build (`--prune`) só entram as chaves citadas no código. Por isso **`t()` sempre recebe a chave literal**: montar a chave em tempo de execução não passa no tipo e sumiria no build. Textos de uma área só vão para um arquivo próprio por idioma (`FEATURES` em `scripts/gen.mjs`, ex. `-orders.json`, `-finance.json`), carregado com `loadTexts` antes da tela, fora do primeiro download.

### Dados: API ou Firestore

Regra geral: **dinheiro, situação e tudo que o servidor precisa conferir vão pela API** (`/v1/app/*`, ver `docs/WEB_API.md`). O Firestore direto fica para leitura rápida e para o que as regras já protegem sozinhas.

| Área | Leitura | Gravação |
|---|---|---|
| Sessão, empresa, rótulos do ramo | Firestore REST (`firestore/lite`), leitura única | Empresa e perfil: Firestore direto, só os campos que mudam, transação com o `updatedAt` lido |
| Lista de OS de quem vê valores | Firestore REST para as páginas; cliente completo com `onSnapshot` para as 30 primeiras linhas, carregado depois da lista aparecer | — |
| Lista e OS de quem não tem `viewPrices` | API (`GET /v1/app/orders`, `/:id`), projeção sem nenhum valor | — |
| OS: dinheiro, situação, itens, datas, responsável, parada, apagar | — | API (`lib/orders/writes.ts`), com `expectedUpdatedAt` |
| OS: cliente e aparelho, comentários, fotos, documentos | — | Firestore direto, só os campos que mudam (sem dinheiro) |
| Clientes, aparelhos, importação, próxima manutenção | API (`/v1/app/customers`, `/devices`), cortada pelo papel no servidor | API |
| Catálogo | API (`/v1/app/services`, `/products`), sem `value` para quem não vê preço | API; foto no Storage na pasta do item |
| Agenda | API (`GET /v1/app/orders?sort=scheduledDate…`) | API (`PATCH /v1/app/orders/:id`) |
| Financeiro: Resumo, Receber, Relatório | API (`/v1/app/finance/*`): nenhuma OS somada no navegador | — |
| Notas fiscais | Firestore REST (`invoices` por `effectiveDate`) | API (`/v1/app/nfse/*`) |
| Checklists | Firestore direto (`lib/forms/data.ts`) | Firestore, uma transação por resposta; fotos no Storage |
| Contratos | Firestore REST com máscara de campos: nenhum valor chega ao navegador | `documents:commit` só dos campos `contract.*`, com a versão lida como pré-condição |
| Equipe e convites | `memberships` pelo Firestore | API (`/v1/app/invites`, `/team/members`) |

O Firebase carrega sob demanda (`lib/firebase.ts`). A tela de entrada não baixa Firestore. Até a lista aparecer só vem o build REST (`firestoreLite()`, cerca de 29 KB); o cliente completo (`firestoreClient()`, cerca de 144 KB) chega depois, para o tempo real, a OS aberta e as gravações diretas. `scripts/check-budget.mjs` falha se ele entrar no caminho até a lista.

Por que REST e não a API até a lista: a API passa pela Function (partida a frio em produção) e o REST lê direto do Firestore com as mesmas regras, sem abrir o canal do cliente completo.

**Concorrência.** Toda gravação de OS pela API leva `expectedUpdatedAt` com a `version` como veio (`versionOf`, nunca convertida pelo fuso do navegador); `409 ORDER_CHANGED` mostra o aviso e a versão nova. Pagamento e desconto levam `clientTransactionId`, a Nova OS um `clientOrderId`, o recebimento de várias OS um `receiptId`, importações e preços em lote um id por linha ou `batchId`: repetir depois de a rede cair nunca grava em dobro. As escritas do painel entram em fila.

**Cache persistente** (só no cliente completo): apagado ao sair, quando a sessão termina de outro jeito (`onAuthStateChanged` com `null`) e quando entra outra conta. O dono fica em `praticos.cacheOwner` até a exclusão dar certo. A sessão e a lista nunca leem o disco.

### Sessão e permissões

O papel vem do claim `roles` do token, a mesma fonte das regras do Firestore. `users/{uid}` só dá nome e ordem das empresas; se ele listar uma empresa que o token não conhece, o token é renovado (`refreshClaims()`, também depois de aceitar convite). `owner` é lido como `admin`, papel desconhecido não recebe nada, e sem `useFinancial` as permissões financeiras somem. A sessão escuta `companies/{id}` ao vivo (`followCompany`), então desligar "Valores e cobrança" em outro lugar esconde preços na hora.

Toda rota declara `meta.access` (`tests/access.test.ts` falha sem isso), e cada item do menu carrega a mesma regra (`navigation.ts`).

Onde o web difere do app de propósito (para não deixar uma empresa sem saída): **não aplica limite de plano** (`WEB_PLAN_LIMITS_ENFORCED = false` em `lib/plan-limits.ts`), como o app no navegador; o técnico e o gerente não criam OS (`canCreateOrders`, igual a `canCreateOrder` do app).

### Entrada

Mesmas portas do app (`lib/screens/login.dart`): Google, Apple e "Já tenho conta com e-mail" (senha e "Esqueceu a senha?"). Conta nova só por Google ou Apple. Não há entrada por link de e-mail.

Google e Apple entram na mesma página, sem popup (`signInWithRedirect` em `signInWithProvider`, `lib/session.ts`): a página vai para `/__/auth/handler`, depois para o Google ou a Apple, e volta para `/login`, onde `startSession` termina a entrada e o roteador segue para o `next`. Isso só funciona no Safari porque o `authDomain` é o próprio domínio do app (`praticos.app` no `.env.production`): o armazenamento do login fica no mesmo site. Não mudar o `authDomain` para outro domínio. Voltar do Google sem entrar devolve a tela pronta (evento `pageshow`). A confirmação de identidade antes de apagar a conta (`reauthenticate`, `lib/settings/data.ts`) continua em popup, para não perder a tela aberta.

Tempo da entrada: a tela de login acorda o `api` (`warmUpApi`, `lib/web-access.ts`) com um GET simples, porque o Cloud Run sem instância mínima levava de 4 a 8 s para responder à primeira checagem de acesso. O login e o `onAuthStateChanged` dividem a mesma carga da conta (`hydrate`) e a mesma pergunta de acesso. A medida fica em `npm run e2e:perf:login` (`PERF_COLD_API_MS=4000 PERF_AWAY_MS=5000` simula o `api` frio); meta de 3 s do clique até a lista.

Nos testes de tela, o emulador do Auth fica em outra origem (`127.0.0.1:9099`), então o redirect só roda no Chromium; no WebKit ele cai no bloqueio que o domínio próprio evita em produção.

Quem trabalha em mais de uma empresa escolhe em `/web/choose-company`; a escolha fica lembrada no navegador.

Detalhes da entrada (`src/views/LoginView.vue`, `lib/auth-errors.ts`):

- E-mail sem @ ou ponto e senha vazia são avisados antes de chamar o Auth; "Mostrar senha" troca o campo. "Esqueceu a senha?" com e-mail vazio ou errado diz no campo e não manda nada.
- Cadastro recusado pelo servidor (função `blockSuspiciousSignups`, ou cadastro desligado) tem frase própria, nunca a do Google ou da Apple (`isSignupBlocked`).
- Primeira entrada no web: sem `users/{uid}`, a sessão cria o documento do app numa transação (sem empresa, idioma do navegador), sem esperar (`lib/user-profile.ts`).
- Idioma: o `preferredLanguage` da conta vale num navegador onde ninguém escolheu idioma; escolher em Configurações grava na conta (`pt-BR`, `en-US`, `es-ES`), como o app.
- Conta que não carregou mostra "Tentar de novo"; nunca manda para o primeiro acesso.

Convites sem empresa (`/web/no-company`, `components/InvitesList.vue`, `components/InviteCodeFlow.vue`): aceitar o convite da lista entra direto na empresa; "Recusar convite" pergunta com o nome da empresa; "Tenho outro código" e, no primeiro acesso, "Recebi um código de convite" abrem o código (maiúsculas e `INV_` na frente, como o app), com "Buscar outro código". Os erros vêm do código da API (`inviteErrorKey`).

### Domínios

O web fica em **https://praticos.app/web**. O mesmo Hosting também responde em `praticos.web.app` e `praticos.firebaseapp.com`: quem abre `/web` num deles vai para `praticos.app` com o mesmo caminho, query e hash (script inline no `index.html`, antes do Firebase, `scripts/legacy-host-plugin.ts`; só no build de produção). `/q`, `/__/auth` e o site não mudam.

**Endereço antigo `/app`.** Até 2026-11-05 o web ficava em `/app`. O Hosting responde `/app` e `/app/**` com 301 para `/web` com o mesmo caminho e query (`redirects` no `firebase/firebase.json`, testado em `scripts/check-hosting.mjs`); no domínio antigo são dois passos, `/app` → `/web` no mesmo host e depois o script leva a `praticos.app`. O service worker de avisos que ficou instalado em `/app/` é desregistrado na próxima entrada (`dropLegacyWorker` em `lib/push/token.ts`), para não mostrar cada aviso duas vezes.

Por que um domínio só: o redirect de reserva da entrada depende do `authDomain` (Safari), e login, empresa escolhida e caches ficam guardados por origem.

Cadastros fora do código (passo manual, já feitos):

- **Google Cloud**, cliente OAuth "Web client (auto created by Google Service)": origens e retornos `/__/auth/handler` de `praticos.app` e `praticos.web.app`.
- **Apple Developer**, Services ID `br.com.rafsoft.praticos.app`: domínios `praticos.app`, `praticos.web.app` e `praticos.firebaseapp.com` e os handlers.
- **Firebase Auth**, domínios autorizados: os mesmos três.

Um domínio novo precisa dos três cadastros, de uma entrada em `frame-src` da CSP e de trocar `VITE_FIREBASE_AUTH_DOMAIN`. O CORS da `api` aceita qualquer origem (quem protege é o token), e a lista de acesso decide pelo e-mail, então nenhum dos dois depende do domínio.

### Lista de acesso

O web abre só para contas liberadas. `GET /v1/app/web-access` (`firebase/functions/src/routes/v1/web-access.routes.ts`) lê `config/webApp`:

```json
{ "open": false, "allowedEmailHashes": ["<sha256 do e-mail em minúsculas>"] }
```

- Sem documento, sem e-mail ou com e-mail não verificado: negado. `open: true` libera todo mundo.
- O cliente não lê nem grava `config/webApp` (regra do Firestore). A rota tem limite por IP e guarda a leitura por 30 s.
- Na SPA, um "sim" vale 12 horas e é conferido de novo a cada 10 minutos; um "não" fecha o app na hora; trocar de conta começa do zero; numa falha de rede só um "sim" válido da mesma conta continua valendo.
- Quem está fora vê "O PraticOS no computador ainda não foi liberado para você". Se falta confirmar o e-mail, a tela diz isso e reenvia.

Isso fecha as telas; os dados continuam protegidos pelas regras e pela API. Sem o documento, o web fica fechado para todos.

```bash
cd firebase/functions
npm run webapp:access -- --email pessoa@exemplo.com --project <projeto>
npm run webapp:access -- --email pessoa@exemplo.com --remove --project <projeto>
npm run webapp:access -- --show --project <projeto>
npm run webapp:access -- --open --project <projeto>     # abre para todos
```

`--dry-run` mostra o que mudaria. Sem `--project`, o script recusa, exceto no emulador. O primeiro `--email` cria o documento com `open: false`.

### Navegação e histórico

Painel ao lado com o id na URL (`useRoutePanel`, `?order=`, `?customer=`…). Quem chega por link recebe a lista atrás do painel, então o primeiro Voltar não sai do app. `Layer` empilha um parâmetro `layer` no histórico, e `guard` pergunta antes de fechar quando há texto digitado. Filtros, abas, mês e período também ficam na URL.

## Funcionalidades

Resumo do que cada área faz e do que é próprio do web. O comportamento de tela segue o app e `docs/WEB_APP_DESIGN.md`; o detalhe fino está nos testes de cada área.

### Ordens de serviço

`src/lib/orders/`, `src/components/orders/`, `src/views/OrdersView.vue`.

- **Início (`/`).** A lista de OS, como no app. Filtros Em aberto, Atrasadas, Para hoje, Sem receber, Orçamentos, Paradas, Concluídas e Todas (o técnico abre em Minhas, que pede `assignedTo=<uid>` à API). "Atrasada" compara por dia no fuso da empresa (`isOverdue`, contrato `overdue.json`). Cada filtro é a sua própria consulta (`filterQueries` em `lib/orders-query.ts`, `filterSources` em `lib/orders/data.ts`): Atrasadas por `dueDate` antes de hoje, Para hoje por `dueDate` ou `scheduledDate` de hoje (duas consultas juntas, sem repetir), Orçamentos por `createdAt` crescente, Paradas por `onHold.since`, Sem receber por `status done` e `payment unpaid`, sempre com `createdBy.id` para quem só vê as próprias. Datas comparadas como o texto gravado pelo app (hora local sem fuso). Os números do topo e o "Sem receber N" vêm do servidor (agregação `count`/`sum` do Firestore, ou o `total` da API), nunca do que está carregado. A contagem simples é a consulta da página sem o limite, com a mesma ordenação, para usar o mesmo índice composto. A soma do Sem receber não aceita ordenação e tem índice próprio com os campos somados (`payment, status, paidAmount, total`, e com `createdBy.id`), que o emulador não cobra. Pela API (quem não vê valores) Paradas não tem filtro: as páginas seguem até encher. Resumo no topo com "R$ X para receber". Busca nas OS carregadas (número, cliente, aparelho, placa, sem acento), que também pergunta ao servidor (`lib/orders/search.ts`: número, clientes e veículos que batem) e vale no Quadro, onde os cartões são só o que o servidor achou; "Procurar em todas". Sino, Lista | Quadro e Nova OS ficam numa linha só, no mesmo lugar nas duas vistas; a busca fica na barra de baixo. As linhas se atualizam no lugar (`lib/orders/bus.ts`), sem perder página nem rolagem. Paginação por data e id no cursor (o id do documento, nunca um campo `id` gravado dentro da OS, que nas antigas é `null`). Se a próxima página falha, o aviso "Mostrando a última cópia salva" aparece só quando o navegador está sem rede; um erro da consulta mostra "Não deu para carregar as próximas OS", e "Tentar de novo" pergunta ao servidor de novo.
- **Quadro** (`?view=board`): aba da lista; mover arrastando, pelo "…" ou com `Shift` + seta, só para onde o papel deixa. Fica aberto o dia todo (TV na oficina), então se atualiza sozinho: quem lê do Firestore escuta a mesma consulta do quadro (as 130 OS mais novas, `loader.watch`); quem lê pela API (sem valores) pergunta de novo a cada 2 minutos e quando a aba volta para a frente. "Atrasada" e "parada há" seguem um relógio de 60 s, como na lista.
- **Modo TV** (`/tv`, botão "Modo TV" no Quadro; `src/views/TvBoardView.vue`, `src/lib/orders/tv.ts`): o quadro sozinho para uma tela na oficina. Sem menu, sem valores (as OS são lidas com `showsMoney` falso e nada de dinheiro é desenhado), sem clicar nem arrastar, letra que cresce com a largura da tela, relógio, "Tela cheia" e "Sair". Pede a tela acordada (Screen Wake Lock, onde o navegador tem). Só para quem vê todas as OS (`viewAllOrders`). Cada coluna é a sua consulta, ao vivo: as 50 mais novas de cada situação (Orçamento, Aprovado, Em andamento), de modo que OS velhas acumuladas numa situação não empurram as outras; a contagem mostra "50+" quando passa. Concluído vira **"Concluídas hoje"**: `completedAt` (gravado pelo servidor, UTC) a partir da meia-noite no fuso da empresa, com filtro de um campo só (sem índice composto); recomeça à meia-noite. Dentro da coluna, atrasadas primeiro (a mais atrasada no topo), depois as paradas, depois o resto. Quem lê pela API pergunta de novo a cada 2 minutos e quando a aba volta; nesse caminho "Concluídas hoje" filtra as 30 concluídas mais novas pela data de criação, então pode faltar uma OS antiga concluída hoje. Quando a empresa tiver etapas por equipe, a ideia é agrupar dentro de "Em andamento" (ver discovery das etapas).
- **Esconder valores** (o olho, como nos apps de banco): botão no cabeçalho da Lista e do Quadro, só para quem vê valores. Ligado, os valores das telas de OS (cartão do quadro, frase do topo, coluna Total, painel da OS e pagamentos) viram "R$ •••" (`shownMoney` em `lib/orders/text.ts`; o leitor de tela diz "valor escondido"). Fica guardado por navegador (`prefs.hideValues`), não por pessoa: a TV continua escondida e o computador do escritório continua mostrando. Os botões de dinheiro continuam; janelas de mudar preço e os seletores de item mostram o número. Só esconde na tela: o valor ainda chega ao navegador. Para não ter valor nenhum no navegador, use um perfil sem `viewPrices` (Supervisor, Técnico).
- **Lote** (tela grande): situação, responsável, cobrança (um link Asaas por cliente), assistente (até 10 OS, pergunta antes de aplicar), receber de um cliente, PDF e imprimir. Toda mudança mostra antes de → para e quantas já estão assim; o recusado pelo servidor é contado com o motivo; "Desfazer" volta o que o papel permite.
- **Nova OS** (`N`, gaveta): cliente com Recentes e busca pela placa, veículo (do cliente primeiro; placa digitada vira veículo novo com a placa), itens com preço do catálogo e "Mais usados", "+ Cadastrar «nome»", "+ Usar «texto» nesta OS" (item fora do catálogo) e "+ Cadastrar «texto» no catálogo" (os cadastros abrem um bloco com 1 ou 2 campos: WhatsApp; modelo e placa/série; tipo e preço; ver `docs/QUICK_REGISTER.md`), entrega, pedido do cliente (no ramo com o campo `service_order.observation` grava em `customData.observation`; sem o campo vira o primeiro comentário interno, como no app), fotos (ficam no navegador e sobem depois do id; clique na miniatura tira), campos do ramo (`service_order.*` sem o do pedido, conferidos antes do ✓ e gravados em `customData`) e "Mais opções" (situação, visita, responsável e, com Atendimento no local, o Local). Sem Local, a OS leva o endereço do cliente com a coordenada. Cronometrada no E2E: falha acima de 45 s.
- **OS no painel**: cabeçalho com uma frase e o botão do próximo passo, "O que o cliente pediu" logo abaixo (`lib/orders/request.ts`: o campo do ramo, mudar com a mesma regra dos campos principais; vazio, escrever pelo menu …; pedido antigo que o web gravava como comentário aparece enquanto o campo está vazio, sem apagar o comentário), itens por aparelho (item novo em OS com 2 ou mais aparelhos pergunta "Em quais veículos?": Geral, um, vários ou todos, uma linha por aparelho), totais só para quem vê valores, fotos (colar, arrastar, apagar), comentários internos ou para o cliente, Detalhes (entrega, visita, responsável, local), "Mais dados" do segmento, checklists, contrato, avaliação do cliente, Documentos (nota, contrato, garantia: "Que documento é este?" antes de subir, abrir em aba nova, excluir com confirmação; pasta `documents/` do app, nunca o comprovante de pagamento). Fotos em tela cheia com setas e "Definir como capa" (a primeira foto). O menu … abre a ficha do cliente e de cada aparelho. Teclas `A`, `S`, `C`, `D`, `M`, `R`. OS apagada ou sem acesso mostra "não está mais aqui".
- **Ao concluir**: pergunta a próxima manutenção (`lib/orders/maintenance-offer.ts`, regras de `docs/DEVICE_NEXT_MAINTENANCE.md`) e trava se houver checklist por terminar.
- **Assistente** (`POST /v1/app/ai/order-assist`, com `GET /v1/app/ai/status` ligado; `lib/orders/assist-draft.ts`, `ai-actions.ts`): aplica na hora, marca com ✦ e oferece Desfazer. Nunca recebe, cancela nem apaga sozinho.
  - **Nova OS** (`NewOrderAssist.vue`): texto ou foto (arquivo, só com `attachPhotos`). Preenche cliente, veículo, itens, pedido e entrega sem trocar o que já está escolhido. Cliente ou veículo fora do cadastro entra como "novo" e é cadastrado pela API só no ✓; parecidos abrem "Qual X?" com "Cadastrar" (com a permissão) e "Outro". Desfazer fica no aviso, dentro da gaveta.
  - **OS salva** (`OrderAssistant.vue`): põe itens (do catálogo ou só pelo nome), muda valor, quantidade ou descrição e tira a linha só quando pedido, tudo pela API de itens; linha ambígua pergunta "Qual X?". A foto entra na OS e depois é lida.
  - **Falar** (`AssistTalk.vue`, nas duas barras): grava pelo microfone do navegador (`MediaRecorder`, webm, ogg ou mp4, 32 kbps) e manda o áudio na mesma chamada do texto; o servidor transcreve. O gravador (`lib/orders/talk.ts`) só carrega ao tocar em Falar, e o microfone só é pedido aí. Enquanto ouve: "Cancelar" (ou Esc) joga fora, "Parar e preencher a OS" manda. Para sozinho depois de 20 s sem som ou 5 min; parar sem ter ouvido nada só avisa. Microfone bloqueado: aviso para liberar no cadeado da barra de endereço. Navegador que não grava: sem Falar, fica a caixa de texto. O `firebase.json` libera `microphone=(self)` no `Permissions-Policy` de `/web`. Com áudio o cartão de dinheiro não vem (o servidor só manda `actions` com texto).
  - **Dinheiro** ("Confere?", `AiActionsDialog.vue`): só com a chave `financeActions` (o servidor manda `actions`). Nada grava antes de Confirmar; depois desconto, aprovar, receber e status pela API, nessa ordem, parando no primeiro erro. Na Nova OS o cartão abre na OS depois do ✓.
  - **Apresentação**: uma vez por navegador, em Início, para quem cria OS; "Experimentar agora" abre a Nova OS com o cursor no assistente.
- **Início, extras**: "Manutenções chegando" (atrasadas ou em até 7 dias, sem as de contrato ativo), o sino com os avisos (`/notifications`) e "Agora" para o técnico (a visita de hoje).

### Clientes e aparelhos

`src/views/customers/`, `src/lib/customers/`. Tudo pela API, cortado pelo papel no servidor (consultor e técnico contam só as OS que leem).

- **Clientes (`/customers`)**: por inicial, selos "N atrasadas" e "N em aberto", busca por nome, e-mail, telefone e placa. Ficha ao lado com contato, CPF/CNPJ, endereço, campos do segmento, "Falta receber", aparelhos, OS, recebimentos e "Nova OS para…".
- **Cadastro**: nome e telefone (máscara do segmento pelo país), "Mais dados" com o resto. Telefone de outro cliente pergunta antes. Editar manda a versão lida: se alguém salvou depois, nada é gravado.
- **Aparelhos (`/devices`)**: aba ao lado de Clientes com o nome do ramo, com a ficha, os contratos ativos e a próxima manutenção.
- **Foto do aparelho**: no cadastro ("Mais dados"), escolher, arrastar ou colar uma imagem (até 10 MB). Só trocar, sem tirar, como o app. Nada é gravado antes do ✓: em aparelho novo, o aparelho é criado primeiro e a foto sobe depois para `tenants/{empresa}/devices/{id}/photo.jpg`, com "Enviando a foto…" no botão. Se o envio falhar, o aparelho fica salvo e um aviso diz que a foto não foi. A API só aceita arquivo da pasta daquele aparelho. A foto aparece na ficha.
- **Importar planilha (`/customers/import`)**: CSV ou XLSX lido no navegador, sem biblioteca (zip pelo `DecompressionStream`), ou linhas coladas. Colunas adivinhadas e conferidas, prévia do que entra e do que fica de fora, grava só ao confirmar, de 100 em 100, com id por linha: repetir não duplica.

### Catálogo

`src/views/catalog/`, `src/lib/catalog/`. API `/v1/app/services` e `/products`.

- **Lista (`/catalog`)**: Serviços e Produtos (nome do ramo), busca, "Mais usados", preço só para quem vê valores. O técnico não entra.
- **Cadastro**: nome, preço (com `editPrices`), foto e campos do segmento. A foto sobe só depois de o item existir.
- **Importar (`/catalog/import`)**: igual à de clientes, de 200 em 200; nome que já está no catálogo fica de fora.
- **Preços em lote**: porcentagem para cima ou para baixo, arredondar, prévia antes e depois, até 500 itens numa transação (todos ou nenhum), com `batchId` e Desfazer.

### Mandar, receber e cobrar

`src/components/orders/receive/`, `src/lib/receive/` (centavos, `tests/receive-model.test.ts`).

- **Mandar para o cliente** (`M`): usa o link da API (`/orders/:id/share`), mensagem pela situação e pelo ramo, "Mandar pelo WhatsApp" com o telefone do cadastro do cliente.
- **Compartilhar** (`src/lib/share.ts`, `src/components/ShareButtons.vue`): onde o app abre a folha do sistema, o web oferece "Mandar pelo WhatsApp" (`wa.me/<número>?text=`, número do cadastro do cliente com o DDI do país da empresa; sem telefone, `wa.me/?text=` e a pessoa escolhe), "Copiar o link" e, quando o navegador tem, a folha dele (`navigator.share`, com o arquivo quando `navigator.canShare({ files })`). Vale para o link da OS ("Mandar de outro jeito"), o PDF da OS (WhatsApp baixa o PDF para anexar e manda o link), a foto, o recibo, o PDF da nota (sem conseguir ler o PDF, manda o link) e o convite da equipe. Toda forma de mandar passa por `onShare(method, context)`: ele manda uma vez o evento `share` do analytics (`logShare`), com `method` `sheet`, `whatsapp` ou `clipboard` e `content_type` `order` (link da OS, como o app), `pdf`, `photo`, `receipt`, `invoice` ou `invite`.
- **Avisar o cliente** (`src/lib/orders/notify.ts`): depois de mudar para aprovada, em andamento ou concluída, com cliente com telefone e sem link ativo, uma nota "Na oficina. Avisar Ana?" fica 8 s sob os botões (pausa com o ponteiro ou o foco), uma vez por OS. "Avisar" abre o WhatsApp com o link e o texto da situação.
- **Receber de uma OS**: quanto, como e quando; "Já recebido" com remover e desfazer, "Imprimir recibo" de um pagamento manual e, na parte de um recebimento de várias OS, "Abrir recebimento"; comprovante (imagem ou PDF até 10 MB) para quem tem `attachPhotos`. Recusas do Asaas e da nota usam as mesmas frases do app (`lib/api.ts`, conferidas em `tests/payment-errors.test.ts`).
- **Receber de um cliente em várias OS**: divide da mais antiga para a mais nova, relê os saldos antes de gravar, `receiptId` contra gravação em dobro. Recibo impresso pela ficha do cliente.
- **Cobrança (Asaas)**: criar, cancelar e gerar link novo para quem tem `chargeOrder`, com a conta conectada; um link por OS ou por cliente. Detalhes em `docs/ASAAS_INTEGRATION.md`.
- **Financeiro › Receber (`/finance/receive`)**: quem deve, por cliente, lido do servidor (`/finance/receivable`).
- **Próxima cobrança** (Financeiro, `lib/finance/next-charge.ts`, regra de `lib/utils/next_charge.dart`): dívidas dos últimos 90 dias, a mais antiga primeiro; pula quem tem link aberto (do cliente ou de qualquer OS em aberto) e some se os links não puderem ser lidos em 8 s. "Mandar cobrança" abre a cobrança do cliente já na folha (várias OS com Asaas), a cobrança da OS (uma OS) ou o link da OS (sem Asaas). "Agora não" vale 30 dias **neste navegador, por empresa** (no app, no aparelho).
- **Cobrança de várias OS sobre link de uma OS**: a linha da OS diz "Esperando o pagamento" ou "Venceu em dd/mm" e mandar a nova pede confirmação.

### Agenda

`src/views/agenda/`, `src/lib/agenda/`. Pela API para todos os papéis.

- Semana ou Dia (`/schedule`, `?d=`, `?view=day`, `?who=`), grade de 7 às 19 que cresce, faixa "Dia todo", mês ao lado. No celular, faixa da semana e a lista do dia.
- **Grade sempre na tela** (tela grande), mesmo na semana vazia. **Clicar num horário livre** abre a Nova OS com a visita naquela meia hora (`ui.newOrderSeed.visit`), na faixa "Dia todo" só o dia, e sem `useScheduling` a entrega do dia (`due`). Com "De quem" numa pessoa, ela vem como responsável. Nada é gravado até o ✓, e fechar sem mexer não pergunta. Só para quem cria OS (`canCreateOrders`); o "+ 14:00" ao passar o mouse mostra onde cai.
- **Arrastar** de meia em meia hora, ou `Shift` + setas e `Enter`. Visita que o cliente esperava pergunta antes. "Desfazer" depois.
- **Fuso.** Visita e entrega são gravadas como o app grava: hora da empresa sem fuso (`2026-11-03T14:00:00.000`; "Dia todo" é `T00:00:00.000`). O fuso vem do país da empresa (`lib/zone.ts`); o do computador vale quando é do mesmo país.
- Sem `useScheduling`, mostra as entregas. Admin, gerente e supervisor filtram por responsável.

### Financeiro e notas fiscais

`src/views/finance/`, `src/lib/finance/`, `src/lib/nfse/`.

- **Números do servidor** (`/v1/app/finance/*`): quem não tem `viewFinancialReports` não chega às telas e o servidor responde 403. O navegador manda o fuso; o servidor só aceita o do país da empresa.
- **Resumo (`/finance`)**: Recebido e Vendido do mês, A receber e Em andamento, `?month=`.
- **Relatório (`/finance/report`)**: dia, semana (domingo a sábado, contrato `finance-period.json`), mês, ano ou datas próprias; filtros por pagamento e cliente. "Exportar CSV" (BOM, `;` onde o país usa vírgula, proteção contra fórmula), "Exportar planilha" (XLSX montado no navegador) e "Imprimir ou salvar PDF".
- **Notas fiscais (`/invoices`)**: para quem tem `chargeOrder`, com a nota ligada (`docs/NFSE_ASAAS.md`). Lista do mês com "Precisa de atenção", nota ao lado, emitir pela OS com prévia do servidor, corrigir e cancelar. "Notas de X" em `/invoices?customer=`. Na OS, a linha "Nota fiscal" com a situação ao vivo e, concluída e paga, "Emitir nota fiscal" como botão azul. No cliente, "Notas fiscais · N emitidas" e "Emitir uma nota com várias OS".
- **Configurar a nota (`/invoices/setup`)**: dono e admin (`manageCompany`), pelas rotas `/v1/app/nfse/setup*`. Dados fiscais, acesso à prefeitura (painel do Asaas, confere de novo ao voltar à aba), serviço buscado na lista da prefeitura ou digitado, impostos e quando emitir. Sem configuração pronta, a folha de emitir diz o que falta antes da prévia.
- **Nota direta (`/invoices/direct`)**: com `settings/payments.nfseDirectEnabled`, dono e admin. CNPJs e o emitente lado a lado, certificado arrastado para a gaveta e "Importar notas" (gaveta que lê as notas no governo e só aplica no "Importar"), depois do certificado de um CNPJ novo ou pelo emitente (`docs/NFSE_DIRECT.md`).

### Checklists

`src/views/forms/`, `src/lib/forms/`. Formato idêntico ao do app (`docs/formularios_dinamicos.md`), sem migração.

- **Modelos (`/checklists`)**: só com `manageForms`. "Seus checklists" e "Prontos para usar" do segmento; editor em gaveta com perguntas reordenáveis.
- **Na OS**: adicionar (com o aparelho, se houver vários), preencher em gaveta pelo teclado, fotos no caminho do app (`tenants/{cid}/orders/{oid}/forms/{iid}/…`).
- **App e web ao mesmo tempo**: cada resposta é uma transação que muda só a pergunta respondida. O app ainda regrava a resposta inteira da pergunta (foto posta no web pode sumir); correção no lote do app.

### Contratos

`src/views/contracts/`, `src/lib/contracts/`. O contrato mora na OS que se repete (`isContract` e o mapa `contract`, como no app).

- **O web não cria OS de contrato.** Quem cria é o app ao abrir, ou o job do servidor (`docs/CONTRACTS_SERVER_JOB.md`, desligado). A linha diz quando a OS ainda não nasceu.
- `/contracts`: Ativos e Encerrados, "Ajustar" (frequência, começo, fim, criar sozinha), "Parar de repetir" (grava `active: false`, não apaga), "Novo contrato" e "Repetir esta OS".
- **Sem pausa por enquanto**: versões antigas do app regravam o mapa `contract` inteiro e desfariam a pausa. Volta quando o app que relê o modelo na transação estiver nas lojas.

### Primeiro acesso

`src/views/onboarding/`, `src/lib/onboarding/`. Mesmo fluxo de `docs/ONBOARDING.md`: ramo, especialidades e "Para o cliente", cada passo na URL. Grava empresa, membership e usuário no mesmo lote do app, espera a claim (até 20 s), pede a cópia dos dados (`POST /v1/app/onboarding/seed`) e entra. Recarregar no meio termina a mesma empresa (`sessionStorage`), nunca cria outra.

**Empresa sem ramo** (`resumesCompany`): dono ou admin de uma empresa que existe sem `segment` volta ao primeiro acesso antes de qualquer tela da empresa, com o nome e o telefone dela, e completa a mesma empresa. O servidor só semeia empresa criada há pouco: numa empresa antiga o ramo é gravado sem checklists e exemplos (`ONBOARDING_NOT_NEW`).

### Equipe, empresa e configurações

`src/views/settings/`, `src/lib/settings/`.

- **Configurações (`/settings`)**: a conta e só as linhas que o papel abre. "Neste navegador": idioma, tema e "Usar atalhos de uma tecla". O rodapé mostra a versão ("PraticOS web {dia} ({commit})", `__WEB_VERSION__`).
- **Equipe (`/team`)**: dono e admin. Convidar (código e WhatsApp), reenviar, convidar de novo, mudar papel e tirar. Tabela "O que cada papel pode fazer" lida da matriz gerada.
- **Sua empresa**: dados, logo, termos, ramo e os interruptores (Valores e cobrança, Agenda, Atendimento no local, Contratos, Controle de aparelhos), gravados por transação com o `updatedAt` lido.
- **Plano**: só leitura. Nada de compra ou preço no web. Quem não é dono nem admin lê "Peça ao administrador da conta para mudar de plano."
- **Avaliações (`/settings/ratings`)**: dono e admin (`manageCompany`). Média ("4,5 de 5") e as últimas, a linha abre a OS. Lê só as OS com `rating.score >= 1` (`lib/settings/ratings.ts`).
- **Sua conta**: perfil, trocar de empresa, código de convite, sair e apagar a conta (pela função `accountApi`, `docs/ACCOUNT_DELETION.md`).
- **Integrações**: Asaas (piloto) e conexões do ChatGPT e do Claude.

### Avisos do navegador

`src/lib/push/`, `public/firebase-messaging-sw.js`.

- **O que chega:** os mesmos avisos que o celular recebe do servidor (orçamento aprovado ou recusado, comentário, avaliação, pagamento, manutenção chegando, fim da cortesia), por Web Push pelo FCM.
- **Quando pede:** depois de salvar a Nova OS ou de marcar visita numa OS salva, uma vez por navegador, enquanto ele não respondeu. Primeiro um aviso ("Avisos do PraticOS", "Continuar" ou "Agora não"), depois a pergunta do próprio navegador. Nunca na entrada. Na Nova OS com veículo fica para a próxima, porque a OS vai perguntar do checklist ou da manutenção.
- **Token:** em `users/{uid}.fcmTokens`, no mesmo formato do app, com `platform: 'web'` e um `deviceId` deste navegador (`localStorage`). A cada entrada com permissão dada, o web confere o token. Sair da conta tira o token (até 3 segundos, sem segurar a saída) e apaga o token no FCM. **Computador compartilhado:** o `localStorage` guarda de quem é o token (`praticos.push.owner`); se outra pessoa entrar (ou a anterior não saiu), o token antigo é apagado no FCM e o navegador ganha id e token novos antes de gravar na conta nova. Se não der para apagar, a pessoa nova fica sem aviso nessa vez, nunca com o da anterior. O ícone do aviso é `public/notification-icon.png` (192 px).
- **Clique:** o service worker (escopo `/web/`, sem código do Firebase) foca uma aba aberta e manda abrir a OS, ou abre `/web/?order={id}&company={id}`. O roteador abre a OS só se for da empresa em uso; de outra empresa, fica no Início, como o app.
- **Com a página na tela:** o sistema não mostra nada; aparece um aviso dentro da página e o sino conta de novo.
- **Configuração:** só funciona com `VITE_FIREBASE_VAPID_KEY` (chave pública do par de chaves Web Push, no console do Firebase › Cloud Messaging), `VITE_FIREBASE_MESSAGING_SENDER_ID` (número do projeto) e `VITE_FIREBASE_APP_ID` (app web registrado no projeto). Sem as três, o recurso fica escondido, sem erro.
- **Lembretes não vêm:** os do app (antes da visita, resumo do dia, dias sem abrir, OS paradas) são agendados no próprio celular. Mandar pelo servidor duplicaria no celular; para ter no web, os lembretes do app precisariam ir para o servidor.
- **Teste:** o emulador não entrega push. O build E2E usa um token fixo, o E2E (`e2e/push.spec.ts`) testa o pedido, o token, o clique e o aviso com a página na tela; o service worker é testado em `tests/push.test.ts`.

### Estatísticas de uso (GA4)

`src/lib/analytics.ts`, `src/lib/analytics-client.ts`, `src/components/AnalyticsConsent.vue`.

- **Mesmos nomes do app** (`docs/FIREBASE_ANALYTICS.md`): entrada e primeiro acesso, `screen_view` com os nomes das abas e rotas do app, o funil do assistente, `share` (sheet, whatsapp, clipboard) e `payment_added`. `logShare(method, contentType)` é exportada para qualquer novo ponto de envio.
- **Consentimento:** depois da primeira tela aparece uma vez o aviso "Estatísticas de uso" com "Recusar" e "Aceitar". Nada sai antes do "Aceitar" e o `firebase/analytics` nem baixa. A resposta fica no navegador (`praticos.analyticsConsent`) e muda em Configurações › Neste navegador.
- **Sem dado pessoal:** só as chaves da lista `ALLOWED_PARAMS` saem; nome, telefone e e-mail nunca. O usuário é o uid. O endereço enviado é o da rota, sem id de OS nem busca. Anúncios, sinais do Google e personalização ficam desligados.
- **Configuração:** `VITE_FIREBASE_APP_ID` e `VITE_FIREBASE_MEASUREMENT_ID` em `.env.production` (app web "PraticOS Website" do projeto `praticos`, o mesmo fluxo GA4 do site). Sem eles, tudo desligado e sem aviso.
- **Orçamento e CSP:** o client vem depois da primeira tela; `check-budget.mjs` falha se ele entrar no caminho da entrada ou da lista. A CSP do `/web` libera só `www.googletagmanager.com` (script) e `*.google-analytics.com`, `*.analytics.google.com` (envio).
- **Testes:** no build e2e os eventos vão para `window.__analytics`, e só quando o teste pede (`praticos.analyticsE2E`): `e2e/analytics.spec.ts` e `tests/analytics.test.ts`.

### PDF, impressão e paleta

- **PDF da OS** (`src/lib/pdf/`): "Ver PDF" na OS e "PDF" no lote. Montado no navegador com `pdf-lib` e `qrcode-generator`, baixados só nesse momento. Mesmo desenho do app (`docs/PDF_GENERATION.md`), com os textos `pdf*` dos `.arb`. Sem `viewPrices`, sai sem valores. Caracteres fora do WinAnsi usam a Roboto do app, embutida só quando precisa.
- **Fotos no PDF** funcionam: o CORS do bucket `praticos.appspot.com` já aceita `GET` e `HEAD` de qualquer origem, então o navegador baixa as fotos. Baixar e compartilhar uma foto como arquivo usam o mesmo CORS. Se um dia o CORS do bucket mudar e bloquear o domínio do web, o PDF sai com "Fotos disponíveis no sistema digital" no lugar das fotos e compartilhar manda o link da foto.
- **Impressão**: "Imprimir ou salvar PDF" usa folha própria (`@media print`), na OS, no lote e no Relatório.
- **Paleta `⌘K`** (`src/lib/global-search.ts`, `CommandPalette.vue`): OS pelo número, clientes, aparelhos, catálogo e ações, cada grupo só para quem abre a tela (`canOpen`, a mesma guarda das rotas).

## Testes

| Tipo | Onde | Comando |
|---|---|---|
| Regras puras e casos de contrato | `tests/*.test.ts` (vitest) | `npm test` |
| Tipos | `vue-tsc` | `npm run typecheck` |
| Ponta a ponta | `e2e/*.spec.ts` (Playwright + Emulator Suite) | `npm run e2e` |
| Acessibilidade | `e2e/a11y.spec.ts` e `*-a11y.spec.ts` (axe, claro e escuro) | parte do `e2e` |
| Desempenho | `e2e/perf/list-visible.spec.ts` | `npm run e2e:perf`, `npm run e2e:perf:cold` |
| Lighthouse | `lighthouserc.json` (tela de entrada, desktop) | `npm run lhci` |
| Hosting | `scripts/check-hosting.mjs` | `npm run check:hosting` |

**Casos de contrato.** `docs/web-app/contract-cases/*.json` (totais, permissões, situações, recebimentos, visibilidade, telefone, CPF/CNPJ, período do Financeiro, limites do plano, geração de contratos…) são a mesma tabela de entrada e saída rodada em três lugares: no app (`test/contract/`), nas Functions (`src/__tests__/*cases*.test.ts`) e no web (`tests/contract-cases.test.ts`). Mudar uma regra é mudar o caso e fazer os três passarem.

**E2E.** Contra o Emulator Suite (`firebase/firebase.e2e.json`, portas próprias), projeto `demo-praticos`, com o seed de `e2e/seed.mjs`: um usuário por papel e um sem empresa (`e2e/fixtures.mjs`), empresas separadas para os testes que mudam a empresa (gama, equipe, delta), OS de cenário fixo e as que cada teste cria (`e2e/data.ts`). Asaas, notas fiscais, o modelo do assistente e o uso do assistente são simulados com `page.route`; o WhatsApp nunca abre (o teste lê o link). Segredos das Functions são falsos, criados só durante a execução.

```bash
PW_ARGS=e2e/auth npm run e2e                   # um arquivo
E2E_ONLY=auth,firestore,storage npm run e2e    # sem Functions (mais rápido)
E2E_PORT_OFFSET=1000 npm run e2e               # outra cópia do repositório rodando ao mesmo tempo
```

**Desempenho.** Fast 4G, CPU 4x, 10 mil OS, p75 de 7 rodadas, cada passo marcado com `performance.mark`. A visita medida é a de quem já usa: login e "sim" da lista de acesso guardados, sem cache HTTP nem do Firestore. Falha acima de 1,5 s. A "primeira visita fria" (`e2e:perf:cold`) liga o emulador de Functions e não usa o "sim" guardado.

Medido em 2026-11-03, com todas as áreas:

| Medida | Resultado | Limite |
|---|---|---|
| Lista visível, 1ª visita | cerca de 1,08 s | 1,5 s |
| Lista visível, volta | cerca de 0,70 s | — |
| Primeira visita fria (com a rota `web-access`) | 1,46 s | — (em produção a partida a frio da Function pode somar segundos) |
| JS até a lista (brotli) | 136,1 KB | 240 KB |

O que trouxe o tempo de 2,6 s para 1,1 s: servir com brotli, ler usuário e empresa em paralelo com o token, `modulepreload`, primeira página de 30 e, por último, o Firestore REST até a lista (de 239 KB para 130 KB de JS).

**Guardas no build e no CI.**

| Guarda | Onde |
|---|---|
| JS da entrada até 200 KB, até a lista até 240 KB, Firestore completo e Firebase Messaging fora do caminho até a lista | `scripts/check-budget.mjs` |
| Scripts inline com hash na CSP | `scripts/check-csp.mjs` |
| Acessibilidade 100, performance 90, LCP 2,5 s, CLS 0,1, TBT 300 ms | `lighthouserc.json` |
| axe sem violação em claro e escuro | `e2e/a11y.spec.ts` |
| Toda rota com `meta.access` | `tests/access.test.ts` |

O CI (`.github/workflows/webapp_check.yml`) roda em todo PR que toque o web, os tokens do site, os casos de contrato, os `.arb`, a matriz de permissões ou a rota `web-access`, em três máquinas ao mesmo tempo: uma com gen, typecheck, testes, build, Lighthouse e Hosting, e duas com metade do E2E cada (`--shard`). Um push novo no mesmo PR cancela a execução anterior. O axe no tema escuro só roda quando o PR mexe em `src/styles/`, `src/lib/prefs.ts` ou nos tokens do site; nos outros PRs o CI passa `E2E_SKIP_DARK_AXE=1` e o `playwright.config.ts` pula esses testes (o tema claro e os testes do modo escuro continuam).

## Como rodar

Node 22 e, para os emuladores, Java 21 ou mais novo. Na máquina do Rafael:

```bash
export PATH=/opt/homebrew/opt/openjdk@27/bin:$PATH JAVA_TOOL_OPTIONS=-Duser.language=en
```

```bash
cd firebase/webapp
npm ci
npm test && npm run typecheck && npm run build

(cd ../functions && npm ci && npm run build)   # uma vez
npm run emulators    # terminal 1: suíte + seed
npm run dev          # terminal 2: http://localhost:5180/web/
```

Desenvolvimento sempre contra o emulador. Os componentes base ficam em `/web/dev/components`, só nos builds de emulador.

## Deploy

`firebase-hosting-deploy.yml` compila o site e depois a SPA (`npm run build:hosting`, que vai para `firebase/hosting/public/web`). Dispara também com mudanças em `firebase/webapp/**`. A configuração de produção (`.env.production`) só tem valores públicos. Os avisos do navegador precisam de mais três, também públicos (ver "Avisos do navegador").

**Ordem:** a Function `api`, com a rota `/v1/app/web-access` e as rotas que uma tela nova usa, precisa estar no ar **antes** do Hosting. As Functions saem por outro workflow (`firebase-functions-deploy.yml`): num PR que mude os dois, confirme que o das Functions terminou.

`firebase/firebase.json`:

| Caminho | O que faz |
|---|---|
| `^/web/[^.]*$` | rewrite para `/web/index.html`. Só caminhos sem extensão: um asset que não existe dá 404, não o `index.html` |
| `/web/assets/**` | `Cache-Control: public, max-age=31536000, immutable` |
| rotas do app e `index.html` | `Cache-Control: no-cache` |
| `/web/**` | CSP, `nosniff`, `Referrer-Policy`, `X-Frame-Options: DENY` |

- Uma aba aberta antes de um deploy pede chunks que já não existem: o app recarrega uma vez (`lib/stale-build.ts`); se falhar de novo em menos de um minuto, mostra o erro.
- A CSP libera os três scripts inline do `index.html` por hash. Se um mudar, `npm run build` falha e mostra o hash novo para colar em `firebase.json`.
- `npm run check:hosting` sobe o emulador de Hosting com o `firebase.json` real e confere a SPA em rota funda, o cache dos assets, a CSP na entrada, o redirecionamento do domínio antigo e que o site, `/pricing` e `/robots.txt` não mudaram. `/q`, `/pro`, `/admin` e `/mcp` são conferidos pela configuração.

## Como adicionar uma tela

1. Crie a view em `src/views/<área>/`, começando por `PageHead`, com a resposta da tela no título.
2. Rota em `src/router.ts`, com `import()` e **`meta.access`**. Se entra no menu, a entrada em `src/navigation.ts` com a mesma regra.
3. Regras em `lib/<área>/model.ts` com teste; chamadas em `lib/<área>/data.ts`. Dinheiro e situação pela API.
4. Textos: reuse as chaves do app quando o sentido for igual; as do web nos três `src/i18n/web_*.json`, com prefixo `web.`, e numa área própria em `FEATURES` se não forem do primeiro download.
5. Rótulo do ramo com `resolveLabel`; dinheiro e datas com `lib/format.ts`; cores só pelos tokens; status com `StatusLabel`.
6. Atalho com `registerShortcut`, comando da paleta com `registerCommand`; remova os dois ao desmontar.
7. Vazio, erro e carregando com `EmptyState`, `ErrorState` e `LoadingState`. Erro de API: `t(errorMessageKey(error))`.
8. E2E da tela, entrada em `e2e/a11y.spec.ts` e `e2e/guard.spec.ts`, e a linha em `docs/web-app/parity-matrix.yaml`.

## Limitações conhecidas

- **`expectedUpdatedAt` só protege entre telas do web:** o app grava itens sem atualizar `updatedAt` e regrava a OS inteira.
- **Checklists e contratos com versões antigas do app:** o app pode apagar uma foto posta no web e regravar o mapa `contract` inteiro.
- **Quem não vê valores não tem tempo real:** a OS é relida depois de cada gravação e ao voltar à janela.
- **Fuso:** a empresa não tem campo de fuso; ele vem do país. Uma empresa em Manaus aberta num computador em São Paulo usa São Paulo.
- **Pedido do cliente:** fica no primeiro comentário interno, como no app; `service_order.observation` do segmento não é gravado pelo web.
- **Primeiro acesso de empresa antiga sem ramo:** completa o ramo sem checklists e exemplos (o servidor recusa semear empresa que não é nova).
- **Próxima cobrança:** "Agora não" fica no navegador, como no app fica no aparelho.
- **Opções da empresa que faltam no documento** (`lib/company-features.ts`): resolvidas como o app (empresa, padrão do ramo, padrão do app), mas o web nunca grava o que falta.

## Decisões pendentes

Do dono:

- **Abrir para todos e anunciar.** Hoje só a lista de acesso entra. Abrir é `npm run webapp:access -- --open`; anunciar é ligar `site.flags.webApp` (o artigo `/docs/computador*.html` entra no hub e no índice) e decidir menu e home.
- **Compra e gestão de plano no web.** Hoje o Plano é só leitura.
- **Limite de plano no web e limite de convites no servidor.** Hoje nenhum dos dois trava.
- **Texto da política de privacidade sobre estatísticas no navegador.** O web pede consentimento para o Google Analytics, mas a política (`firebase/hosting/src/_data/legal.json`) ainda não fala de cookies nem de estatísticas de uso no navegador.
- **Tirar `praticos.web.app` e `praticos.firebaseapp.com`** da CSP e dos consoles, quando o app deixar de ser servido neles.

Técnicas, esperando outra peça:

- **Pausar contratos:** quando o app que relê o modelo na transação estiver nas lojas e as versões antigas saírem de uso.
- **Avisos do navegador:** gerar o par de chaves Web Push no console do Firebase (Cloud Messaging) e pôr a chave pública em `VITE_FIREBASE_VAPID_KEY` no `.env.production` (o app id e o número do projeto já estão lá).
- **Lembretes no web:** no app são notificações locais do celular; para chegarem ao navegador, os lembretes do app teriam de ir para o servidor (senão o celular recebe dois).
- **Câmera:** no computador é arquivo; a proposta é um QR "Continuar no celular".
- **Fica para depois, por área:** foto do aparelho (a rota ainda não aceita), faixa "Sem data" na agenda, mudar e tirar itens pelo assistente em lote, lote no celular.
