# Web app: benchmarks de arquitetura

Medições de 31/10/2026 para decidir como construir o web app. Dados 100% sintéticos, no Firebase Emulator (projeto `demo-praticos`). Nenhuma leitura ou escrita de dados de cliente.

## Resultado

**Recomendação: SPA Vue 3 + Vite, estática no Firebase Hosting (opção C).** O Nuxt continua servindo `/q`, `/pro` e `/admin`, e os dois compartilham tokens e componentes.

A hipótese inicial (Nuxt, opção B) perdeu, mas por pouco e por um motivo de entrega: depois de enxugada, ela empata com a C em tudo que o usuário sente na volta ao app. A diferença real é que a C não tem Cloud Run no caminho do HTML. O Flutter Web (opção A) perdeu para as metas de produto: é a opção com o maior reuso e a pior experiência de web.

| Meta | A CanvasKit | A Wasm | B Nuxt como está | B Nuxt enxuto | **C Vite** |
|---|---|---|---|---|---|
| Lista visível, 1ª visita (p75) | 5.719 ms | 5.338 ms | 2.392 ms | 2.029 ms | **1.690 ms** |
| Lista visível, com cache (p75) | 2.610 ms | 1.927 ms | 1.563 ms | 1.369 ms | **1.350 ms** (580 ms com cache primeiro) |
| LCP do navegador, 1ª / cache | não mede | não mede | 2.396 / 1.568 ms | 2.032 / 1.374 ms | **1.046 / 694 ms** |
| INP < 150 ms | 212 ms | 124 ms | 168 ms | 32 ms | **32 ms** |
| INP com semântica ligada | 296 ms | 200 ms | não muda: o DOM é o mesmo | não muda | **não muda** |
| 1ª visita em brotli, sem o índice de busca | 3.133 KB | 2.751 KB | 1.309 KB | 181 KB | 194 KB |
| Ctrl+F e impressão com texto | não | não | sim | sim | **sim** |
| Abrir em nova aba (Cmd/Ctrl+clique) | não | não testado | sim (mesmo `<a>`) | sim | **sim** |
| axe no protótipo, violações | 1 (zoom bloqueado); 3 com semântica | 3 com semântica | 2 (título e `lang`) | não rodado | **0** |
| Código real reaproveitado no protótipo | 50 arquivos, 7,8 mil linhas | igual | 0 linhas de Dart | 0 | 0 |

Perfil: CPU 4x, Fast 4G, 7 rodadas, p75. Tabela completa abaixo.

## Situação das metas

| Meta | Situação na opção C | Motivo |
|---|---|---|
| LCP p75 < 1,5 s | Passa no LCP do navegador. Na lista visível, passa com cache (1.350 ms) e no cabo (1.118 ms), mas **falha por 190 ms** na 1ª visita em Fast 4G | Ver abaixo |
| INP < 150 ms | Passa (32 ms) | |
| Busca < 200 ms | Passa: MiniSearch p95 de 6,6 ms com CPU 4x, tecla até a tela em 32 ms. **O difícil é montar o índice, não consultar** | Ver "Busca global" |
| Zero vazamento entre empresas | 16 de 16 testes nas regras reais | Vale para leitura direta. A projeção por empresa muda esse quadro, ver "Busca global" |
| 50+ linhas | Só com linha de 18 px | 24 px cabe 41 linhas em 1080p e 28 em 768p. Ver "Densidade" |

**Por que a 1ª visita em Fast 4G não bate 1,5 s.** A latência de 165 ms por ida e volta domina. Antes da lista aparecer são pelo menos HTML, JS, login, consulta da conta e o aperto de mão do canal do Firestore, cerca de 1 s só de espera. Além disso, 192 KB dos 194 KB são SDK do Firebase. O login automático do benchmark soma uma ida e volta (cerca de 165 ms) que uma sessão salva não teria, então o número real deve ficar perto do limite. Ainda não testado: `initializeAuth` só com o necessário, `modulepreload` e `preconnect`.

