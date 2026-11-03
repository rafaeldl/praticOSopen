# WEB_APP.md

## Visão Geral

App web do PraticOS: ferramenta de mesa para as mesmas contas e dados do app. Vue 3 + Vite, SPA estática em `/app`, código em `firebase/webapp/`. A decisão está em `docs/web-app/ADR-001-web-architecture.md`, as regras de tela em `docs/WEB_APP_DESIGN.md`, e a referência visual é o protótipo da branch `claude/web-app-prototype-bb3bbf` (tema Campo). Quando protótipo e `WEB_APP_DESIGN.md` divergem, vale o protótipo.

Estado: fechado por lista de acesso. Tem entrada (Google, Apple, e-mail), convites, escolha de empresa, casca, permissões, componentes base a fatia "OS completa": Início com a lista de OS, Nova OS por teclado e a tela da OS (ver "Ordens de serviço"), e a fatia "Clientes e aparelhos" (ver a seção com esse nome). O deploy em `/app` sai junto com o site.

Decisões fechadas: botão principal amarelo, densidade confortável, painel ao lado, IBM Plex Sans no texto, Outfit só no logo.

## Arquitetura

```
firebase/webapp/
├── scripts/gen.mjs        # contrato: permissões e textos → src/generated/
├── scripts/check-budget.mjs  # orçamento de tamanho, roda no build
├── src/
│   ├── i18n/              # t(), web_{pt,en,es}.json
│   ├── lib/               # firebase, api, session, permissions, format, segments…
│   ├── lib/rules/         # regras de OS cobertas pelos casos de contrato
│   ├── components/        # Layer, Combobox, MoneyInput, DateField, StatusLabel…
│   ├── views/             # casca e telas
│   ├── navigation.ts      # entradas do menu, com a permissão de cada uma
│   └── router.ts          # rotas e guarda
├── tests/                 # vitest
└── e2e/                   # Playwright + Emulator Suite
```

### Contrato gerado

`npm run gen` lê:

- `firebase/functions/src/__tests__/rbac/app-permissions.json`: matriz de permissões.
- `lib/l10n/app_{pt,en,es}.arb` e `src/i18n/web_{pt,en,es}.json`: textos. O ICU (placeholders e plurais) é compilado aqui, então não há parser no navegador.

Falha se os idiomas divergirem em chave ou parâmetro, se uma chave web não começar com `web.` ou se repetir uma chave do app.

A saída fica em `src/generated/`, **fora do git**. Motivo: são 1.800 textos em 3 idiomas que mudariam a cada alteração nos `.arb`, gerando conflito e ruído num repositório público, e a fonte já está versionada. `dev`, `build`, `test` e `typecheck` rodam o gerador antes.

Nos builds (`--prune`) só entram as chaves citadas no código, 5% do total, o que corta cerca de 30 KB do download. Por isso **`t()` sempre recebe a chave literal**. Montar a chave em tempo de execução (`` t(`status${x}`) ``) não passa no tipo e sumiria no build.

### Dados

| Operação | Caminho |
|---|---|
| Sessão, empresa, lista e OS de quem vê valores | Firestore direto, com `onSnapshot` |
| Lista e OS de quem não tem `viewPrices` | Projeção da API (`GET /v1/app/orders`, `/:id`), sem nenhum valor |
| Dinheiro, situação, itens, datas, responsável, parada, apagar | API (`lib/orders/writes.ts`) |
| Cliente e aparelho da OS, comentários, fotos | Firestore direto, só os campos que mudam (sem dinheiro) |
| Telas de clientes e aparelhos, cadastro, importação, próxima manutenção | API (`lib/customers/data.ts`): `/v1/app/customers`, `/v1/app/devices` |

Firebase é carregado sob demanda por `lib/firebase.ts`. A tela de entrada não baixa Firestore. Cache persistente fica desligado, porque o computador da oficina é compartilhado.

### Sessão e permissões

