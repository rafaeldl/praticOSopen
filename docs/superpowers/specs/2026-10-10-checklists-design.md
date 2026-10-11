# Checklists mais práticos, com modelo pronto por ramo

**Data:** 2026-10-10 · **Status:** direção aprovada pelo Rafael, protótipo pronto, implementação não começou.
**Protótipos:** canvas https://claude.ai/artifact/NfHsv1Ge52LXGdpd9ZYihz, página **"Checklists"** (8 pranchas ligadas pelo Play; comece em "1 · OS nova").
**Alinha com:** `2026-10-11-telas-os-ia-design.md` (OS em branco, "Nesta OS", menu "Adicionar à OS", Foto + "Falar"), `docs/formularios_dinamicos.md`, `docs/APP_DESIGN_SYSTEM.md`.

## Problema

Quase ninguém usa: **no máximo 3 aberturas em 28 dias** no Analytics. O que o código mostra:

1. **Modelos existem, mas ninguém os vê.** `firebase/scripts/seed_forms.js:18` (`GLOBAL_FORMS`) tem de 3 a 7 modelos para 12 ramos: automotive `:22`, hvac `:371`, smartphones `:711`, computers `:1075`, appliances `:1478`, electrical `:1869`, plumbing `:2026`, security `:2153`, solar `:2283`, printers `:2406`, public_works `:2549`, other `:2806`. Eles são copiados para a empresa no primeiro acesso (`BootstrapService.syncCompanyFormsFromSegment`, `lib/services/bootstrap_service.dart:217`, chamado em `lib/screens/onboarding/confirm_bootstrap_screen.dart:169,234`), mas **nenhum entra sozinho na OS**: o usuário precisa achar a seção e adicionar.
2. **Quatro ramos sem modelo:** `building_maintenance`, `bicycles`, `asset_maintenance` e `global` (`firebase/scripts/seed_segments.js`).
3. **Muitos passos até a primeira pergunta.** OS → seção "Formulários" (`lib/screens/order_form.dart:788`) → "Adicionar" → (escolher equipamento, se houver vários) → `FormSelectionScreen` → `FormFillScreen` em tela cheia. São 3 a 4 telas.
4. **Preencher dá trabalho.**
   - Uma lista longa com todas as perguntas.
   - Opção de lista abre um action sheet (2 toques).
   - Multiescolha abre outra tela.
   - Foto é um ícone pequeno no cabeçalho do item, que abre um action sheet "Câmera/Galeria" (`lib/screens/forms/form_fill_screen.dart:406`, `:616-665`).
5. **Sem noção de quanto falta.** O progresso (respostas / itens) só aparece na lista da OS e ignora os obrigatórios. Os obrigatórios só são cobrados ao concluir, num alerta (`form_fill_screen.dart:253-288`).
6. **Sem medição:** nenhum evento de checklist (`form_fill_screen.dart`, `forms_service.dart` e `form_selection_screen.dart` não chamam `AnalyticsService`). As "3 aberturas" vêm de `screen_view`.
7. **Risco escondido:** rodar a sincronização de novo sobrescreve os modelos que a empresa editou (`bootstrap_service.dart:262`, `set(..., merge: true)` com o mesmo id).

## Proposta

### 1. O modelo do ramo já vem na OS

- Cada ramo marca **um** modelo como "de entrada": `autoAttach: true` no seed. Exemplos: "Entrada do veículo" (mecânica), "Entrada do aparelho" (celulares, informática, eletrodomésticos), "Registro da instalação" (climatização). Em ramos sem um modelo de entrada claro, nenhum é marcado.
- **OS nova** (com cliente salvo): o modelo aparece em **"Nesta OS"** como uma linha "Entrada do veículo · Faltam 5 perguntas", com ponto âmbar (`warning`) e texto. Não cria instância no Firestore até a primeira resposta: é só uma sugestão.
- Se for o próximo passo natural, o bloco azul diz **"Próximo passo: conferir a entrada do carro"** com o botão "Conferir entrada · 5 perguntas" (`chk-os-sugerido`). Depois da entrada conferida, o próximo passo volta ao fluxo normal da OS (`chk-pronto`): "mandar o orçamento para a Ana".
- Quem não quer: "…" → "Não usar nesta OS" na linha.
- **Mais › Checklists** (`chk-modelos-ramo`) mostra o resultado em vez da configuração, em três seções: **"Já vem em toda OS"**, **"Para usar quando precisar"** e **"Não usados na empresa"** (em cinza; só aparece se houver algum). Não tem interruptor na lista nem texto explicando.
- Para trocar um checklist de seção, a pessoa abre o checklist (`chk-modelo-editar`). No topo vem **"Quando usar"**, com três opções e ✓ à direita: "Em toda OS nova", "Quando eu precisar" e "Não usar na empresa". As perguntas vêm embaixo.
- "Não usar na empresa" **esconde, não apaga**: o checklist some da OS e do "Adicionar", e volta escolhendo outra opção. Ele vira o campo `usage: 'auto' | 'onDemand' | 'off'` no modelo da empresa (`companies/{id}/forms/{formId}`), e a sincronização do ramo não pode religar o que a empresa desligou (ver etapa 6). Checklist criado pela empresa ganha também "Apagar checklist", em vermelho, no fim da tela.
- Os outros modelos do ramo ficam em **"Adicionar à OS ›"** (menu "…" da OS, como na spec da OS), já filtrados pelo ramo e pelos serviços da OS.

### 2. Uma pergunta por vez

Uma sheet grande com "Fechar" à esquerda, o nome do checklist no centro, uma barra de progresso em segmentos e a pergunta em letra grande. O texto acima diz **"Faltam 4"**, e não "2 de 5" (regra 3 do design system).