O que resolve a volta ao app é pintar do cache primeiro: 1.350 ms cai para 580 ms, com sessão salva de verdade. **Esse é o padrão a adotar.**

**Atenção ao LCP.** Na opção C o navegador credita o título `H1`, que aparece antes das linhas. Por isso a meta deve ser acompanhada pela marca "lista visível", não pelo LCP sozinho. No Flutter o LCP nem existe, porque o conteúdo é desenhado em canvas: o Chrome não registrou nenhum candidato em nenhuma rodada. Métrica de campo também ficaria cega.

## Tabela completa

Fast 4G, CPU 4x, 1920×1080, build de produção, p75 de 7 rodadas (5 nas variantes com semântica).

| Variante | FCP 1ª | Lista 1ª | Lista cache | LCP 1ª / cache | TTI 1ª / cache | INP | Busca | Clique | Setas | Abrir detalhe | Rolagem p95 | Quadros > 50 ms |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| A CanvasKit | 4.776 | 5.719 | 2.610 | n/a | 6.148 / 2.610 | 212 | 212 | 80 | 56 | 161 | 17 | 0% |
| A CanvasKit + semântica | 4.936 | 5.964 | 2.712 | n/a | 5.964 / 2.712 | 296 | 296 | 72 | 88 | 152 | **83** | **38,5%** |
| A Wasm | 4.551 | 5.338 | 1.927 | n/a | 5.925 / 2.054 | 124 | 124 | 64 | 28 | 114 | 17 | 0% |
| A Wasm + semântica | 4.583 | 5.443 | 2.017 | n/a | 5.963 / 2.235 | 200 | 200 | 40 | 48 | 95 | 50 | 0,8% |
| B Nuxt como está | 1.442 | 2.392 | 1.563 | 2.396 / 1.568 | 2.392 / 1.563 | 168 | 32 | 16 | 16 | 458 | 17 | 0% |
| B + cold start de 2 s | 3.234 | 4.183 | 3.388 | 4.184 / 3.392 | 4.183 / 3.388 | 96 | 32 | 16 | 16 | 449 | 17 | 0% |
| B Nuxt enxuto | 1.380 | 2.029 | 1.369 | 2.032 / 1.374 | 2.029 / 1.369 | 32 | 32 | 16 | 20 | 268 | 17 | 0% |
| C Vite | 1.046 | 1.690 | 1.350 | 1.046 / 694 | 1.690 / 1.350 | 32 | 32 | 24 | 16 | 259 | 17 | 0% |
| C + cache primeiro + sessão salva | 1.040 | 1.686 | **580** | 1.040 / 514 | 1.686 / 580 | 32 | 32 | 16 | 16 | 252 | 17 | 0% |

Tempos em ms. "Abrir detalhe" vai do clique até o detalhe pintado. INP é a pior interação da rodada (busca, clique, Esc, setas, Enter). Rolagem é o intervalo entre quadros, então o p95 de 17 ms equivale a 60 fps.

Cabo (5 Mbps, 28 ms, CPU 4x, 5 rodadas):

| Variante | Lista 1ª | Lista cache | INP |
|---|---|---|---|
| A CanvasKit | 6.662 | 1.984 | 224 |
| A Wasm | 5.811 | 1.360 | 112 |
| B Nuxt enxuto | 1.166 | 797 | 32 |
| C Vite | 1.118 | 784 | 32 |

"B enxuto" é o Nuxt sem as fontes do Google e sem o `logo.png` de 1,1 MB usado como ícone no `head`. Essa limpeza é pré-requisito da opção B, não ganho gratuito: em `firebase/web` ela afeta o site inteiro. A causa exata dos 168 ms de INP do Nuxt como está (vêm do voltar com Esc) não foi isolada, mas eles somem na versão enxuta.

### Tamanho da primeira visita

Transferido de verdade, sem o índice de busca, que é igual em todas (185 KB em brotli).