O papel vem do claim `roles` do token, a mesma fonte das regras do Firestore. O documento `users/{uid}` só dá nome e ordem das empresas. Se ele listar uma empresa que o token ainda não conhece, o token é renovado. `refreshClaims()` força isso depois de aceitar convite.

`owner` é lido como `admin` e papel desconhecido não recebe nada, como no servidor. Sem `useFinancial`, as permissões financeiras somem.

A tela só decide o que mostrar. Quem protege é o servidor e as regras.

### Entrada

Mesmas portas do app (`lib/screens/login.dart`): Google, Apple e "Já tenho conta com e-mail", com senha e "Esqueceu a senha?". Conta nova só por Google ou Apple, como no app. O app não tem entrada por link de e-mail, então o web também não tem.

Google e Apple abrem em popup. Se o navegador bloquear o popup, a entrada segue por redirect (`shouldRedirect` em `lib/session.ts`). Para o redirect funcionar no Safari, o `authDomain` precisa estar no mesmo site do app. Hoje ele é `praticos.firebaseapp.com`. Passar para `praticos.web.app` exige cadastrar `https://praticos.web.app/__/auth/handler` no cliente OAuth do Google e no Services ID da Apple, um passo manual nos consoles.

Quem trabalha em mais de uma empresa escolhe onde entrar (`/app/choose-company`). A escolha fica lembrada neste navegador e pode ser trocada no menu.

### Convites

Convites pendentes aparecem na tela "sem empresa" e em Configurações. A lista vem do Firestore (`links/invites/tokens`, pelo e-mail verificado). O aceite passa por `POST /v1/app/invites/:token/accept`. Depois o web espera o claim novo no token e entra na empresa.

**Limitação do servidor:** `/v1/app/invites` fica atrás de `bearerAuth`, que responde 403 para quem ainda não tem empresa. Por isso o primeiro convite de uma conta nova não é aceito pelo web. O app chama a mesma rota, então deve ter o mesmo problema. O teste está em `e2e/invites.spec.ts` como `fixme`. Quem já tem empresa aceita normalmente.

### Lista de acesso

O web abre só para contas liberadas. `GET /v1/app/web-access` (`firebase/functions/src/routes/v1/web-access.routes.ts`) lê `config/webApp`:

```json
{ "open": false, "allowedEmailHashes": ["<sha256 do e-mail em minúsculas>"] }
```

- Sem documento, sem e-mail ou com e-mail não verificado, o acesso é negado.
- `open: true` libera todo mundo.
- O cliente não lê nem grava `config/webApp` (regra do Firestore).
- A rota tem limite próprio por IP e guarda a leitura do documento por 30 s.

Na SPA:

- Um "sim" fica guardado por 12 horas e é conferido de novo em segundo plano a cada 10 minutos.
- Um horário no futuro guardado é tratado como inválido.
- Ao trocar de conta, a resposta começa do zero.
- Numa falha de rede, só um "sim" ainda válido da mesma conta continua valendo; sem ele, aparece um erro com "Tentar de novo".
- Um "não" fecha o app na hora.

Quem não está na lista vê só a tela "ainda não foi liberado". Se o que falta é confirmar o e-mail, a tela diz isso e oferece mandar o e-mail de novo. Isso fecha as telas; os dados continuam protegidos pelas regras e pela API.

O documento `config/webApp` não existe até alguém rodar o script. Sem ele, o web fica fechado para todos. O primeiro `--email` cria o documento com `open: false`.

Para liberar alguém (nunca rode sem saber qual projeto):

```bash
cd firebase/functions
npm run webapp:access -- --email pessoa@exemplo.com --project <projeto>
npm run webapp:access -- --email pessoa@exemplo.com --remove --project <projeto>
npm run webapp:access -- --show --project <projeto>
npm run webapp:access -- --open --project <projeto>     # abre para todos
```

`--dry-run` mostra o que mudaria. Sem `--project`, o script recusa, exceto no emulador.