| Tipo (`form_definition.dart:57`) | Como responde |
|---|---|
| `boolean` | Dois botões grandes (64 de altura): "Sim, tem" / "Não tem". **Tocar já salva e passa** (`chk-pergunta`) |
| `select` | Opções em botões grandes, com ✓ à direita; tocar salva e passa (`chk-pergunta-opcoes`) |
| `checklist` (várias) | Os mesmos botões, com ✓ em cada um, e "Pronto" no fim. Nada de outra tela |
| `photo_only` | **A câmera abre direto** (sem "Câmera ou Galeria?"); a galeria fica como link "Escolher da galeria". Depois da foto, a IA lê o que der (km, nível de combustível, modelo, número de série) e mostra com marca-texto: "Está certo, próxima" (`chk-pergunta-foto`) |
| `text` / `number` | Campo grande com o teclado já aberto; "Próxima" no teclado |
| qualquer item com `allowPhotos` | Botão de foto em vidro embaixo, sempre no mesmo lugar (igual à OS) |

- "Pular por agora" em toda pergunta, e "Voltar à anterior".
- Obrigatório não trava o caminho: o pulado fica na contagem ("Faltam 1"). Só "Concluir OS" avisa, como hoje (`order_form.dart:2305`).
- Ao responder a última: a sheet fecha e a linha vira "Completo · 2 fotos" (ponto verde). Só háptico, sem animação (ver `2026-10-10-animacoes-conclusao-design.md`).

### 3. Falar as respostas (IA)

Embaixo da pergunta fica **"Falar as respostas"** (a mesma barra da OS: foto + Falar).

- O usuário fala tudo de uma vez: "risco na porta de trás, um quarto de tanque, estepe ok, sem luz acesa".
- A IA propõe as respostas com marca-texto, e o que não entendeu aparece como "Falta" (`chk-ia-preencheu`).
- Ele confirma com "Está certo, pode marcar" (regra 5: a IA sempre pergunta antes).

Usa o mesmo assistente da OS (`2026-10-09-os-ai-assistant-design.md`): a operação nova é `fillFormResponses(formInstance, transcript, photos)`. Ela conta na cota de IA como as outras.

### 4. O cliente vê

O checklist concluído entra no PDF (já entra, `lib/services/pdf/pdf_service.dart:43`) e **no link do cliente**, porque hoje a página tem o componente, mas a API não manda `forms` (ver `2026-10-10-app-cliente-design.md`). Isso dá valor a quem preenche: a vistoria de entrada protege a oficina ("o risco já estava lá") e aparece para o cliente.

## Modelos por ramo

| Ramo | Modelo de entrada (`autoAttach`) | Situação |
|---|---|---|
| automotive | Entrada do Veículo (5) | Existe |
| smartphones | Entrada (8) → **cortar para 5** | Existe; longo demais para o balcão |
| computers | Entrada (7) → cortar para 5 | Existe |
| appliances | Entrada (5) | Existe |
| printers | Entrada (5) | Existe |
| hvac | Registro da Instalação (6) | Existe; só em OS de instalação (filtrado por serviço) |
| other | Entrada do Item (6) | Existe |
| electrical, plumbing, solar, security, public_works | — | Sem modelo de entrada claro: nada abre sozinho; os modelos ficam em "Adicionar" |
| bicycles | **Novo:** Entrada da bike (freios, câmbio, pneus, foto) | Falta |
| building_maintenance | **Novo:** Vistoria do local (fotos antes, acesso, risco) | Falta |
| asset_maintenance | **Novo:** Entrada do equipamento (estado, nº de série, foto) | Falta |

**Regra para modelos de entrada: no máximo 5 perguntas e pelo menos uma de foto.** Os modelos longos continuam disponíveis para quem quiser.

## Medição

Eventos novos em `AnalyticsService`:
- `checklist_suggested` (linha mostrada na OS)
- `checklist_started`
- `checklist_answered` (com `type` e `via`: `tap`, `photo` ou `voice`)
- `checklist_completed`
- `checklist_dismissed`
- `checklist_autoattach_off`

Parâmetros: `segment` e `template_id`. Nada de conteúdo das respostas.

O que olhar: das OS onde o checklist foi sugerido, quantas o concluíram. Por ser o primeiro número medido, ele vira a linha de base, sem meta inventada antes.

## Ordem de implementação

| # | Etapa | Onde | Risco |
|---|---|---|---|
| 1 | Eventos de Analytics no fluxo atual (medir antes de mudar) | `forms_service.dart`, `form_fill_screen.dart` | `risk:low` |
| 2 | Tela "uma pergunta por vez" (`FormQuestionSheet`), com testes de widget por tipo | `lib/screens/forms/` | `risk:low` |
| 3 | Câmera direta no `photo_only` | `form_fill_screen.dart` / nova sheet | `risk:low` |
| 4 | `autoAttach` no seed + modelos de entrada encurtados + 3 ramos novos | `firebase/scripts/seed_forms.js` | `risk:high` (seed de produção, modelo compartilhado) |
| 5 | Sugestão na OS ("Nesta OS" + próximo passo) e interruptor em Mais › Checklists | OS redesenhada (depois da sessão da OS) | `risk:low` |
| 6 | Sincronização sem sobrescrever modelos editados (só cria os que faltam) | `bootstrap_service.dart:262` | `risk:high` (migração de dados) |
| 7 | `forms` resumido no link do cliente | `functions/src/routes/public/orders.routes.ts` | `risk:high` |
| 8 | "Falar as respostas" (IA) | assistente da OS, Functions | `risk:high` (Function de produção com escrita) |

Atualizar `docs/formularios_dinamicos.md` (lista de modelos e UX desatualizadas) junto com a etapa 2.