| Variante | Brotli | Gzip (arquivos locais) | Observação |
|---|---|---|---|
| A CanvasKit | 3.133 KB | 3.510 KB + externos | `canvaskit.wasm` 1.579 KB, `main.dart.js` 617 KB, mais 445 KB de CDNs do Google |
| A Wasm | 2.751 KB | 3.007 KB + externos | `skwasm.wasm` 1.164 KB, `main.dart.wasm` 718 KB |
| B como está | 1.309 KB | não medido | 1.127 KB são o `logo.png` |
| B enxuto | 181 KB | 197 KB | |
| C | 194 KB | 223 KB | |

A opção A leva junto o que o protótipo nem usa: mapeamentos do RevenueCat (174 KB), Font Awesome (280 KB), Google Sign-In (101 KB) e os SDKs de Storage, Analytics e Messaging. Registrar os plugins no pubspec basta para carregá-los. **O app inteiro compilado para web dá 7,8 MB de `main.dart.js` (1,42 MB em brotli) antes do CanvasKit**, 2,2 vezes o protótipo.

## Cloud Run e cold start

Configuração lida de `praticos-web`: 1 vCPU, 512 MiB, concorrência 80, máximo de 3 instâncias, sem instância mínima (escala a zero) e com CPU boost na partida.

| Sinal | Valor |
|---|---|
| Partidas de instância nos logs | Cerca de 30 em 8 dias, a maioria em horário comercial |
| Latência de requisição, últimos 14 dias (247 amostras) | p50 0,24 s, p75 2,4 s, p90 7,2 s, máximo 8,6 s |
| Requisições acima de 2 s | 28% |
| `/admin/login` medido de fora (shell SPA) | 2,04 s na primeira, 0,36 a 0,46 s nas seguintes |

Com pouco tráfego, boa parte das visitas cai em instância fria. Simulando 2 s de cold start, a lista vai de 2,4 s para 4,2 s, e a volta com cache de 1,6 s para 3,4 s, porque o HTML é `no-cache`. É o argumento decisivo contra servir o HTML do app por Cloud Run. Os 7 s de p90 provavelmente são SSR de `/q` chamando a API, não shell SPA, e por isso os 2 s simulados são a estimativa otimista.

Saídas para manter a B: shell estático no Hosting (na prática, vira a entrega da C) ou instância mínima 1 (gasto recorrente, precisa de aprovação).

## Teclado, acessibilidade e densidade

| Teste | A (Flutter) | B e C (Vue) |
|---|---|---|
| Árvore de acessibilidade na carga | 13 nós, nenhuma tabela. Só o botão oculto "Enable accessibility" | 1.189 nós: tabela, 51 linhas, 350 células, 50 links |
| Com semântica ligada | 1.240 nós, tabela e linhas, **58 violações críticas de axe** (`aria-required-children`, `aria-required-parent`) | Não se aplica |
| Zoom | Flutter injeta viewport que bloqueia zoom (violação `meta-viewport`, WCAG 1.4.4) | Livre |
| Axe | Ver tabela do início | C: 0 violações. B: `document-title` e `html-has-lang`, de correção simples |
| `/`, setas, `j`/`k`, Enter, Esc | Funcionam, depois de corrigir o foco na volta do detalhe | Funcionam |
| Foco visível no Tab | Só no campo de busca | Em cada parada |
| Atalhos do navegador | Ctrl+F, L e D não são capturados | Iguais. Ctrl+K pode ser usado pelo app |
| Ctrl+F em linha renderizada | Não acha. Só com semântica ligada | Acha |
| Ctrl+F em linha fora da janela virtualizada | Não acha | **Também não acha**: a busca do app precisa cobrir isso |
| Selecionar e copiar | Sem semântica, copiou vazio. Com semântica, copiou sem separar colunas | Copia com tabulação, cola certo em planilha |
| Impressão | 1 página de imagem, 1 caractere de texto | 2 páginas com texto, **só as linhas renderizadas**: relatório impresso exige tela própria |
| Link direto `/app/orders/{id}` | Funciona | Funciona |
| Voltar / avançar | Voltar funciona. **Avançar não**, com Navigator 1.0 (Router API pode resolver, não testado) | Funcionam |
| Duas abas | Abre, mas a 2ª cai para cache em memória (`failed-precondition`). `synchronizeTabs` não testado | Sem erro, cache compartilhado |
| Cmd/Ctrl+clique | Abre na mesma aba | Nova aba, com a URL certa |