### Moeda e datas

`lib/format.ts` usa o **país da empresa**, não o idioma. Uma OS brasileira aberta em inglês continua em R$ e com vírgula. `parseMoney` lê o que foi digitado: `150` é 150, nunca 1,50.

### Ordens de serviço

Código em `src/lib/orders/` (regras puras em `model.ts`, testadas em `tests/orders-model.test.ts`) e `src/components/orders/`.

**Início (`/`, também `/orders`).** É a lista de OS, como no app. Filtros do app: Em aberto, Orçamentos, Paradas, Concluídas e Todas; o técnico vê Minhas, Paradas e Todas e abre em Minhas. Orçamentos, Paradas e Minhas filtram as OS abertas no navegador, como o app. A ordem de Em aberto é atrasadas (promessa mais antiga primeiro), de hoje e o resto. "Atrasada" compara por dia, na lista e na OS (`isOverdue`, contrato `overdue.json`). A frase de resumo aparece só com a lista toda carregada. A linha mostra aparelho e serviços, situação com entrega e visita, parada com motivo e dias, valor e "falta receber". Todas é separada por mês. Filtro, busca e OS aberta ficam na URL (`?f=`, `?q=`, `?order=`). A busca procura nas OS carregadas (número, cliente, situação, aparelho, placa, sem acento); "Buscar nas mais antigas" pede o número ao Firestore e as páginas seguintes. A lista se atualiza sozinha: as 30 primeiras linhas por `onSnapshot`, e o que muda no painel, na Nova OS ou no lote atualiza a linha no lugar (`lib/orders/bus.ts`), sem perder página nem rolagem.

**Quadro.** Aba da lista (`?view=board`). Mover o cartão arrastando, pelo botão "…" ou com Shift e seta. Só oferece o que o papel permite.

**Lote.** Selecionar linhas troca a barra de filtros pelas ações: mudar a situação (só as que todas as selecionadas aceitam) e responsável. Cada OS vai pela API; o que o servidor recusa é contado no aviso.

**Nova OS.** `N`, a paleta ou o "+" da barra no celular. Técnico e gerente não criam (o app tira o técnico em `canCreateOrder`, apesar da matriz de permissões). Cliente, aparelho (o único do cliente entra sozinho; os que ele já trouxe aparecem primeiro), itens com o preço do catálogo, entrega, pedido do cliente e "Mais opções" (situação inicial sem "cancelada", visita, responsável). `Ctrl/⌘ Enter` salva de qualquer campo. Fechar com algo preenchido pergunta (Esc, X, Voltar e recarregar). O pedido do cliente vira o primeiro comentário interno, como no app. As listas são lidas enquanto a pessoa olha a lista, para a gaveta abrir pronta.

**Tela da OS.** Cabeçalho com cliente, aparelho, situação e uma frase (prazo, atraso ou "Falta receber"), o botão azul do próximo passo (aprovar, começar, concluir serviço, retomar, receber) e "Marcar como parada". Itens agrupados por aparelho, com mudar e tirar; tirar oferece Desfazer. Totais só para quem vê valores. Fotos (escolher, colar, arrastar), comentários com "só a equipe" ou "cliente também vê", Detalhes (entrega, visita, responsável, local). Menu "…" só com o que a OS e o papel permitem, destrutivas por último e com confirmação. Teclas: `A`, `S`, `C`, `D`, `R`. "Imprimir ou salvar PDF" usa uma folha própria de impressão. OS apagada ou sem acesso mostra "não está mais aqui", nunca uma OS vazia.

**Gravações.** `expectedUpdatedAt` vai em situação, datas, responsável, itens, pagamento e desconto, com a `version` da OS como veio (`versionOf` em `lib/orders/model.ts`), nunca convertida pelo fuso do navegador; um `409 ORDER_CHANGED` mostra o aviso e a versão nova. Pagamento e desconto levam `clientTransactionId` gerado ao abrir o diálogo, então repetir não grava em dobro. Itens lidos do Firestore recebem o mesmo id derivado que o servidor calcula (`lib/orders/line-ids.ts`, igual a `locateLines`). As escritas do painel entram em fila: uma segunda espera a primeira, nunca some.

