# WEB_APP.md

## Visão Geral

App web do PraticOS: ferramenta de mesa para as mesmas contas e dados do app. Vue 3 + Vite, SPA estática em `/app` (https://praticos.app/app; ver "Domínios"), código em `firebase/webapp/`. A decisão está em `docs/web-app/ADR-001-web-architecture.md`, as regras de tela em `docs/WEB_APP_DESIGN.md`, e a referência visual é o protótipo da branch `claude/web-app-prototype-bb3bbf` (tema Campo). Quando protótipo e `WEB_APP_DESIGN.md` divergem, vale o protótipo.

Estado: fechado por lista de acesso. Tem entrada (Google, Apple, e-mail), convites, escolha de empresa, casca, permissões, componentes base a fatia "OS completa": Início com a lista de OS, Nova OS por teclado e a tela da OS (ver "Ordens de serviço"), a fatia "Clientes e aparelhos", a de mandar, receber e cobrar, a do Catálogo, a "Agenda", a de "Checklists", a de "Contratos", a de "Financeiro e notas fiscais" a de "Equipe, empresa e configurações" e o "Primeiro acesso" (ver as seções com esses nomes). O deploy em `/app` sai junto com o site.

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
| Sessão, empresa, rótulos do ramo e páginas da lista de quem vê valores | Firestore REST (`firebase/firestore/lite`), leitura única |
| Linhas ao vivo da lista e OS de quem vê valores | Firestore completo, com `onSnapshot`, carregado depois da lista aparecer |
| Lista e OS de quem não tem `viewPrices` | Projeção da API (`GET /v1/app/orders`, `/:id`), sem nenhum valor |
| Dinheiro, situação, itens, datas, responsável, parada, apagar | API (`lib/orders/writes.ts`) |
| Cliente e aparelho da OS, comentários, fotos | Firestore direto, só os campos que mudam (sem dinheiro) |
| Telas de clientes e aparelhos, cadastro, importação, próxima manutenção | API (`lib/customers/data.ts`): `/v1/app/customers`, `/v1/app/devices` |
| Agenda: leitura e mudar a data | API (`lib/agenda/data.ts`): `GET /v1/app/orders?sort=scheduledDate&startDate&endDate`, `PATCH /v1/app/orders/:id` com `expectedUpdatedAt` |
| Telas do catálogo: lista, cadastro, foto, importação, preços em lote | API (`lib/catalog/data.ts`): `/v1/app/services`, `/v1/app/products`; a foto vai para o Storage na pasta do item |
| Financeiro: Resumo, Receber e Relatório | API (`lib/finance/data.ts`): `GET /v1/app/finance/summary`, `/report`, `/receivable`; nenhuma OS lida no navegador para somar |
| Notas fiscais | Lista lida do Firestore REST (`invoices` por `effectiveDate`); prévia, emitir e cancelar pela API (`/v1/app/nfse/invoices*`) |
| Checklists: modelos e respostas na OS | Firestore direto (`lib/forms/data.ts`), cada gravação numa transação; fotos no Storage na pasta do checklist |
| Contratos: lista, contrato da OS e OS criadas por ele | Firestore REST com máscara de campos (`lib/contracts/data.ts`): nenhum valor da OS chega ao navegador; gravação só dos campos do contrato, com a versão lida como pré-condição |

Firebase é carregado sob demanda por `lib/firebase.ts`. A tela de entrada não baixa Firestore. Até a lista aparecer só vem o build REST (`firestoreLite()`, cerca de 29 KB); o cliente completo (`firestoreClient()`, cerca de 144 KB) chega depois, para as linhas ao vivo, a OS aberta e as gravações diretas. `scripts/check-budget.mjs` falha se o cliente completo entrar de novo no caminho até a lista.

### Sessão e permissões

O papel vem do claim `roles` do token, a mesma fonte das regras do Firestore. O documento `users/{uid}` só dá nome e ordem das empresas. Se ele listar uma empresa que o token ainda não conhece, o token é renovado. `refreshClaims()` força isso depois de aceitar convite.

`owner` é lido como `admin` e papel desconhecido não recebe nada, como no servidor. Sem `useFinancial`, as permissões financeiras somem.

A tela só decide o que mostrar. Quem protege é o servidor e as regras.

### Entrada

Mesmas portas do app (`lib/screens/login.dart`): Google, Apple e "Já tenho conta com e-mail", com senha e "Esqueceu a senha?". Conta nova só por Google ou Apple, como no app. O app não tem entrada por link de e-mail, então o web também não tem.

Google e Apple abrem em popup. Se o navegador bloquear o popup, a entrada segue por redirect (`shouldRedirect` em `lib/session.ts`). Para o redirect funcionar no Safari, o `authDomain` precisa estar no mesmo site do app, senão o Safari bloqueia o armazenamento entre sites. Por isso o `.env.production` usa `praticos.app`, o domínio principal, e o Hosting serve o handler em `/__/auth/handler` (caminho reservado, fora das regras de `/app`).

#### Domínios

O app web fica em **https://praticos.app/app**. O mesmo Hosting também responde em `praticos.web.app` e `praticos.firebaseapp.com`. Quem abre o `/app` num desses domínios antigos vai para `https://praticos.app` com o mesmo caminho, query e hash (`location.replace`). O script fica inline no `index.html`, logo depois do `charset`, e roda antes de o Firebase carregar (`scripts/legacy-host-plugin.ts`). `/q`, `/__/auth` e o site não mudam. O script só entra no build de produção: dev, emulador e build do E2E ficam onde estão.

Por que mandar para um domínio só:

- **Entrada:** o `authDomain` é `praticos.app`. Fora desse site, o popup funciona, mas o redirect de reserva (popup bloqueado) cai em armazenamento entre sites e pode falhar no Safari.
- **Sessão:** login, empresa escolhida, cache da lista de acesso e cache do Firestore ficam guardados por origem. Quem já tinha entrado em `praticos.web.app` entra de novo em `praticos.app`, uma vez.

Outros pontos:

- **CSP:** `frame-src` libera `praticos.app`, `praticos.web.app` e `praticos.firebaseapp.com` (o iframe escondido do Firebase Auth vem do `authDomain`). Tirar `praticos.web.app` e `praticos.firebaseapp.com` só quando o app deixar de ser servido neles.
- **API e lista de acesso:** não dependem do domínio. O CORS da `api` aceita qualquer origem (`origin: true`; quem protege é o token), e `config/webApp` decide pelo e-mail verificado do token.

O handler está cadastrado nos consoles (passo manual):

- **Google Cloud**, cliente OAuth "Web client (auto created by Google Service)": origens `https://praticos.app` e `https://praticos.web.app`, retornos `https://praticos.app/__/auth/handler` e `https://praticos.web.app/__/auth/handler`.
- **Apple Developer**, Services ID `br.com.rafsoft.praticos.app` (o mesmo do provedor Apple no Firebase): Sign In with Apple ligado, App ID principal `br.com.rafsoft.praticos`, domínios `praticos.app`, `praticos.web.app` e `praticos.firebaseapp.com` e os handlers de cada um.
- **Firebase Auth**, domínios autorizados: `praticos.app`, `praticos.web.app` e `praticos.firebaseapp.com`.

`praticos.web.app` e `praticos.firebaseapp.com` continuam cadastrados nos três, então voltar o `authDomain` para um deles funciona sem mexer nos consoles. Um domínio novo para o web precisa dos mesmos três cadastros, de uma entrada em `frame-src` e de trocar `VITE_FIREBASE_AUTH_DOMAIN`.

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
- Não depende do domínio: a mesma lista vale em `praticos.app` e em `praticos.web.app`.

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

**Lote.** Selecionar linhas troca a barra de filtros pelas ações: mudar a situação (só as que todas as selecionadas aceitam) e responsável. Cada OS vai pela API; o que o servidor recusa é contado no aviso, com o motivo de cada OS. Criar e Aplicar não repetem em duplo clique.

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

**Sobras fechadas (feat/webapp-leftovers).**
- Lista: a placa vem depois do veículo; de 64rem para cima, a coluna "Quando" mostra a visita (com a hora) ou a entrega, em vermelho quando atrasada, e a situação fica só com o nome. Abaixo disso as datas continuam na linha da situação.
- Seletores (`lib/orders/pickers.ts`): "Recentes" (5 clientes das últimas 50 OS, por `GET /v1/app/orders?limit=50`, então o consultor vê os das OS dele), "Pela placa ou série" a partir de 3 caracteres (escolher traz o dono, cliente da OS mais recente do aparelho, e o veículo juntos) e "Mais usados" no item da Nova OS (`meta.mostUsed` da rota do catálogo, um de cada tipo por vez). Na OS, o nome do veículo abre a troca: ✓ no atual, outro substitui no mesmo lugar e "Nenhum veículo" tira.
- Tela da OS: "Mais dados" com os campos `service_order.*` do segmento (`OrderCustomFields.vue`; só quem edita a OS muda, com obrigatório, mínimo, máximo e máscara conferidos antes de gravar). Local em Detalhes: "Pôr o local" (com `fieldService`), "Mudar endereço" e "Tirar endereço"; texto novo apaga `latitude` e `longitude`. "Apagar foto" no visualizador, com confirmação: uma transação tira só aquela foto e o arquivo sai do Storage. Com 2 ou mais veículos, "Mudar" no item diz de qual (ou Geral), pela API (`PATCH /items` com `deviceId`).
- Ao concluir (botão azul ou situação), depois de o servidor aceitar: "Quando é a próxima manutenção?" (`lib/orders/maintenance-offer.ts`), com as regras do app (`docs/DEVICE_NEXT_MAINTENANCE.md`): só com `manageDevices`, OS com veículo e sem contrato, veículos de contrato ativo fora, 3 recusas seguidas param a pergunta (por empresa, neste navegador), "Não repetir" tira só a data que esta OS cumpriu. A data vai por `PUT /v1/app/devices/:id/next-maintenance` com o `orderId`: o servidor tira dessa OS o cliente e o serviço principal (o do veículo ou o sem veículo), como o app, e grava `updatedAt`/`updatedBy`. Nova OS salva já concluída com veículo também pergunta, quando a OS abre.
- Servidor: a projeção da OS para quem não vê valores (`projectOrder`) passa a levar `address`, `latitude`, `longitude` e `customData` (sem dinheiro).
- Testes: `e2e/pickers.spec.ts`, `e2e/order-extras.spec.ts`, `e2e/maintenance-offer.spec.ts` e as linhas novas de `e2e/orders-list.spec.ts`.

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

**Contratos do aparelho.** A ficha lista os contratos ativos com o aparelho ("OS 12 · Todo mês" e a próxima), lidos pelo REST do Firestore com máscara (sem valores), e cada um abre a OS. Com contrato ativo, a próxima manutenção é a do contrato ("Pelo contrato") e a ficha não pede outra data. Marcar a data na ficha zera as recusas da pergunta ao concluir.

**Fica para depois.** Vínculo do aparelho cadastrado pela tela do cliente (não há campo de dono), foto do aparelho (a rota `PUT /v1/app/devices/:id` ainda não aceita a foto: precisa da regra do catálogo, com pasta do aparelho, `photoSeen` e apagar o antigo), ✓ por nome+telefone em cliente antigo sem id, e notas do cliente.

### Catálogo

Código em `src/views/catalog/`, `src/components/catalog/` e `src/lib/catalog/` (regras puras em `model.ts`, chamadas em `data.ts`). Testes: `tests/catalog.test.ts` e `e2e/catalog*.spec.ts`. Os textos ficam no mesmo pedaço dos de clientes (`-customers.json`), para não mexer no `src/i18n/index.ts` do primeiro download.

**Dados pela API.** `/v1/app/services` e `/v1/app/products` (ver `docs/WEB_API.md`). Quem não tem `viewPrices` (supervisor, ou "Valores e cobrança" desligado) recebe a lista sem o campo `value`: o preço não chega à rede nem a cache nenhum. Nenhuma tela desta fatia usa o Firestore. A Nova OS continua lendo o catálogo como antes (`lib/orders/catalog.ts`).

**Lista (`/catalog`).** Só com `viewServices` ou `viewProducts`; o técnico é barrado na rota (no app a rota aberta direto ainda assina serviços). Serviços (N) | Produtos (N), com o nome que o segmento dá aos produtos (`product._entity_plural`, ex. "Peças"); some quando o papel vê um tipo só. Tipo e busca na URL (`?kind=product`, `?q=`). Busca por nome, "contém", sem acento e sem caixa; ordem alfabética sem caixa (o app põe minúsculas e acentuados no fim). "Mais usados" do tipo no topo, sem busca. Preço só para quem vê valores, "sem valor" quando vazio. A linha abre o cadastro só para quem gerencia o tipo (só dono e admin); para os outros é só leitura. Vazio, erro com "Tentar de novo" e carregando por tipo. Dica do app no fim.

**Cadastro.** Gaveta com nome (exemplo por ramo), preço só para quem tem `editPrices` (`MoneyInput`: 150 é 150) e "Foto e mais dados" com a foto e os campos `service.*`/`product.*` do segmento. Salvar cinza até ter nome, `Ctrl/⌘ Enter`. A foto (escolher, colar ou arrastar, até 10 MB) espera no navegador e sobe para `tenants/{empresa}/{services|products}/{id}/photo.jpg` só depois de o item existir: cancelar não deixa item sem nome (defeito C9 do app). Editar manda a versão lida; se alguém salvou depois, nada é gravado e a lista relê. "Tirar a foto" manda também a foto vista e o servidor apaga só esse arquivo. Fechar com mudança pergunta (o app descarta a edição sem perguntar). Apagar fica no menu "…", com a confirmação do app, e leva a foto junto. Erro ao salvar ou apagar sempre aparece.

**Importar planilha (`/catalog/import`).** Igual à de clientes: CSV ou XLSX no navegador, colunas adivinhadas (nome, tipo, preço) e conferidas, linhas sem tipo no tipo escolhido. Ficam de fora: sem nome, tipo que não é serviço nem produto, preço que não dá para ler, nome que já está no catálogo (mesmo tipo, sem acento e sem caixa) e nome repetido na planilha. O preço é lido como digitado, pelo país da empresa ("R$ 1.234,56" é 1234,56) e só entra para quem tem `editPrices`. Nada grava antes de "Importar"; vai de 200 em 200 com id por linha, e o id da importação nasce na prévia: "Importar" de novo depois de uma falha não duplica.

**Preços em lote.** Na lista, para quem gerencia e tem `editPrices`: selecionar linhas, "Mudar preços", aumentar ou baixar por porcentagem (baixar até 100%), arredondar para inteiro. A prévia mostra cada item antes e depois; itens sem preço ficam como estão. "Aplicar" pede confirmação. A conta é em centavos. Até 500 itens por vez, num pedido e numa transação: o servidor grava todos ou nenhum (acima disso a tela pede para dividir). Cada mudança leva o preço que a pessoa viu e o lote leva uma chave (`batchId`). Se a resposta se perde, a prévia fica com o lote enviado e "Tentar de novo" manda exatamente o mesmo, nunca recalculado da lista relida: o que já mudou não muda outra vez. Um 409 (alguém mudou um preço) fecha a prévia, limpa a seleção e a lista mostra os preços novos. "Desfazer" no aviso segue a mesma regra. Fechar com resultado desconhecido relê a lista e pede para conferir.

**Fica para depois.** Abrir o cadastro do catálogo de dentro da Nova OS ("Novo item" → "Serviço ou produto?") e preços em lote dos dois tipos juntos (a seleção é por tipo). Toda gravação aqui esquece as listas da Nova OS (`forgetLists`), que relê o catálogo na próxima vez.

### Mandar ao cliente, receber e cobrar

Código em `src/components/orders/receive/`, regras puras em `src/lib/receive/model.ts` (dinheiro em centavos, testadas em `tests/receive-model.test.ts`) e chamadas em `src/lib/receive/data.ts`. Os textos ficam no pedaço de OS (`-orders.json`), fora do primeiro download. Testes: `e2e/receive.spec.ts`.

**Mandar para o cliente.** No cabeçalho da OS, no menu "…" e na tecla `M`, para todos os papéis. Usa o primeiro link válido de `GET /v1/app/orders/:id/share` ou gera um (`POST`, ver, aprovar e comentar, 7 dias); a URL é a que a API devolve, nunca montada no navegador. A mensagem segue a situação, o que o link permite, o rótulo do segmento e o idioma (`web.share.*`), com o nome da empresa na assinatura, e pode ser editada. "Mandar pelo WhatsApp" abre `wa.me` em nova aba com o telefone do cadastro do cliente (não a cópia guardada na OS); sem telefone, o botão azul copia a mensagem. Trocar o que o cliente pode fazer ou a validade gera um link novo, e o servidor desativa os anteriores. "Desativar o link" pede confirmação. OS sem cliente diz o que falta e oferece escolher o cliente.

**Receber de uma OS.** O "Receber" (`MoneyDialog`) pergunta quanto, como (nada vem marcado) e quando (nem no futuro nem antes da OS). "Já recebido" mostra cada pagamento e desconto, do dia mais novo, com forma, quem anotou e o comprovante. "Remover" e "Desfazer pagamentos" pedem confirmação e vão pela API (`DELETE /payments/:id`, `DELETE /discounts/:id`, `POST /payments/reset`). Pagamento do Asaas e parte de um recebimento de várias OS não saem daqui. OS em orçamento ou cancelada mostra só o histórico.

**Receber de um cliente em várias OS.** Gaveta "Receber de {nome}", aberta pelo cliente, pela seleção de OS de um mesmo cliente na lista (tela grande) e pelo Financeiro. Lista as OS em aberto (`GET /customers/:id/open-orders`), divide o valor da mais antiga para a mais nova e mostra a divisão e o total antes de gravar; uma confirmação repete os dois. Antes de gravar, relê os saldos: se algo mudou, avisa e não grava. O `receiptId` é gerado ao abrir e renovado quando o saldo muda ou a pessoa muda o que entra: repetir o mesmo pedido depois de a resposta se perder não grava em dobro, e um `RECEIPT_EXISTS` relê os recebimentos e mostra o valor gravado, nunca o digitado. O consultor vê as OS de outra pessoa à parte e desmarcadas.

**Comprovante.** No "Receber", quem tem `attachPhotos` anexa uma imagem ou PDF abaixo de 10 MB (outro tipo ou tamanho é recusado com frase antes de enviar); em "Já recebido", cada pagamento à mão tem "Anexar comprovante", "Trocar comprovante" e "Tirar comprovante" (este com confirmação). O arquivo sobe para `tenants/{empresa}/orders/{os}/payments/{pagamento}/receipt_{ms}.{ext}` com nome novo a cada vez (o servidor apaga o antigo depois de trocar, então os dois nunca dividem o caminho), e só depois vai a chamada (`POST /payments` com `receiptFile`, `PUT` e `DELETE /payments/:id/receipt`). Pagamento do Asaas e parte de recebimento de várias OS não mudam aqui. Gerente vê, não anexa: o servidor exige `attachPhotos` em `PUT`/`DELETE /payments/:id/receipt` e no `POST /payments` com arquivo, e recusa orçamento e cancelada (409 `ORDER_STATUS`). Se a API recusar depois do envio, o web apaga o arquivo que acabou de subir. Apagar foto só tira do Storage o que está na pasta de fotos da própria OS.

**E2E do comprovante.** O emulador do Storage serve `http://127.0.0.1:<porta>`, e o servidor só aceitava `https` do bucket. `validateReceiptFile` (`firebase/functions/src/services/payment-input.ts`) aceita a URL `http` do emulador só quando `FUNCTIONS_EMULATOR=true` e o host é o de `FIREBASE_STORAGE_EMULATOR_HOST`. Em produção nada muda: o Cloud Functions não define `FUNCTIONS_EMULATOR` e só passa `https` do bucket (teste em `services/__tests__/payment-input.test.ts`). Teste: `e2e/proof.spec.ts`.

**Recebimentos.** Na tela do cliente: lista (`GET /customers/:id/receipts`), recibo impresso pelo navegador e "Desfazer recebimento", com confirmação. O recibo não tem "Ainda falta": o recebimento não guarda o saldo daquele dia, e o saldo de hoje mudaria um recibo antigo.

**Cobrança (Asaas).** Quem recebe na OS (o consultor também) vê o link aberto só para ler; com link aberto, Receber deixa de ser o botão azul e avisa que a cobrança se ajusta. Criar, cancelar e gerar link novo só para quem tem `chargeOrder`, com `settings/payments.asaasEnabled` e `asaasConnected`. Na OS: cartão do link aberto (esperando, vencido, parcelas, o que falta fora do link), aviso "A OS mudou de valor" com "Gerar link novo" e "Manter o link" (guardado por cobrança neste navegador), parcelamento cancelado pelo servidor, copiar, mandar de novo e cancelar. "Mandar cobrança" pede valor (sempre em R$), vencimento (hoje + 3, nunca no passado), parcelas (só uma OS) e CPF/CNPJ quando o cadastro não tem um válido. Criar e mandar são um passo só: a folha vira "Mandar pelo WhatsApp" com o link do Asaas. Na gaveta do cliente: um link para várias OS, copiar e cancelar. O link mandado de novo é sempre o do Asaas, na OS e no cliente.

**Financeiro > Receber (`/finance/receive`).** Toda OS que ainda deve: concluída com saldo e aberta (aprovada ou em andamento) com sinal, para não repetir o P1 do teste do Marcos. Desde a fatia 6 vem do servidor (`GET /v1/app/finance/receivable`), por cliente, das dívidas mais antigas; antes o navegador lia até 20.000 OS sem pagar a cada visita. Se a empresa passar de 20.000 OS em aberto, um aviso diz que algumas podem faltar (qualquer uma, não necessariamente as mais antigas). Marcar OS de um cliente abre a gaveta de receber; OS de dois clientes não recebem juntas. `?customer=` abre direto o "Receber de" do cliente (vindo do Resumo).

**Imprimir várias OS.** Na seleção da lista (tela grande), cada OS numa página.

**No E2E** o WhatsApp nunca abre (os testes leem o link) e o Asaas é simulado: as rotas de cobrança são respondidas pelo teste, que grava o documento da cobrança como o servidor gravaria. O seed liga `settings/payments` na empresa A.

**Fica para depois.** Comprovante do recebimento de várias OS na tela do recibo, "Mandar de outro jeito" testado (o Chrome de mesa não tem `navigator.share`), "Mandar recibo" de um pagamento só, parte de recebimento abrindo o recebimento, link de OS única substituído pela cobrança de várias OS (confirmação), "Próxima cobrança" e Resumo do Financeiro, arquivo vindo de outro app, eventos de compartilhar no GA4 e o aviso "Pagamento recebido" no sino.

### Agenda

Código em `src/views/agenda/`, `src/components/agenda/` e `src/lib/agenda/` (regras puras em `model.ts`, testadas em `tests/agenda-model.test.ts`; textos e datas em `text.ts`; chamadas em `data.ts`). Textos no pedaço `-agenda.json`. Testes: `e2e/agenda.spec.ts`.

**Fuso e formato da empresa (todo o web).** `lib/zone.ts` guarda o fuso da empresa (`App.vue` acerta ao carregar a empresa); `lib/format.ts`, o dia de atraso, "hoje/amanhã" e o "só o dia" da meia-noite usam esse fuso, na lista, na OS e na agenda. Visita e entrega são gravadas como o app grava: hora da empresa sem fuso (`2026-11-03T14:00:00.000`; "Dia todo" é `T00:00:00.000`), pela agenda, pelo seletor da OS e pela Nova OS. Assim o app lê a mesma hora, o mesmo dia e o mesmo mês (revisão do #521, M1). Limite: a empresa não tem campo de fuso; ele vem do país, e o do navegador vale quando é do mesmo país (uma empresa em Manaus aberta num computador em São Paulo usa São Paulo).

Os dias são os do fuso do país da empresa (`companyZone`: Brasil é São Paulo; se o computador estiver em outro fuso do mesmo país, como Manaus, vale o dele; empresa sem país segue o computador), nunca os do computador: uma visita das 09:00 em São Paulo aparece às 09:00 num computador em Tóquio. O formato (24 h ou AM/PM, nome dos dias) segue o país, e as palavras, o idioma. O texto sem fuso que o app grava (`toIso8601String()`) é lido como hora da empresa; o que a API grava vem em UTC.

**Tela (`/schedule`).** Semana (padrão na tela grande) ou Dia, com a grade de horas de 7 às 19 (cresce para caber toda visita) e uma faixa "Dia todo" para meia-noite. O mês fica ao lado, com ponto nos dias com OS, inclusive os do mês vizinho. A semana começa no dia do país. Setas, `←` `→`, `T` (hoje) e o dia na URL (`?d=`, `?view=day`, `?who=`). Abrir a OS a põe ao lado (`?order=`); o que muda nela relê a agenda. Se o canal ao vivo do Firestore não responde em 6 s, a OS é lida uma vez pelo REST e o canal segue tentando; se essa leitura falha, aparece o erro com "Tentar de novo" (`watchOrder`, revisão B6). No celular (abaixo de 48 rem): faixa da semana, "Ver o mês" e a lista do dia com cliente e hora, situação · nº e aparelho · com responsável.

**Dados.** Pela API para todos os papéis: o servidor aplica quem vê o quê (o técnico vê as que criou e as atribuídas a ele, o que o app não faz) e tira os valores de quem não tem `viewPrices`. Pede a grade inteira do mês, com 14 h de folga de cada lado (o texto sem fuso é comparado como texto), e põe cada OS no dia pelo fuso da empresa. Até 30 páginas de 100; passou disso, um aviso diz que a lista foi cortada. Relê ao voltar à janela.

**Mudar a data (tela grande).** Arrastar o bloco para outra hora ou dia (de meia em meia hora) ou para "Dia todo". Pelo teclado, com o bloco em foco: `Shift` + `↑` `↓` meia hora, `Shift` + `←` `→` um dia; o bloco vai para onde ficaria, `Enter` confirma e `Esc` desfaz. Mudar uma visita que o cliente já esperava (tinha data, tem cliente, não está concluída nem cancelada) pergunta antes, com a data antiga e a nova e o lembrete de avisar o cliente. Depois de gravar, o aviso tem "Desfazer". Grava só a data (`PATCH /v1/app/orders/:id`, que confere `canEditOrderMainFields`), com a `version` lida; `409 ORDER_CHANGED` mostra o aviso e relê. Quem não pode mudar a data (supervisor e técnico fora do orçamento, consultor e técnico em OS de outra pessoa) não arrasta, e o teclado avisa.

**Sem agendamento.** Com `useScheduling` desligado na empresa, a agenda mostra as entregas (`dueDate`), todas como "Dia todo".

**De quem.** Admin, gerente e supervisor filtram por responsável (`assignedTo` no servidor). "Só de {nome}" com "Mostrar todos". Trocar de empresa tira o filtro.

**Fica para depois.** Faixa "Sem data" com as OS para marcar arrastando (o servidor não lista "sem campo"; precisaria de um filtro novo), mudar o responsável arrastando para a coluna da pessoa, aviso de conflito no mesmo horário, lembretes (no app são notificações locais; no web só com Web Push).

### Financeiro e notas fiscais

Código em `src/views/finance/`, `src/components/finance/`, `src/lib/finance/` (período em `period.ts`, palavras em `text.ts`, exportação em `export.ts`, chamadas em `data.ts`) e `src/lib/nfse/` (regras puras em `model.ts`, leituras e chamadas em `data.ts`). Textos no pedaço `-finance.json`. Testes: `tests/finance.test.ts`, `tests/contract-cases.test.ts` (`finance-period.json`) e `e2e/finance.spec.ts`, `e2e/finance-report.spec.ts`, `e2e/invoices.spec.ts`.

**Números do servidor.** O Resumo, o Relatório e o Receber pedem tudo pronto à API (`/v1/app/finance/*`, ver `docs/WEB_API.md`). Quem não tem `viewFinancialReports` (técnico, supervisor, consultor, ou "Valores e cobrança" desligado) não chega às telas e o servidor responde 403 sem número nenhum. O navegador manda o próprio fuso; o servidor só aceita se for do país da empresa.

**Resumo (`/finance`).** Recebido e Vendido do mês escolhido, A receber e Em andamento de hoje, e embaixo a lista do cartão escolhido (`?list=`). Mês na URL (`?month=AAAA-MM`), nunca no futuro; setas e teclas `←` `→`; o rótulo de um mês passado volta para hoje. Trocar de mês mantém os números antigos marcados como ocupados e descarta resposta atrasada. Erro só na primeira carga; relê ao voltar à janela. A receber por cliente abre o "Receber de"; as outras linhas abrem a OS ao lado (`?order=`), e fechar relê os números. "Notas fiscais · N" com a contagem de emitidas no mês e quantas precisam de atenção, nunca dinheiro; leitura que falha tira a linha (o app mostrava 0). "Ver o relatório" e "Outro período".

**Relatório (`/finance/report`).** Período na URL: `?kind=day|week|month|year&offset=-N` ou `?from=&to=` (datas próprias, de 2020 até hoje, as duas pontas incluídas). A semana vai de domingo a sábado, uma conta só para o rótulo, a busca e a exportação (contrato `finance-period.json`). Filtros na URL e só nesta visita: pagamento (`?payment=paid|unpaid`, a legenda; estreita as OS, a composição e os rankings de serviços e produtos, como o app, mas não os totais) e cliente (`?customer=`, o ranking). A OS abre ao lado (`?order=`). Escolher um cliente estreita os números, mas o ranking continua com todos. O rótulo volta ao período atual e tira os filtros. Faturamento, já pago e a receber (rótulos do segmento `financial.total_paid` e `financial.remaining`), OS, média, composição, rankings e as OS do período, 5 de cada com "Ver todos". Carregando, erro com "Tentar de novo" e vazio próprios.

**Exportar e imprimir (tela grande).** "Exportar CSV" (as OS do período, com `;` e vírgula decimal onde o país usa vírgula, BOM para os acentos, célula que começaria fórmula ganha apóstrofo) e "Exportar planilha" (XLSX montado no navegador, sem biblioteca: zip sem compressão com Resumo, OS, Clientes, Serviços e Peças, valores como números). Só sai o que o servidor deu a esse papel. "Imprimir ou salvar PDF" usa folha própria: todas as linhas, sem navegação; desabilitado no período sem OS.

**Notas fiscais (`/invoices`).** Para quem tem `chargeOrder`. Com a nota desligada na empresa (`settings/payments`: `nfseEnabled`, `asaasEnabled`, `asaasConnected`), a tela diz isso em vez de girar. Lista do mês (`?month=`): uma frase com o que saiu (emitidas e com cancelamento negado), "Precisa de atenção" no topo (erro não reemitido, conflito e cancelamento negado, do mês anterior a hoje em diante), a tabela com número, cliente e OS, situação em ponto e texto e valor. Lê `invoices` por `effectiveDate` do início pedido até o fim do mês (o app lia até hoje e o futuro). O seguinte vai até o mês de hoje mais 60 dias (nota agendada). Busca (`?q=`) só com mais de 10 notas, sem acento, por cliente, número e OS. A nota abre ao lado (`?invoice=`): situação e frase, valor, número, data, OS que abrem, motivo, aviso de conflito, PDF e XML da emitida, "Corrigir e emitir" e "Cancelar nota" (confirmação com "Manter nota" no foco; prefeitura que não cancela por aqui abre "Já cancelei na prefeitura").

**Emitir.** Na OS, "…" → "Emitir nota fiscal" (quem tem `chargeOrder`, nota ligada, OS fora de orçamento e cancelada), e "Corrigir e emitir" na nota com erro. A gaveta mostra a prévia do servidor (valor de cada OS, peças fora, desconto repartido, serviço da prefeitura), o texto editável, a data (de hoje até 60 dias; hoje vai vazio), o CPF/CNPJ quando falta e o e-mail e endereço com CEP que a prefeitura pede. "Emitir" fica cinza com o primeiro motivo (OS já com nota, nada a cobrar, CPF/CNPJ, contato). `CUSTOMER_DATA_REQUIRED` reabre a prévia com todos os campos e mantém o texto; erros de configuração mandam configurar no app. Fechar com algo mudado pergunta.

**No E2E** nenhuma nota é emitida: as rotas `/v1/app/nfse/*` são respondidas pelo teste (`page.route`), que grava o documento da nota como o servidor gravaria. O seed liga a nota na empresa A, grava duas notas do mês e um mês fechado com números conhecidos (março de 2026, `seedFinance`); a empresa C tem "Valores e cobrança" desligado.

**Fica para depois.** Próxima cobrança (sugestão, mandar e "Agora não"), configuração da nota (dados fiscais, serviço, quando emitir), uma nota com várias OS do cliente, notas de um cliente, compartilhar o PDF da nota, nota ao vivo na tela (relê ao voltar à janela e depois de cada ação), relatório de um cliente em PDF próprio e a linha "Nota fiscal" na tela da OS.

### Checklists

Código em `src/views/forms/`, `src/components/forms/` e `src/lib/forms/` (regras puras em `model.ts`, testadas em `tests/forms-model.test.ts`; Firestore e Storage em `data.ts`; oferta depois da Nova OS em `offer.ts`). Textos no pedaço de OS (`-orders.json`): o checklist abre dentro da OS e `src/i18n/index.ts` não muda. Testes: `e2e/forms.spec.ts` e `e2e/forms-a11y.spec.ts`. Não há protótipo destas telas; seguem `WEB_APP_DESIGN.md` e o app (`docs/formularios_dinamicos.md`).

**Formato.** O mesmo do app: modelos em `/companies/{cid}/forms/{id}` com as chaves de `FormDefinition.toJson` (`id`, `title`, `description`, `isActive`, `items`, `titleI18n`, `descriptionI18n`, `company`, `createdAt/By`, `updatedAt/By`), lidos também no formato antigo (`name`, `fields`, `requiresPhoto`). Na OS, `/companies/{cid}/orders/{oid}/forms/{iid}` com a cópia das perguntas (`formDefinitionId`, `title`, `status` `pending`/`in_progress`/`completed`, `items`, `responses`, `startedAt`, `completedAt`, `updatedAt`, `titleI18n`, `deviceId`). Resposta: `{ itemId, value, photoUrls }`; sim/não é `bool`, escolha é a opção original do modelo (mostrada traduzida), várias é a lista, texto e número são texto (número validado pelo país da empresa e gravado como digitado, como o app lê). Fotos em `tenants/{cid}/orders/{oid}/forms/{iid}/{itemId}_{ms}_{n}.{ext}`, o caminho do app: `storage.rules` libera só um nível abaixo do checklist, então `.../items/{itemId}/` seria recusado.

**App e web ao mesmo tempo.** Cada resposta é uma transação que relê o checklist e muda só a pergunta respondida (`applyChange`): valor novo mantém as fotos que outro pôs, foto nova mantém o valor, tirar foto tira só ela. Nada a migrar: o formato é o mesmo. As respostas de uma tela vão em fila, na ordem dada. Checklist concluído recusa resposta até ser reaberto (também a que estava sendo digitada). O web não apaga o que o app grava; o app ainda pode apagar o que o web grava: a tela do app não relê o checklist e troca a resposta inteira da pergunta (foto posta no web some, foto tirada no web volta), e a fila offline do app regrava a lista inteira. Isso vai para o lote de correções do app. Toda gravação do web é transação que lê antes: sem conexão ela falha e a tela diz, em vez de ficar na fila do navegador e aparecer como feita (a resposta fica marcada "Não deu para guardar", com "Tentar de novo").

**Checklists (`/checklists`).** Só com `manageForms` (dono, admin e supervisor), pela rota e pelo link em Configurações; o app abre para qualquer papel (defeito 27). "Seus checklists" ao vivo e "Prontos para usar" do segmento, cada um com carregando e erro. O pronto já copiado (mesmo id ou mesmo título) não aparece de novo. Ver o pronto, Usar (com confirmação, id novo e aviso). Apagar na linha, com a confirmação de apagar do app; se falhar, a linha fica.

**Editor.** Gaveta com nome, descrição e perguntas. Diz o que falta (nome, pergunta ou os dois). A pergunta (diálogo): texto, tipo (padrão Sim ou não, o primeiro da lista), opções uma por linha (2 ou mais), obrigatória e "Pode pôr foto"; "Só foto" nunca é obrigatória; tradução só fica com o mesmo texto. Reordenar arrastando, pelos botões ou com Alt + ↑/↓, no novo e na edição. Apagar pergunta com Desfazer dentro da gaveta. "…" com Parar de usar / Voltar a usar (na hora) e Apagar. Fechar com mudança pergunta, também ao sair da página. Salvar e Parar/Voltar a usar mandam a versão lida: se o app salvou depois, nada é gravado, a gaveta fica aberta com o que foi digitado e oferece "Recarregar" (descarta o texto e traz a versão salva) e "Copiar minhas perguntas".

**Limite do plano.** Igual ao app: o app só aplica limite onde há planos pagos para comprar (`FeatureGateService.planLimitsEnforced = paidPlansEnabled`, falso no navegador), então o web não trava (`WEB_PLAN_LIMITS_ENFORCED = false`) e uma empresa Free não fica sem saída. A regra do número (ativos `isActive != false` na lista; limite de `companies/{id}.subscription`, vencido vale Free) está em `activeLimit`, e enquanto o plano não for lido nada é bloqueado. Não há trava no servidor; o contador de uso continua com a Function `onFormTemplateWrittenUsage`.

**Na OS.** Seção "Checklists" com "x de y respondidas" ou "Completo", o aparelho e Remover (com confirmação). Adicionar segue `canManageOrderForms` (técnico só em orçamento, supervisor até concluir): com 2 ou mais aparelhos pergunta qual (ou Geral), depois "Qual checklist?" (ativos da empresa e prontos do segmento ainda não copiados, como o app, com "Da empresa" e "Globais" quando há os dois; por título, busca com mais de 10, erro com Tentar de novo) e "Novo checklist" para quem gerencia, que volta já escolhido. O pronto entra direto na OS, sem cópia, também para quem não tem `manageForms`.

**Preencher.** Gaveta com todas as perguntas, respondidas no lugar. Tab passa de pergunta, setas escolhem, espaço ou o número marca (1 é a primeira), Enter segue. Responder passa para a próxima sem resposta; sem nada faltando, o checklist é concluído e fecha (como o app depois da última). Começar/Continuar/Concluir em azul, "Concluir assim mesmo" só com opcionais faltando, obrigatória vazia lista o que falta. Fotos (JPEG, PNG ou WebP abaixo de 10 MB): escolher, colar (com a pergunta em foco) ou arrastar, ver uma a uma (← →), tirar com confirmação, e o arquivo sai do Storage. Concluído é só leitura; reabrem admin, gerente e supervisor. Responder segue `fillForms`: o gerente só lê (no app ele responde).

**Concluir a OS.** Com checklist que não está completo, o botão azul e "Mudar situação" param em "Falta terminar N checklist" e oferecem abrir o primeiro.

**Depois da Nova OS.** Com veículo e não concluída, a OS aberta pergunta "Fazer o checklist de entrada?". Três "Agora não" seguidos param a pergunta (por empresa, neste navegador). O app só pergunta no ramo automotivo; o web pergunta onde a empresa tem checklist ativo, porque o segmento não tem um campo para isso.

**Desempenho.** Medido em 2026-11-03: **1.088 ms** na 1ª visita e **704 ms** na volta. O caminho até a lista foi de 132,8 para 132,9 KB (a rota `/checklists` e o seu título no núcleo); as telas e os textos ficam fora do primeiro download.

**Fica para depois.** Câmera (exceção proposta: no computador é arquivo), conferir checklists pendentes no quadro e no lote, campo do segmento para a oferta do checklist.

### Extras de tela grande

Código em `src/lib/pdf/` (PDF), `src/lib/global-search.ts` e `src/components/CommandPalette.vue` (⌘K), `src/components/orders/BatchActions.vue`, `BatchConfirm.vue`, `BatchChargeDialog.vue` e `AiBatchDialog.vue` (lote). Testes: `tests/order-pdf.test.ts` e `e2e/pdf.spec.ts`, `e2e/palette.spec.ts`, `e2e/batch.spec.ts`, `e2e/power-a11y.spec.ts`. Tudo carrega sob demanda; o caminho até a lista só ganhou os textos da paleta e `canOpen` no `router.ts`.

**PDF da OS.** "Ver PDF" no menu "…" da OS e "PDF" na seleção da lista. Monta o arquivo no navegador com `pdf-lib` (e `qrcode-generator` para o QR), carregados só nesse momento (~190 KB gzip). Mesmo desenho do app (`docs/PDF_GENERATION.md`): cabeçalho da empresa em toda página, barra da situação com técnico e datas, cliente e resumo lado a lado, um bloco por aparelho (com "Geral" quando há itens sem aparelho), QR do link da OS, fotos (até 30), termos, assinaturas e uma página por checklist (sim/não, opções marcadas, texto, fotos até 8 por pergunta). Rótulos do segmento e textos dos `.arb` (os mesmos `pdf*` do app), dinheiro e datas pelo país da empresa. Regra de quem recebe igual à do app (`canShareOrderPdf`): quem vê preços, ou todos quando "Valores e cobrança" está desligado; sem `viewPrices` a OS vem da projeção da API e o PDF sai sem resumo, valores e subtotais. Várias OS: um arquivo, cada OS nas suas páginas e numerada por conta própria; OS que não abre fica de fora e o diálogo diz quantas. "Abrir" leva ao visualizador do navegador e "Baixar" salva `OS-186.pdf` (ou `OS-186-190.pdf`). A Helvetica só desenha WinAnsi: o que fica fora ("μ", "ő") sai pela Roboto de reserva do app (`assets/fonts/Roboto-Regular.ttf`), embutida só quando algum texto precisa; ela e o `@pdf-lib/fontkit` baixam só nesse caso. Sem marca d'água: o web não aplica limite de plano (`WEB_PLAN_LIMITS_ENFORCED`).

**Fotos no PDF em produção.** O navegador baixa as fotos do Storage com `fetch`, o que exige CORS no bucket. Sem CORS, as fotos ficam de fora e o PDF diz "Fotos disponíveis no sistema digital" (a regra do app para foto que não baixa). Passo manual do dono, uma vez: `gsutil cors set` no bucket com `GET` para `https://praticos.web.app` e `https://praticos.app`. A CSP já libera `*.googleapis.com` em `connect-src`.

**⌘K de qualquer tela.** Grupos OS, Clientes, Aparelhos (nome do segmento), Catálogo e Ações. OS pelo número em qualquer tela (a leitura da lista, por papel: Firestore para quem vê valores, a API para os outros); clientes, aparelhos e catálogo pela API, já cortados pelo papel no servidor, lidos ao abrir a paleta; preço só para quem vê valores. Ações: "Ir para" cada tela, importações, Checklists, Receber e o relatório. Cada grupo só aparece para quem abre a tela (`canOpen`, a mesma guarda das rotas): o técnico não vê catálogo, Financeiro nem Notas fiscais. O que a tela aberta já tem carregado (lista de OS, clientes) vem primeiro.

**Lote (tela grande).** Mudar a situação, pôr ou tirar o responsável, mandar cobrança, pedir ao assistente, PDF e imprimir. Toda mudança pergunta antes, com o número de OS que vão mudar (concluir deixa de fora a OS com checklist por terminar, como a tela da OS), cada OS com de → para e quantas já estão assim. Cada OS vai pela API com `expectedUpdatedAt`; o que o servidor recusa é contado no aviso. Desfazer volta cada OS ao que era quando o papel permite o caminho de volta; o que alguém mudou depois fica e o aviso diz quantas.

**Cobrança em lote.** Para quem tem `chargeOrder`, com o Asaas ligado e conectado. Um link por cliente: uma OS vira link da OS, várias do mesmo cliente viram um link do cliente. Antes de criar, mostra cada cliente com as OS e o valor que falta, e o que fica de fora e por quê: sem cliente, nada a receber, link já aberto da OS ou do cliente, sem CPF/CNPJ válido no cadastro (essas vão pela OS). O valor segue o Receber (`receivableOf`): concluída com saldo ou em andamento com sinal. Recusa do servidor aparece por cliente, com o motivo. Vencimento hoje + 3. Depois de criar, "Mandar pelo WhatsApp" e "Copiar" por cliente; "Desfazer" cancela os links criados, com confirmação.

**Assistente em várias OS.** Mesma rota da OS aberta (`POST /v1/app/ai/order-assist`), um pedido por OS; nenhuma rota nova, nenhuma flag mudada. Aparece só com `GET /v1/app/ai/status` ligado e todas as OS abertas a mudar itens. Prepara e mostra a lista do que cada OS ganharia, com ✦; nada é gravado antes de "Aplicar em N OS". Só põe itens do catálogo, como na OS aberta: nunca recebe, cancela nem apaga. Até 10 OS por vez; se a cota do mês não cobre a seleção, pede menos OS antes de chamar o modelo, e um `AI_QUOTA_EXCEEDED` no meio para e mostra o que já foi preparado. Desfazer tira o que entrou. No E2E o modelo é simulado com `page.route`.

**Desempenho.** Medido em 2026-11-03: lista em **1.080 ms** na 1ª visita e **702 ms** na volta; JS até a lista 133,8 KB.

**Fica para depois.** Mudar e tirar itens pelo assistente em lote (a rota devolve as mudanças, mas o web só aplica itens novos, como na OS aberta), PDF da nota fiscal, compartilhar o PDF pela folha do sistema (exceção proposta: baixar), lote no celular (sem seleção abaixo de 48 rem) e resultados da paleta com OS por cliente fora da lista.

### Contratos

Código em `src/views/contracts/`, `src/components/contracts/` e `src/lib/contracts/` (regras puras em `model.ts`, testadas em `tests/contracts-model.test.ts`; REST do Firestore em `data.ts`; textos em `text.ts`). Textos no pedaço de OS (`-orders.json`). Testes: `e2e/contracts.spec.ts` e `e2e/contracts-a11y.spec.ts`.

**Formato.** O do app: o contrato mora na OS que se repete (`isContract: true` e o mapa `contract` de `OrderContract.toJson`: `frequency`, `interval`, `startDate`, `endDate`, `nextDueDate`, `lastGeneratedDate`, `generatedCount`, `autoGenerate`, `active`, `reminderDaysBefore`, `parentOrderId`, `parentOrderNumber`). Datas como o app grava, hora da empresa sem fuso (`2026-12-03T00:00:00.000`), e a conta de calendário é feita nesse texto, sem passar pelo fuso do navegador (mensal no dia 31 rola como o `DateTime` do Dart). A OS criada por um contrato tem `contract.parentOrderId`. O web não acrescenta campo nenhum.

**Regra única: o web não cria OS.** Quem cria a OS do contrato é o app, ao abrir, ou o job do servidor (`docs/CONTRACTS_SERVER_JOB.md`, desligado). Nenhuma tela do web chama a geração. Quando a data passou e a OS ainda não nasceu, a linha diz "Ela nasce quando alguém da equipe abrir o app".

**Leitura.** `runQuery` e `GET` do REST do Firestore com máscara: só número, situação, cliente, aparelhos, autor, `isContract` e `contract`. Nenhum preço ou pagamento chega à rede, para nenhum papel (supervisor e técnico não veem valores), e nada vai para o cache do navegador. Consultor e técnico consultam com `createdBy.id`, como as regras pedem e como o app. Sem tempo real: a lista relê ao voltar à janela, depois de gravar e quando uma OS é criada ou muda no web.

**Gravação.** `documents:commit` com `updateMask` só dos campos do contrato que mudaram, mais `updatedAt`/`updatedBy`, e `currentDocument.updateTime` da leitura. Se a OS foi salva depois (pelo app ou outra aba), o web relê: se os campos do contrato que ele muda continuam iguais, grava sobre a versão nova; se mudaram, não grava, mostra "Alguém mudou este contrato" e põe a versão nova na tela. Sem conexão, a gravação falha e a tela diz (não fica em fila). As regras do Firestore não mudaram: quem pode editar a OS pode editar o contrato.

**Contratos (`/contracts`).** Pelo link em Ajustes (com `useContracts` ou para quem tem `manageCompany`) e pela URL, para qualquer papel que vê OS. Título "Contratos", ou "{OS} que se repetem" quando o ramo chama a OS de Contrato. Ativos e Encerrados, como no app (`active` diferente de `true` é Encerrado). Linha: cliente, frequência, aparelho e número da OS; ligado mostra a próxima OS, encerrado a data do fim. A linha abre a OS ao lado (`?order=`). "Ajustar" só para quem edita os campos principais daquela OS (técnico só em orçamento, consultor e técnico só nas suas). Vazio, erro com "Tentar de novo" e carregando. "Novo contrato" só com `canCreateOrder` (técnico e gerente não veem; no app o "+" não conferia, defeito 36).

**Contratos desligado.** Para que serve e "Usar contratos" para quem tem `manageCompany`, que grava só `useContracts` e mostra a lista. Os outros papéis leem que está desligado.

**Novo contrato.** A Nova OS com a seção Repetir (padrão do app: todo mês, começa hoje, sem término, criar sozinha). A OS é criada pela API e o contrato é gravado logo depois, com `generatedCount: 0`, `reminderDaysBefore: 3` e a próxima OS um período depois do começo. Se o contrato falhar, a OS fica e o aviso diz que nem tudo foi salvo; a seção Contrato da OS oferece "Repetir esta OS".

**Ajustar (gaveta).** Com que frequência (as 8 do app, mais a atual se for outra), começa, termina ou "Sem data para terminar" (o término nunca antes do começo; sugestão começo + 1 ano) e "Criar a OS sozinha", com a próxima OS calculada antes de salvar. "Salvar" grava de uma vez (o app grava a cada toque). A próxima OS conta os períodos a partir do começo e é a primeira de hoje em diante, depois da última criada: períodos perdidos não são repostos. "Avisar antes" não aparece: o app grava e nada lê (exceção proposta na matriz).

**Parar de repetir.** Pede confirmação e grava `active: false` e `endDate` de hoje: o contrato fica em Encerrados com o histórico (o app apaga o contrato, defeito 62). Grava o mesmo `active` que o app já usa, com o mesmo risco de hoje entre dois celulares.

**Sem pausa, por enquanto** (revisão do #527, A1 e M3). Ao abrir, o app lê os modelos do cache e, ao gerar, regrava o mapa `contract` inteiro, sem reler o modelo na transação. Um contrato pausado no web ganharia uma OS e voltaria a ativo, e um `pausedAt` que o app não conhece seria apagado. Pausar e Retomar voltam quando o app reler o modelo dentro da transação (lote 3 do app).

**Na OS.** Seção "Contrato": a frequência, a próxima OS, "Ajustar" e as OS criadas por ele (da mais nova), cada uma abrindo ao lado. Na OS criada, "Criada pelo contrato da OS N" abre a de origem. Sem contrato, "Repetir esta OS" para quem edita a OS, com Contratos ligado.

**Fica para depois.** Pausar e retomar (acima), contratos do aparelho (`device.detail.contracts`), a data da próxima manutenção pelo contrato, ligar e desligar Contratos nos dados da empresa, e o aviso antes da data.

### Primeiro acesso

Código em `src/views/onboarding/` e `src/lib/onboarding/` (regras puras em `model.ts`, testadas em `tests/onboarding.test.ts`; Firebase e API em `data.ts`). Textos no pedaço `-onboarding.json`. Testes: `e2e/onboarding.spec.ts`. Mesmo fluxo de `docs/ONBOARDING.md`.

**Portão.** Quem entra na lista de acesso sem empresa cai em `/no-company`, que lê os convites: com convite, mostra o convite antes, com "Começar sem convite"; sem nenhum, vai a `/start`. Erro ao ler os convites mostra erro com "Tentar de novo" e nunca manda criar empresa (fatia 01, 72). Quem está fora da lista não chega a nenhuma das duas.

**Passos (`/start?step=`).** "Qual é o seu ramo?" (só ramos `active`, por nome, nome no idioma), "O que você atende?" (só ramo com especialidades, todas marcadas) e "Para o cliente" (nome opcional quando a conta tem nome, telefone com a máscara `company.phone` do país, "Valores e cobrança" no padrão do ramo). Cada passo fica na URL, então o Voltar do navegador volta um passo. "Sair" no primeiro passo. Recarregar volta ao ramo.

**Criar.** "Criar meu PraticOS" ou "Começar sem exemplos":

1. Grava a empresa com o mesmo lote do app (`UserStore.createCompanyForUser` → `AuthService.signup`): `users/{uid}` (com `companies` e, se não existir, o cadastro), `companies/{id}` e `companies/{id}/memberships/{uid}` com papel admin, sob as mesmas regras. Os campos são os de `applyBusiness`, mais o país (o app não grava, defeito D8): região do navegador, senão a do idioma. Termos do ramo no idioma ativo.
2. Espera a claim (token renovado a cada 500 ms, até 20 s). Tempo esgotado é erro, não segue (D9).
3. `POST /v1/app/onboarding/seed` (ver `docs/WEB_API.md`): checklists sempre, exemplos só no botão azul, no idioma ativo.
4. Relê o token e entra na empresa, na Início.

Erro em qualquer passo mostra "Não deu para terminar…" com "Tentar de novo" (repete a última escolha) e "‹ Para o cliente" (volta ao formulário com o que foi digitado). A empresa salva fica guardada: tentar de novo completa a mesma, nunca cria outra. O id dela e a escolha ficam no `sessionStorage` (`lib/onboarding/pending.ts`): recarregar a página leva de volta ao primeiro acesso, que termina a mesma empresa (o roteador manda para lá enquanto houver pendência). Depois de pedir a cópia dos dados, o formulário não volta mais ao ramo. Um `409 ONBOARDING_ALREADY_SEEDED` conta como pronto.

**Fica para depois.** "Recebi um código de convite" (a tela de código não existe no web), empresa que já existe sem ramo (o app retoma o primeiro acesso para ela; o web abre normalmente) e os eventos de analytics (`tutorial_begin`, `company_created`, `tutorial_complete`).

### Início: manutenções, avisos e Agora

**Manutenções chegando** (`src/components/orders/Maintenances.vue`, `src/lib/orders/maintenance.ts`). Nas listas abertas (Em aberto, Minhas, Orçamentos, Paradas), sem busca: aparelhos com manutenção atrasada ou em até 7 dias, lidos pelo REST do Firestore depois da lista aparecer, sem os que têm contrato ativo (quem não lê contratos, técnico e consultor, vê todos, como no app). 3 de cada vez, "Ver mais N", atrasada em vermelho. A linha abre: "Chamar cliente" (só com cliente na data; telefone lido na hora; `wa.me` com a mensagem pronta, nada é enviado sozinho; sem telefone ou cliente apagado, um aviso), "Abrir OS" (quem cria OS: Nova OS com cliente, aparelho e os serviços da última OS concluída com o valor dela, lida pela API) e "Ver {aparelho}". Falha só esconde a seção.

**Sino e Avisos** (`src/lib/notifications/`, `src/views/notifications/`). O sino da Início mostra os avisos novos da pessoa (99+ acima de 99; o app conta no máximo 50), contados no servidor depois da lista. `/notifications` lista os 50 mais recentes em Novos e Antes, com o texto do app (aprovação sem o "da OS #", comentário, pagamento recebido, manutenção) e o tempo ("há 5 minutos", a data depois de um mês). Abrir marca como lido e abre a OS ao lado na Início (manutenção vai à Início). "Marcar todos como lidos" marca todos os novos, também os além dos 50. Os lembretes do app são do aparelho: o web não tem "Ajustar lembretes".

**Agora** (técnico, em Minhas, sem busca). A primeira visita de hoje ainda não começada, senão a em andamento, com "Abrir OS N"; ela não se repete na lista. As visitas de hoje em Minhas mostram a hora.

**Desempenho.** Medido em 2026-11-03 com esta fatia: **1.079 ms** na 1ª visita e **826 ms** na volta (`npm run e2e:perf`, p75). JS até a lista: 136,7 KB (134,6 na master com Configurações). O primeiro acesso, as manutenções e os avisos carregam sob demanda; no caminho até a lista entram só o sino, as iniciais, o "Agora" e as rotas novas.

**Iniciais.** O botão do perfil (no celular, no topo; no computador, ao lado do nome da empresa) mostra as iniciais da empresa (primeira e última palavra, sem "da/de/do/e"). No web ele leva a Ajustes.

### Equipe, empresa e configurações

Código em `src/views/settings/`, `src/components/settings/` e `src/lib/settings/` (regras puras em `model.ts`, testadas em `tests/settings-model.test.ts`; chamadas em `data.ts`). Textos no pedaço `-settings.json` (`FEATURES.settings` em `scripts/gen.mjs`), carregado com as telas. Testes: `e2e/team.spec.ts`, `e2e/company.spec.ts`, `e2e/settings.spec.ts`, `e2e/integrations.spec.ts`, `e2e/account-delete.spec.ts` e `e2e/settings-a11y.spec.ts`, cada um numa empresa própria do seed (gama, equipe e delta), para que desligar valores ou trocar papéis não mexa nos outros testes.

**Dados.** Equipe e convites só pela API, que confere o papel de quem convida e do convite: `GET/POST/DELETE /v1/app/invites` e `PATCH/DELETE /v1/app/team/members/:id`. A lista de pessoas vem de `companies/{id}/memberships` (leitura que todo membro tem). Empresa e perfil são gravados direto no Firestore, só os campos que mudam, com `updatedAt` e `updatedBy`, como o app (regras: dono/admin na empresa, a própria pessoa em `users/{uid}`). Logo em `tenants/{id}/logo/logo.jpg` e foto em `tenants/{id}/users/{uid}/photo.jpg`, os caminhos do app. Asaas por `/v1/app/payments/asaas/*` e conexões do ChatGPT e Claude por `/v1/app/integrations/tokens`. A exclusão de conta vai para a função `accountApi` (`…/api` vira `…/accountApi`).

**Configurações (`/settings`).** A conta primeiro (nome, e-mail, "empresa · papel"), depois só as linhas que o papel abre: Sua empresa (`manageCompany`), Equipe e Integrações (`manageUsers`), Plano (todos), Clientes, Catálogo, Checklists e a lista de aparelhos (com "Controle de aparelhos" ligado). Idioma, tema e atalhos ficam em "Neste navegador". "Sair" pede confirmação.

**Equipe (`/team`).** Só dono e admin. "N pessoas e M convites", o primeiro convite com os dias que faltam e "Reenviar convite", os convites (os vencidos aparecem, com "Convidar de novo": o app os esconde) e as pessoas (você primeiro, sem abrir; o dono também não abre). Convidar valida o e-mail de verdade e o WhatsApp (10 a 15 dígitos), grava e-mail em minúsculas e telefone só com dígitos. Repetido: "Reenviar existente" ou "Cancelar e criar novo". Convidar de novo e trocar um convite criam o novo antes de cancelar o velho, então ninguém fica sem convite (o app cancela antes). O código aparece com o prazo que o servidor devolveu, "Copiar código" é o botão principal e "Mandar pelo WhatsApp" abre `wa.me` em outra aba. Mudar papel e tirar da equipe pedem confirmação; o servidor guarda o dono e o último administrador, e a tela também confere antes. As vagas são contadas no servidor (`usersActive`) e a Equipe mostra a contagem, sem bloquear: o app não aplica limite de plano no navegador, e o web segue a mesma regra dos checklists (`WEB_PLAN_LIMITS_ENFORCED` em `lib/plan-limits.ts`). Nem o servidor confere o limite do convite; criar esse limite é decisão do dono. O WhatsApp do convite segue a máscara de telefone do país da empresa. Na tela grande, a tabela "O que cada papel pode fazer", lida da matriz gerada de `app-permissions.json`; com "Valores e cobrança" desligado, as permissões de dinheiro aparecem como desligadas.

**Sua empresa (`/settings/company`).** Dono e admin. "Nome, logo e contato": nome obrigatório, e-mail e site conferidos, máscara do telefone pelo país escolhido no formulário (`company.phone` do segmento), só os países que têm moeda e fuso em `lib/format.ts` e `lib/zone.ts` (nome traduzido; um país gravado pelo app fora da lista continua), logo que espera o "Salvar" e pergunta antes de descartar. Grava só os campos que mudaram, numa transação que confere o `updatedAt` lido: se o app ou outra aba salvou depois, nada é gravado e a tela avisa. O app ainda grava a empresa inteira a partir da cópia que abriu, o que pode desfazer uma mudança do web (lote 3 do app). Termos com "Usar texto padrão do segmento" só com o campo vazio; vazio grava nulo. Ramo pede confirmação e tira as especialidades; especialidades só quando o ramo tem. Interruptores (Valores e cobrança, Agenda, Atendimento no local, Contratos, Controle de aparelhos) mudam na hora, travam enquanto salvam e voltam com aviso se falhar. Desligar "Valores e cobrança" pede confirmação e esconde Financeiro, preços e cobrança na hora, sem recarregar (`session.company.useFinancial`). A sessão escuta `companies/{id}` ao vivo (`followCompany` em `lib/session.ts`, 1,5 s depois da primeira tela, fora do caminho até a lista): desligar pelo app ou por outra aba também esconde na hora.

**Plano (`/settings/plan`).** Todos os papéis, só leitura: plano em vigor (problema no pagamento em vermelho, cortesia, renova em, válido até), uso do assistente, da equipe, das fotos e dos checklists com "quase no limite" (80%) e "no limite", e o bloco do primeiro limite atingido. Os limites são os mesmos do app e do servidor. Nada de compra, preço ou "Ver planos" no web. Equipe e Checklists abrem só para quem os gerencia. Erro no uso do assistente aparece, em vez de a linha sumir.

**Sua conta (`/settings/account`).** Perfil (nome obrigatório, foto que espera o "Salvar"), trocar de empresa (pelas empresas do token), entrar com código de convite (maiúsculas e `INV_` como o app, pergunta antes e entra na empresa nova), sair e apagar a conta. Apagar: aviso, confirmação forte (escrever o próprio e-mail), e a mesma reautenticação do app quando o servidor pede login recente (senha na conta de e-mail, Google ou Apple), com a confirmação final de novo depois. Recusas do servidor (dono com equipe, posse que não confere, tempo esgotado, rede) têm frase própria.

**Integrações (`/settings/integrations`).** Dono e admin. Asaas só para empresa do piloto: conectar com a chave (que não volta para a tela), conta, ambiente, painel e desconectar com confirmação. Conexões do ChatGPT e do Claude: a URL aparece uma vez só, com "Copiar URL", e desligar pede confirmação.

**No E2E** o Asaas e o uso do assistente são simulados pelo teste (`page.route`); equipe, convites, tokens e exclusão de conta rodam de verdade no emulador. Uma gravação recusada da empresa é simulada por `sessionStorage` só nos builds de emulador (`praticos.e2e.failCompanyWrite`).

**Servidor.** `GET /v1/app/invites` devolve também o nome digitado no convite. `DELETE /v1/app/invites/:token` responde 404 (e não 500) para convite antigo sem `company`, e passa a deixar o dono ou um admin da empresa cancelar um convite que outra pessoa mandou: a rota já conferia isso, mas o serviço só aceitava quem criou (o app tinha a mesma falha). Testes em `firebase/functions/src/__tests__/invite-list.test.ts`.

**Desempenho.** Medido em 2026-11-03 com a máquina carregada: **1.093 ms** na 1ª visita e **700 ms** na volta. O caminho até a lista foi para 134,6 KB (as rotas novas no `router.ts` e o carregador dos textos); as telas e os textos ficam fora do primeiro download.

**Versão.** O rodapé de Configurações diz "PraticOS web {dia do build} ({commit})", gravado no build (`__WEB_VERSION__` em `vite.config.ts`, pelo `GITHUB_SHA` no CI ou `git rev-parse`).

**Fica para depois.** Lembretes (locais do aparelho; no web só com Web Push), Avaliações, compra e gestão de plano (decisão do dono), aceitar o primeiro convite de quem não tem empresa (limitação do servidor, ver Convites).

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

A CSP libera os três scripts inline do `index.html` por hash (domínio antigo, tema e preload). Se um deles mudar, `npm run build` falha (`scripts/check-csp.mjs`) e mostra o hash novo para colar em `firebase.json`.

A configuração de produção fica em `.env.production`: só valores públicos, os mesmos do `firebase/web`.

`npm run check:hosting` sobe o emulador de Hosting com o `firebase.json` real e confere:

- `/app/orders/x` serve a SPA, com os cabeçalhos certos;
- os assets vêm com cache imutável;
- a tela de entrada abre sem bloqueio da CSP;
- `/app` em `praticos.firebaseapp.com` (apontado para o emulador) vai para `praticos.app` com caminho, query e hash, sem pedir nada fora antes, e o site nesse domínio fica onde está. O teste usa `firebaseapp.com` porque o navegador só abre `web.app` por https (HSTS);
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

Com a fatia de mandar, receber e cobrar, medido em 2026-11-03: **1.325 ms** na 1ª visita e **487 ms** na volta.

Com a fatia do catálogo, medido em 2026-11-03 com a máquina carregada (outros emuladores rodando): **1.334 ms** na 1ª visita e **659 ms** na volta. As telas do catálogo são rotas sob demanda e só usam a API; no caminho até a lista entram só as duas rotas novas no `router.ts` (239,3 KB contra 239,1 KB da master).

Com o Firestore REST até a lista (fatia da agenda), medido em 2026-11-03 nesta máquina: **1.104 ms** na 1ª visita e **706 ms** na volta. Na mesma máquina e no mesmo dia, antes da mudança: 1.328 ms e 520 ms. O caminho até a lista caiu de 239,1 KB para 130,4 KB (brotli); com a agenda (atalhos e textos no núcleo), 131,1 KB.

| Caminho medido | JS até a lista | 1ª visita | Volta |
|---|---|---|---|
| Antes: Firestore completo com cache persistente | 239,1 KB | 1.328 ms | 520 ms |
| Firestore REST (`lite`) para sessão, rótulos e páginas; completo depois, só para o tempo real | **130,4 KB** | **1.104 ms** | 706 ms |

Com a fatia do Financeiro e das notas fiscais, medido em 2026-11-03: **1.078 ms** na 1ª visita e **702 ms** na volta; JS até a lista 133,0 KB (132,6 antes: rotas novas no `router.ts`, o pedaço de textos `finance` e o `detail` do erro da API). As telas do Financeiro, do relatório e das notas carregam sob demanda.

- **Por que REST e não a API:** `GET /v1/app/orders` também tiraria o Firestore do caminho, mas passa pela Function (partida a frio em produção) e não roda no teste de desempenho, que fica sem o emulador de Functions. O REST lê direto do Firestore, com as mesmas regras, e não abre o canal do cliente completo, que custa idas e voltas.
- **Auth em pedaço menor:** não muda nada. O Auth já usa `initializeAuth` sem o resolvedor de popup (8,2 KB); o popup só baixa ao entrar.
- **A volta ficou mais lenta (520 para 706 ms):** antes ela lia a lista do disco (cache persistente). Agora a 1ª página sempre vem do servidor. Continua bem abaixo da meta e a 1ª visita, que é a meta, ficou 220 ms mais rápida. O cache persistente continua no cliente completo (OS aberta) e as regras de apagar ao sair não mudaram.
- **Sem dados velhos na 1ª página:** como ela não vem mais do disco, o aviso "pode estar desatualizado" só aparece quando falha uma página seguinte.

O teste falha acima de 1,5 s. Ele roda sem o emulador de Functions e usa o "sim" da lista de acesso guardado, como numa visita depois da primeira.

**Primeira visita fria**, com a rota `web-access` (`npm run e2e:perf:cold`, emulador de Functions ligado): login salvo, sem cache e sem "sim" guardado. Resultado: **1.462 ms** de p75. A resposta da lista de acesso chega em 1.017 ms, em paralelo com as leituras do Firestore. O emulador não tem a partida a frio do Cloud Functions: em produção, com a instância parada, a rota pode somar alguns segundos a essa visita.

**Cache persistente:**

- É apagado ao sair pelo botão.
- É apagado quando a sessão termina de outro jeito: outra aba, token que não renova, conta desativada (`onAuthStateChanged` com `null`).
- É apagado quando entra outra conta.
- O dono do cache fica guardado (`praticos.cacheOwner`) até a exclusão dar certo, então uma falha é tentada de novo na próxima carga.
- Enquanto a exclusão não sai, o cliente completo fica só na memória e não lê o disco. A sessão e a lista nunca leem o disco (Firestore REST).

**Lista:** páginas e linhas ao vivo se juntam por id, em ordem de data e id. A paginação usa data e id no cursor, então nenhuma OS se repete nem some entre páginas. Se uma página seguinte falha, aparece um aviso de que os dados podem estar desatualizados, com "Tentar de novo".

### Metas e guardas

| Guarda | Onde | Limite |
|---|---|---|
| JS da tela de entrada (brotli) | `scripts/check-budget.mjs` | 200 KB |
| JS até a lista, com Firestore REST | `scripts/check-budget.mjs` | 240 KB |
| Firestore completo fora do caminho até a lista | `scripts/check-budget.mjs` | sim |
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

- Conta nova não aceita o primeiro convite (limitação do servidor, ver Convites).
- Primeiro acesso: falta o código de convite e a empresa sem ramo (ver "Primeiro acesso").
- OS: falta documentos e linha "Nota fiscal" com a situação.
- `expectedUpdatedAt` só protege entre telas do web: o app grava itens sem atualizar `updatedAt` e regrava a OS inteira.
- O pedido do cliente fica no primeiro comentário interno (como no app); o campo `service_order.observation` do segmento ainda não é gravado pelo web.
- Quem não vê valores não tem tempo real: a OS é lida de novo depois de cada gravação e ao voltar à janela.
- Orçamento do primeiro download: 136,1 de 240 KB com as sobras (coluna Quando e versão). Antes, 133,0 desde a fatia do Financeiro (131,3 com a agenda; era 239,1 KB, 239,3 com o catálogo antes da agenda). As telas novas ficam fora do primeiro download.