O Flutter tem saída para parte disso. As violações de axe saem em boa parte de como o protótipo montou a semântica, e o Router API deve resolver o avançar. O que não tem saída simples é ter semântica ligada para quem precisa sem pagar o custo: leitor de tela ligado leva a rolagem do CanvasKit a 38,5% de quadros acima de 50 ms. Ligada para todos, o custo vai para todos. Desligada, a pessoa precisa achar um botão oculto.

### Densidade

As três opções mostram 50 linhas em 1920×1080 com linha de 18 px e fonte de 13 px, e a virtualização cobre 10 mil linhas sem queda de quadros. O limite é físico, não de framework:

| Altura da janela | Linhas de 18 px | Linhas de 24 px |
|---|---|---|
| 768 px | 38 | 28 |
| 1080 px | 55 | 41 |
| 1200 px | 62 | 46 |

Altura da área de página, descontando o topo e o cabeçalho da tabela (73 px). As barras do navegador tiram cerca de 100 px a mais de uma tela física de mesma altura. Portanto, **a meta de "50+ linhas" só é real em tela grande**. Em notebook comum, ela conflita com a área de toque mínima de 24 px da WCAG 2.5.8. O axe não apontou violação, porque os alvos são links de texto, mas a linha inteira clicável com 18 px merece revisão de design. Sugestão: densidade configurável, com 24 px como padrão.

## Reuso

| Medida | Valor |
|---|---|
| Arquivos Dart em `lib/` | 362 (311 escritos à mão, 51 gerados) |
| App inteiro compila para web | **Sim** em JS. Em Wasm, o teste prévio só avisou sobre o pacote `image`; o build completo em Wasm foi feito só no protótipo |
| Reuso real no protótipo Flutter | 50 arquivos, 7,8 mil linhas, nenhum alterado, mais 24 gerados (17 mil linhas), contra 192 linhas novas |
| Reuso de UI no protótipo Flutter | **Zero**: as 38,9 mil linhas de `lib/screens/` são Cupertino para telefone, e a tabela foi escrita do zero |
| Importam plugin de celular | 35 arquivos; 12 dependem de plugin sem função útil na web |
| Importam `dart:io` | 27 arquivos; 6 usam `Platform.isIOS/isAndroid`, que lança erro na web em execução |
| Regra de negócio a reescrever em TypeScript nas opções B e C | Da ordem de 20 mil linhas: `models` 2,6 mil, `repositories` 2,4 mil, `mobx` 4 mil, `services` 9 mil, `utils` 1,4 mil. Parte não se aplica à web |
| Reuso de `firebase/web` na opção C | Tokens e componentes Vue (4,1 mil linhas de `.vue`), com pacote interno ou cópia controlada |

Compilar não prova que funciona. Só o caminho do protótipo foi executado: `OrderStore`, `FormatService` e repositórios rodaram sem alteração, e o único tropeço foi o `OrderStore` exigir um bucket de Storage na inicialização.

**O reuso é o único ponto em que o Flutter ganha com folga, e pesa de verdade.** Reescrever regra de negócio em TypeScript cria duas fontes de verdade: valor de OS, permissões, status. Os casos de `contract-cases/` já rodam contra Dart e TS e precisam entrar no CI. Sem isso, as duas versões vão divergir.

## Acesso a dados

### Custo de abrir a lista

| Caminho | Tempo | Rede | Leituras |
|---|---|---|---|
| Firestore direto, 50 OS | 590 ms na 1ª, 270 ms depois | 193 KB | 50 |
| 5 páginas | 2,3 s | 957 KB | 250 |
| Detalhe | Ver limitações | 3 KB | 1 |
| Lista do cache persistente | **58 ms** | 0 | 0 antes de revalidar |
| API local de teste, projeção de 50 OS | 174 ms | 2 KB | 50, mais a invocação |