**Assistente.** Barra "Peça ao assistente" no pé da OS, só para quem edita os itens e com `GET /v1/app/ai/status` ligado. Põe na OS os itens do catálogo que entendeu (`POST /v1/app/ai/order-assist` e depois `POST /items`), marca com ✦ e oferece Desfazer. No E2E a resposta do modelo é simulada com `page.route`.

**Depois da revisão e do teste de usuários (#515).**
- Filtros também Atrasadas, Para hoje e Sem receber (com contagem; lido por `payment == 'unpaid'`, indexado com `createdAt`). A busca mostra quantas achou, põe o número exato primeiro e oferece "Procurar em todas". `⌘K` acha OS por número, cliente ou aparelho, e clientes.
- Nova OS cadastra cliente (`POST /v1/app/customers`) e veículo (`POST /v1/app/devices`) com "+ Cadastrar «nome»", só depois das listas carregadas, para nunca duplicar. Quando o cliente não tem OS que a pessoa lê (consultor), lista os veículos da empresa. Texto digitado e não escolhido trava o salvar com aviso. Enter vazio no veículo vai para o item. "+ Usar «texto» nesta OS" põe um serviço fora do catálogo, na Nova OS e na OS aberta (`POST /items` sem `catalogId`, #516). A Nova OS gera um `clientOrderId` ao abrir e o repete em cada tentativa: salvar de novo depois de a rede cair devolve a mesma OS.
- Receber nunca passa do que falta e acompanha o saldo ao vivo; pagamento e desconto mandam `expectedUpdatedAt`; `409 PAYMENT_EXCEEDS_BALANCE` mostra o aviso e relê a OS.
- Tirar item só vai ao servidor quando o aviso sai; Desfazer mantém descrição e posição.
- Fechar "E o veículo?" cancela a troca de cliente. O resumo do cliente gravado leva e-mail e CPF/CNPJ.
- Quem não tem `viewPrices` lê o catálogo pela REST do Firestore com máscara só do nome: o preço não chega à rede nem ao IndexedDB.
- Menu "…" preso ao botão (no celular, folha embaixo). Situações na ordem do serviço. Fechar a OS devolve o foco à linha.
- "Minhas" pede `assignedTo=<uid>` à API: o técnico vê a OS atribuída a ele, criada por qualquer um (regras e índices do #514; na API, `canSeeOrder` e a lista aceitam o técnico atribuído).
- A Início abre com "R$ X para receber" no resumo; em Sem receber, buscar um cliente mostra quanto ele deve. O próximo passo de "Na oficina" é "Concluir serviço". Telefone do cliente legível, total da Nova OS acompanha o valor enquanto digita, controles nativos seguem o tema escuro.

**Textos.** Os textos usados só por uma funcionalidade vão para um arquivo próprio por idioma (`FEATURES` em `scripts/gen.mjs`): `src/components/orders/` em `generated/i18n/{pt,en,es}-orders.json` e as telas de clientes em `-customers.json`. Cada tela carrega o seu com `loadTexts` antes de aparecer, fora do primeiro download.

**Testes.** `e2e/orders-list.spec.ts`, `e2e/orders-new.spec.ts`, `e2e/order-detail.spec.ts` e `e2e/orders-review.spec.ts` (um teste por item da revisão e do teste de usuários), contra o Emulator Suite. As OS que um teste muda são criadas por ele (`e2e/data.ts`); as do cenário fixo ficam em `seedScenario` (`e2e/seed.mjs`). A Nova OS por teclado (cliente, veículo, item e valor) é cronometrada e falha acima de 45 s.

### Clientes e aparelhos

Código em `src/views/customers/`, `src/components/customers/` e `src/lib/customers/` (regras puras em `model.ts`, importação em `import.ts`, chamadas em `data.ts`). Testes: `tests/customers.test.ts` e `e2e/customers*.spec.ts`, `e2e/devices.spec.ts`.

**Dados pela API.** Lista, tela do cliente e do aparelho vêm de `/v1/app/customers` e `/v1/app/devices` (ver `docs/WEB_API.md`), filtradas pelo papel no servidor: consultor e técnico contam só as OS que leem e a tela diz isso. No app essas consultas são negadas pelas regras e a tela fica sem selo, sem busca por placa ou com erro (defeitos 1, 2 e 9 da fatia 03). Nenhuma tela desta fatia usa o Firestore.

**Clientes (`/customers`).** Todos de uma vez, 200 linhas por vez na tela, por inicial sem acento ("#" no fim). Selos "N atrasadas" (vence) e "N em aberto" (aprovada e na oficina). A busca acha nome e e-mail sem acento, telefone pelos dígitos e placa a partir de 3 caracteres, sem hífen; o acerto da placa abre o dono, cliente da OS mais recente. `/` foca a busca e `⌘K` acha cliente e placa. O cliente aberto fica ao lado (`?customer=`), com contato, CPF/CNPJ, endereço com mapa, campos do segmento, "Falta receber" com "Receber", "gastou", aparelhos tirados das OS e as OS com os nomes de situação do segmento. "Nova OS para Ana" leva só o cliente. Ligar e WhatsApp só com telefone (`tel:` só com dígitos e "+"; `wa.me` pela regra de `lib/phone.ts`).

**Cadastro.** Gaveta com nome e telefone (máscara `customer.phone` do segmento pelo país); "Mais dados" com e-mail, CPF/CNPJ (só Brasil ou empresa sem país), endereço e campos do segmento, aberto sozinho quando há algum. "Salvar" cinza até ter nome. Cliente novo com telefone de outro pergunta antes ("Abrir cliente" ou "Salvar mesmo assim"), comparando como o app (sem o nono dígito). Fechar com algo digitado pergunta, também ao editar. Editar manda a versão lida: se alguém (web ou app) salvou depois, nada é gravado, a tela avisa e relê. Apagar diz quantas OS, recibos e cobranças o cliente tem, contando também o que o papel não vê.

**Campos do segmento.** `lib/segment-fields.ts` lê os mesmos `segments/{id}.customFields` do app (global e depois o do segmento; mesma chave, vale o do segmento): text, textarea, number (só inteiro, mínimo e máximo), select e date (gravada como o app, ISO com hora). Lê `customData[nome]` e `customData[chave]`, grava só o nome. `required` vale para todos os tipos (o app ignora em textarea, select e date). Máscaras no formato do `easy_mask` (9, A, N, X).

**Aparelhos (`/devices`).** Aba ao lado de Clientes, com o nome do segmento ("Veículos"). Modelo, placa, situação (com `useDeviceManagement`) e próxima manutenção; editar e apagar na linha só para quem pode. A tela do aparelho (`?device=`) abre para todos os papéis, com dono, OS e a próxima manutenção (marcar, mudar e tirar só com `manageDevices`). O cadastro aceita modelo ou placa; a placa segue a máscara e o `pattern` do segmento e vai em maiúsculas; o modelo sugere os já cadastrados e traz marca e categoria.

**Importar planilha (`/customers/import`).** CSV (vírgula, ponto e vírgula ou tab) ou XLSX lido no navegador, sem biblioteca (zip pelo `DecompressionStream`). Colunas adivinhadas e conferidas; a prévia diz o que entra e o que fica de fora (sem nome, CPF/CNPJ inválido, telefone de um cliente, telefone repetido na planilha). Grava só ao confirmar, de 100 em 100; cada linha tem id próprio e o id da importação nasce na prévia, então "Importar" de novo depois de uma falha não duplica nada.

**Uma fonte só.** Permissões pelo contrato gerado; telefone (`lib/phone.ts`) e CPF/CNPJ (`lib/tax-id.ts`) passam pelos casos de contrato `phone.json` e `tax-id.json`, os mesmos do app e do servidor; máscaras e campos vêm do segmento; textos pelos `.arb` e `web_*.json`.

**Fica para depois.** Seletores da OS ("Qual cliente?" com Recentes e placa, "Qual veículo?" com Nenhum), vínculo do aparelho cadastrado pela tela do cliente (não há campo de dono), foto do aparelho, recebimentos e notas do cliente, contratos do aparelho e a pergunta da próxima manutenção ao concluir a OS.

### Histórico do navegador

Voltar fecha o que estiver aberto. O painel lateral usa `useRoutePanel`, com o id na URL. Quem chega por link recebe a lista atrás do painel, então o primeiro Voltar não sai do app. `Layer` empilha um parâmetro `layer` no histórico, e `guard` pergunta antes de fechar quando há texto digitado.

## Como rodar

Requer Node 22 e, para os emuladores, Java 21 ou mais novo. Na máquina do Rafael:

```bash
export PATH=/opt/homebrew/opt/openjdk@27/bin:$PATH JAVA_TOOL_OPTIONS=-Duser.language=en
```

```bash
cd firebase/webapp
npm ci
npm run gen          # contrato
npm test             # vitest, inclui docs/web-app/contract-cases
npm run typecheck
npm run build        # build com orçamento (falha acima do limite)
```

Desenvolvimento, sempre contra o emulador (`demo-praticos`):

```bash
(cd ../functions && npm ci && npm run build)   # uma vez
npm run emulators    # terminal 1: suíte + seed
npm run dev          # terminal 2: http://localhost:5180/app/
```

Usuários do seed: `e2e/fixtures.mjs`, um por papel mais um sem empresa, com a senha do emulador que está nesse arquivo. Nada disso existe fora do emulador.

Testes de ponta a ponta:

```bash
npm run e2e                      # build, emulador, seed, Playwright
PW_ARGS=e2e/auth npm run e2e     # um arquivo
E2E_ONLY=auth,firestore,storage npm run e2e   # sem Functions (mais rápido)
npm run e2e:perf                 # 10 mil OS, Fast 4G + CPU 4x
npm run lhci                     # Lighthouse (precisa de build:e2e)
```

`E2E_ORDERS=10000` gera a lista grande no seed. Com outra cópia do repositório rodando os mesmos testes, `E2E_PORT_OFFSET=1000 npm run e2e` desloca todas as portas (emuladores e página); a configuração e o `.env.e2e.local` gerados saem no fim. O emulador sobe com `firebase/firebase.e2e.json`, em portas próprias, para não colidir com `firebase.test.json`. Segredos das Functions são falsos, criados só durante a execução.

A rota `/app/dev/components` mostra os componentes base. Existe só nos builds de emulador.

### Deploy

**Ordem:** a Function `api`, com a rota `/v1/app/web-access`, precisa estar no ar **antes** do Hosting com o `/app`. Sem a rota, toda conta cai em "não deu certo" na entrada. O deploy das Functions (`firebase-functions-deploy.yml`) e o do Hosting são workflows separados: no primeiro merge, confirme que o das Functions terminou antes de liberar alguém pelo script.

`firebase-hosting-deploy.yml` compila o site e, em seguida, a SPA (`npm run build:hosting`), que vai para `firebase/hosting/public/app`. O workflow dispara também com mudanças em `firebase/webapp/**`.

`firebase/firebase.json`:

| Caminho | O que faz |
|---|---|
| `^/app/[^.]*$` | rewrite para `/app/index.html`, antes dos outros rewrites. Só caminhos sem extensão: um asset que não existe (aba aberta antes de um deploy) dá 404, e não o `index.html` |
| `/app/assets/**` | `Cache-Control: public, max-age=31536000, immutable` |
| rotas do app e `index.html` | `Cache-Control: no-cache` |
| `/app/**` | CSP, `X-Content-Type-Options: nosniff`, `Referrer-Policy`, `X-Frame-Options: DENY` |

Uma aba aberta antes de um deploy pede chunks que já não existem. O app recarrega a página uma vez (`vite:preloadError` e erro de rota lazy, em `lib/stale-build.ts`). Se falhar de novo em menos de um minuto, o erro aparece, sem recarregar em loop.

A CSP libera os dois scripts inline do `index.html` por hash. Se um deles mudar, `npm run build` falha (`scripts/check-csp.mjs`) e mostra o hash novo para colar em `firebase.json`.

A configuração de produção fica em `.env.production`: só valores públicos, os mesmos do `firebase/web`.

`npm run check:hosting` sobe o emulador de Hosting com o `firebase.json` real e confere:

- `/app/orders/x` serve a SPA, com os cabeçalhos certos;
- os assets vêm com cache imutável;
- a tela de entrada abre sem bloqueio da CSP;
- o site, `/pricing` e `/robots.txt` continuam iguais.

`/q`, `/pro`, `/admin` e `/mcp` vão para o Cloud Run ou para as Functions. O script confere esses caminhos pela configuração, sem fazer requisição.

### Desempenho da lista

Fast 4G, CPU 4x, 10 mil OS, p75 de 7 rodadas, `npm run e2e:perf`. Cada passo é uma marca (`performance.mark`).

**O 1,4 s é de uma visita com login salvo:** sem cache HTTP nem do Firestore, mas com a sessão do Auth e o "sim" da lista de acesso guardados no navegador. É a visita normal de quem já usa o web.

| Caminho tentado | 1ª visita | Volta |
|---|---|---|
| Base: sessão em série, servida sem compressão | 2.603 ms | 2.208 ms |
| Servida com brotli, como o Hosting | 2.104 ms | 1.362 ms |
| Usuário e empresa em paralelo, consulta junto com o token, modulepreload, 1ª página de 30 | 1.324 ms | 880 ms |
| Mais cache persistente do Firestore, lendo da rede | 1.375 ms | 949 ms |
| Mais leitura do disco primeiro na volta | **1.400 ms** | **519 ms** |

Na 1ª visita, o tempo se divide assim:

- até `session:auth`: cerca de 830 ms, entre download, execução com CPU 4x e início do Auth;
- usuário, empresa e lista no Firestore: cerca de 520 ms, quase todo em idas e voltas da conexão.

Com a fatia de OS (filtro Em aberto por padrão, consulta por `status in`), medido em 2026-11-03: **1.379 ms** na 1ª visita e **501 ms** na volta.

Com a fatia de clientes e aparelhos, medido em 2026-11-03: **1.324 ms** na 1ª visita e **487 ms** na volta. A paleta, os atalhos e a folha "Mais" passaram a carregar sob demanda e os textos são divididos por funcionalidade; as telas novas usam só a API, sem nada novo no pedaço do Firestore.

O teste falha acima de 1,5 s. Ele roda sem o emulador de Functions e usa o "sim" da lista de acesso guardado, como numa visita depois da primeira.

**Primeira visita fria**, com a rota `web-access` (`npm run e2e:perf:cold`, emulador de Functions ligado): login salvo, sem cache e sem "sim" guardado. Resultado: **1.462 ms** de p75. A resposta da lista de acesso chega em 1.017 ms, em paralelo com as leituras do Firestore. O emulador não tem a partida a frio do Cloud Functions: em produção, com a instância parada, a rota pode somar alguns segundos a essa visita.

**Cache persistente:**

- É apagado ao sair pelo botão.
- É apagado quando a sessão termina de outro jeito: outra aba, token que não renova, conta desativada (`onAuthStateChanged` com `null`).
- É apagado quando entra outra conta.
- O dono do cache fica guardado (`praticos.cacheOwner`) até a exclusão dar certo, então uma falha é tentada de novo na próxima carga.
- Enquanto a exclusão não sai, as leituras ignoram o disco.

**Lista:** disco, páginas e servidor se juntam por id, em ordem de data e id. A paginação usa data e id no cursor, então nenhuma OS se repete nem some entre páginas. Se a lista veio do disco e o servidor não respondeu, aparece um aviso de que os dados podem estar desatualizados, com "Tentar de novo".

### Metas e guardas

| Guarda | Onde | Limite |
|---|---|---|
| JS da tela de entrada (brotli) | `scripts/check-budget.mjs` | 200 KB |
| JS até a lista, com Firestore | `scripts/check-budget.mjs` | 240 KB |
| Acessibilidade, LCP, CLS, TBT | `lighthouserc.json` | 100, 2,5 s, 0,1, 300 ms |
| axe em claro e escuro | `e2e/a11y.spec.ts` | 0 violações |
| Lista visível, p75, 1ª visita | `e2e/perf/list-visible.spec.ts` | 1,5 s |
| Scripts inline com hash na CSP | `scripts/check-csp.mjs` | todos |
| `/app` no emulador de Hosting | `scripts/check-hosting.mjs` | todos os itens |

CI: `.github/workflows/webapp_check.yml`, em PR que toque o web, os casos de contrato, os `.arb` ou a matriz de permissões.

## Como adicionar uma tela

1. Crie `src/views/MinhaView.vue`, começando por `PageHead`, com a resposta da tela no título.
2. Em `src/navigation.ts`, adicione a entrada com `access: { kind: 'member', anyOf: [...] }`. Se a tela não entra no menu, crie a rota em `src/router.ts`.
3. **Toda rota declara `meta.access`.** Sem isso a guarda nega, e `tests/access.test.ts` falha.
4. Em `src/router.ts`, aponte `component` para a nova view, com `import()`.
5. Textos: reuse as chaves do app quando o sentido for igual. Texto só do web vai nos três `src/i18n/web_*.json`, com prefixo `web.`.
6. Rótulo que muda por ramo usa `resolveLabel` de `lib/segments.ts`.
7. Dinheiro e datas sempre por `lib/format.ts`, com `session.company?.country`.
8. Cores só pelos tokens. Status com `StatusLabel`.
9. Atalho: `registerShortcut`. Comando da paleta: `registerCommand`. Remova os dois ao desmontar.
10. Cubra vazio, erro e carregando com `EmptyState`, `ErrorState` e `LoadingState`. Erro de API: `t(errorMessageKey(error))`, nunca o texto cru.
11. Adicione a tela a `e2e/a11y.spec.ts` e `e2e/guard.spec.ts`, e atualize `docs/web-app/parity-matrix.yaml`.

## Limitações

- Sem criação de empresa no web.
- Conta nova não aceita o primeiro convite (limitação do servidor, ver Convites).
- OS: falta Manutenções chegando, sino de avisos, iniciais no perfil, "Primeira vez" com E2E, campos do segmento, checklists, documentos, contrato, mandar ao cliente (link), nota fiscal, local editável, apagar foto e escolher aparelho por item com 2 ou mais aparelhos.
- `expectedUpdatedAt` só protege entre telas do web: o app grava itens sem atualizar `updatedAt` e regrava a OS inteira.
- O pedido do cliente fica no primeiro comentário interno (como no app); o campo `service_order.observation` do segmento ainda não é gravado pelo web.
- Quem não vê valores não tem tempo real: a OS é lida de novo depois de cada gravação e ao voltar à janela.
- Orçamento do primeiro download: 238,7 de 240 KB depois da fatia de clientes (era 239,0; a paleta, os atalhos e a folha "Mais" saíram do primeiro download e abriram 1,6 KB).