Rede sem gzip, que o emulador não aplica. Os 50 documentos seguem o tamanho médio de 1,77 KB das OS sintéticas.

A API não reduz leituras. Ela reduz rede (2 KB contra 193 KB), mas adiciona invocação de função, cold start e superfície a manter. **Recomendação de leitura: Firestore direto para listas e detalhes, onde as regras garantem o isolamento entre empresas, e projeção da API para perfis sem acesso a valores. Gravação de dinheiro e status segue pela API, como manda `business-rules-map.md`, e o ADR consolida as duas frentes.**

### Custo mensal estimado

Empresa com 10 mil OS, 3 usuários, 5 sessões por dia cada, 22 dias, 200 leituras por sessão: cerca de 66 mil leituras por mês.

| Modelo | Leituras por mês | Custo aproximado |
|---|---|---|
| Paginação de 50 | 66 mil | US$ 0,02 |
| Sincronização inicial por aparelho (3 aparelhos) | 30 mil, uma vez | US$ 0,01, uma vez |
| Projeção em 4 pedaços | 1.320 | Menos de US$ 0,01, mais escritas extras |

Preço de lista de US$ 0,03 por 100 mil leituras, sem contar a cota grátis. O valor de São Paulo não foi confirmado e pode ser maior, mas a ordem de grandeza não muda: **leitura não é o gargalo de custo aqui.** O risco está em um bug de listener sem limite, não no uso normal. A documentação do Firestore diz que listener desconectado por mais de 30 minutos volta a ser cobrado como consulta nova, então o cache economiza menos do que parece em quem passa o dia com o app aberto e volta do almoço (regra confirmada na página da edição Enterprise, a confirmar na Standard).

## Busca global

Firestore não tem busca de texto. Motores testados no navegador, 10 mil OS, CPU 4x, 20 consultas (nome, placa, número, sem acento) repetidas 3 vezes:

| Motor | Montar | p50 | p95 | Máximo | Memória | Consultas com resultado |
|---|---|---|---|---|---|---|
| Varredura simples | 9 ms | 0,8 ms | 2 ms | 2,6 ms | 2 MB | 18 de 20 |
| **MiniSearch com prefixo e erro de digitação** | 121 ms | 0,8 ms | 6,6 ms | 8,6 ms | 6 MB | 19 de 20 |
| MiniSearch só prefixo | 127 ms | 0,4 ms | 1,5 ms | 1,7 ms | 11 MB | 18 de 20 |
| FlexSearch | 75 ms | 3,7 ms | 5,8 ms | 7,5 ms | 26 MB | 20 de 20 |
| Fuse | 12 ms | 59 ms | 151 ms | 159 ms | 9 MB | 20 de 20 |

Memória é estimativa pelo heap do navegador, com ruído. "Consultas com resultado" não mede relevância.

MiniSearch atende, e a varredura simples também, se não precisar de erro de digitação. Índice em IndexedDB: 1,15 MB, grava em 3 ms, lê em 2 ms, restaura em 184 ms.

O número da tela confirma o do motor: tecla até pintar em 32 ms na Vue. No Flutter, a mesma varredura deu 212 ms no CanvasKit e 124 ms no Wasm, porque o custo está em redesenhar a lista.

### A parte difícil: de onde vêm os dados do índice

| Estratégia | 1ª carga | Rede | Leituras | Depois | Respeita as regras de hoje? | Problema |
|---|---|---|---|---|---|---|
| **REST `runQuery` com máscara de campos** | 11,4 s | 10,3 MB sem gzip | 10 mil | Delta por data | **Sim**, sem mudar nada | SDK web não tem máscara, precisa de chamada própria. Técnico e consultor precisam filtrar por `createdBy.id` |
| SDK paginado de 1.000 em 1.000 | 52 s | 39 MB sem gzip | 10 mil | Delta em 1,3 s; ler do cache 1,1 s | Sim | 41 MB em IndexedDB |
| SDK sem limite | **Falhou** | | | | | Em 33 s entregou 0 documentos e caiu para o cache vazio |
| Projeção em 4 documentos | 2,1 s | 1,1 MB sem gzip | 4 | Só o pedaço alterado | **Não**: negada pelas regras reais | Exige Function de escrita e mudança em `firestore.rules` |
| Serviço externo | Sem carga no cliente | Uma chamada por busca | 0 | Sincroniza por trigger | Exige chave por empresa | Gasto recorrente: Algolia cerca de US$ 0,40 por mil registros e US$ 0,50 por mil buscas; Typesense Cloud a partir de cerca de US$ 7 a 22 por mês (fontes divergem) |

**Quatro riscos que a escolha precisa resolver:**

1. **A projeção por empresa pode vazar dados entre perfis.** Técnico e consultor só leem as OS que criaram. Um documento único por empresa expõe tudo a eles, inclusive valores. Precisa de projeção por escopo, ou ficar restrita a dono, admin, gerente e supervisor, com os outros perfis usando REST filtrado.
2. **Delta por `updatedAt` perde mudanças.** O app grava `updatedAt` com o relógio do aparelho, e o código do servidor mistura strings ISO e `Timestamp` em outras coleções. Não confirmei para OS se todas as escritas, inclusive triggers, atualizam o campo. Relógio errado ou escrita sem o campo somem do delta.
3. **Exclusão não aparece em delta.** O app apaga o documento de verdade (`doc(id).delete()`). Sem marca de exclusão, a OS apagada segue no índice local até recarregar tudo.
4. **Dados ficam no navegador.** Nome de cliente e valores em IndexedDB exigem limpeza no logout, e isso precisa de cuidado em computador compartilhado de recepção.

**Recomendação:** começar sem mudar regras, com REST filtrado por perfil, em segundo plano, para montar o índice MiniSearch. A projeção fica para depois, com aprovação, para reduzir as 10 mil leituras e os 10 MB da 1ª carga. Enquanto o índice monta, a busca precisa dizer que ainda não cobre tudo.

## Isolamento

16 de 16 testes passaram com as regras reais, conferidas como idênticas a `firebase/firestore.rules`:

- Empresa A não lê, lista nem escreve em dados da empresa B, nem por `collectionGroup`.
- Técnico e consultor têm a lista negada sem o filtro `createdBy.id`, e a leitura direta de OS alheia é negada.
- Sem login, tudo é negado.

À parte dos 16: a REST com máscara de campos também foi negada para técnico sem filtro.

Testes de regras, não auditoria. A cobertura completa está em `security-summary.md`.

## Método

- **Máquina:** Apple M5, 10 núcleos. Chromium 1248 no modo headless novo, com GPU Metal real.
- **Rede e CPU:** CDP, Fast 4G do DevTools (9 Mbps, 1,5 Mbps, 165 ms) e cabo (5 Mbps, 1 Mbps, 28 ms), CPU 4x.
- **Roteiro igual para todas, com Playwright:** carga vazia (1ª visita), recarga no mesmo contexto (cache), espera do índice, `/` + digitar "silva", limpar, 40 passos de rolagem, clique na linha 6, Esc, 10 setas, Enter.
- **Marcas:** `list-visible` e `detail-visible` depois do quadro pintado, porque o LCP não funciona no canvas. INP pela Event Timing API.
- **Servidor local de produção:** brotli 11, ETag, arquivo com hash imutável, sem hash 1 h (padrão do Hosting), HTML `no-cache`. Nuxt atrás desse servidor, como fica atrás do Hosting.
- **Seed:** empresa com 10 mil OS em 3 anos (70% concluídas, 12% orçamento, 8% aprovadas, 5% em andamento, 5% canceladas), 1.500 clientes, 1.800 veículos, 5 perfis, mais uma empresa com 200 OS.
- **Protótipos:** Vue idêntico em B e C. Flutter 3.38.5 com `Order`, `OrderStore`, `FormatService` e repositórios do app, sem modificar.
- **Login:** automático na carga em todas as opções, porque o FlutterFire valida a sessão salva antes de deixar conectar ao emulador. Exceção: a variante "sessão salva", só na C.
- **Testes:** axe nas tags WCAG 2.0 a 2.2 A e AA, árvore de acessibilidade via CDP, `window.find` no lugar do Ctrl+F e `page.pdf` no lugar da impressão.

## Limitações

**Favorecem o Flutter:** a GPU do M5 não sofre o throttle. GPU integrada de notebook comum deve piorar a rolagem e os quadros dele. Vale repetir em máquina real.

**Afetam todas:**

- Consultas em canal já aberto do Firestore escapam do throttle, por isso abrir detalhe parece rápido demais (19 ms no laboratório). Em produção, some a latência real.
- Tudo roda em HTTP/1.1 local, sem HTTP/2 e CDN do Hosting. Isso prejudica um pouco quem tem mais arquivos.
- CPU 4x sobre um M5 é uma aproximação de notebook intermediário, não de máquina fraca.
- O protótipo é vertical: lista, detalhe, sem charts nem formulários. Os bundles crescem com o produto, e o INP precisa ser remedido com telas reais.

**Não consegui medir:**

- **Economia de cache com token de retomada.** O emulador reenvia tudo (193 KB nas duas sessões), então a economia de leituras do cache persistente fica sem número.
- **Tamanho real com gzip em Firestore e REST.** Emulador não comprime. Só sei que o JSON de 10 mil OS vai de 18,1 MB para 1,55 MB em gzip.
- **Leitor de tela de verdade.** NVDA e VoiceOver não foram testados, só a árvore de acessibilidade.
- **Firefox e Safari.**
- **Cold start real do `/app`.** Usei 2 s, observado em `/admin/login`.
- **App Flutter completo rodando na web.** Compilou, mas só o caminho do protótipo foi executado.
- **Latência de busca em serviço externo.** Só custo, a partir de fontes públicas e divergentes.
- **Preço do Firestore em São Paulo.**

## Reprodução

Fontes, scripts e resultados brutos ficam fora do repositório, no diretório privado de discovery (`architecture-prototypes/`). Não há dado de cliente neles.

1. `emulator/start.sh`: sobe Auth e Firestore no projeto `demo-praticos`, nas portas 19099 e 18080. Requer JDK 21 ou mais novo.
2. `seed/seed.mjs` e `seed/corpus.mjs`, com `FIRESTORE_EMULATOR_HOST` e `FIREBASE_AUTH_EMULATOR_HOST`. Sem essas variáveis, o seed se recusa a rodar.
3. Builds: `option-a-flutter/build_all.sh`, `npm run build` em `option-b-nuxt` e `option-b2-nuxt`, `vite build` em `option-c-vite` e `option-lab`.
4. `bench/serve.mjs` para cada opção, nas portas 5101 a 5108.
5. `node bench/run.mjs <opções> 7 fast4g`, `bench/a11y.mjs`, `bench/extras.mjs`, `bench/isolation.mjs`, `bench/lab.mjs` e `bench/lab2.mjs`.
6. `python3 bench/report.py` calcula os p75.

O teste de projeção adiciona uma regra só na cópia local de `firestore.rules`, depois restaurada. O isolamento foi rodado depois da restauração.

## Fontes de preço

- [Firestore pricing](https://cloud.google.com/firestore/pricing)
- [Firestore Enterprise pricing, regra de 30 minutos](https://cloud.google.com/firestore/enterprise/pricing)
- [Algolia, excedentes do plano Grow](https://support.algolia.com/hc/en-us/articles/15745996583441)
- [Typesense, preço de entrada segundo FitGap](https://us.fitgap.com/products/006301/typesense)
- [Typesense, preço de entrada segundo Modern Data Tools](https://www.modern-datatools.com/tools/typesense/pricing)
