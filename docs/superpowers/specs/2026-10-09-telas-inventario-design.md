# Telas do app: inventário, auditoria e prioridade

Status: proposta · 2026-10-09 · base: `docs/APP_DESIGN_SYSTEM.md` (PR #326) · componentes: `2026-10-09-telas-componentes-design.md`

Este doc é o ponto de entrada da discovery: o inventário de todas as telas, o que se repete entre elas e a ordem de trabalho. Os achados e a tela proposta de cada grupo ficam na spec dele.

Protótipos: canvas https://claude.ai/artifact/NfHsv1Ge52LXGdpd9ZYihz, página **"Telas do app"** (20 pranchas, duas delas no modo escuro). A página "OS com IA" continua com as direções da OS (linha E e "Padrão do app").

**Fora de escopo:** a tela da OS (`order_form.dart`) e os fluxos de criar e editar OS, assistente, nova OS por foto e fotos do WhatsApp, que estão em outra sessão. Telas que só existem dentro da OS (pagamentos da OS, preencher checklist, itens da OS) entram só com os achados, marcadas como "alinhar com a sessão da OS".

## Como foi feito

- Li todas as telas de `lib/screens/**` (67 arquivos), as rotas (`lib/routes.dart`) e as abas (`navigation_controller.dart:33-39`).
- Auditei contra as regras R1–R7 e as 6 zonas do `APP_DESIGN_SYSTEM.md`, mais o `UX_GUIDELINES.md`. O método é o do improve-ui (ui-skills.com): um achado só entra com contrato (a regra), runtime (o arquivo:linha que prova que aquilo aparece na tela) e correção. Para acessibilidade e cor segui o better-accessibility e o better-colors.
- A frequência de uso é estimada pela navegação (se é aba, fluxo da OS ou configuração). Não usei telemetria.

## Inventário

Uso: **D** = diário · **S** = semanal · **R** = raro · **1×** = uma vez por usuário. "Elementos" = ações tocáveis na primeira tela / botões preenchidos / cores de status.

### Início e navegação → `2026-10-09-telas-inicio-design.md`

| Tela | Arquivo (linhas) | Objetivo | Uso | Elementos |
|---|---|---|---|---|
| Abas | `menu_navigation/navigation_controller.dart` (175) | Trocar entre as 5 áreas | D | 5 abas |
| Início: lista de OS | `menu_navigation/home.dart` (1131) | Ver o que está em andamento, abrir ou criar OS | D, várias vezes | ~10 ações + 7–10 chips / 0 botões azuis / ~9 cores |
| Agenda | `agenda/agenda_screen.dart` (501) | Ver o que está marcado no dia | D para quem agenda | ~31 dias + linhas / 1 preenchido / 6 cores |
| Avisos | `notifications/notification_list_screen.dart` (164) + `notification_list_tile.dart` | Ver o que o cliente respondeu | S | N linhas / 0 / 6 cores |
| Avaliações | `ratings/ratings_screen.dart` (453) | Ver o que os clientes acharam | R | 5 cores na nota |
| Carregando | `loading_screen.dart` (31) | Abertura do app | D | — |

### Clientes → `2026-10-09-telas-clientes-design.md`

| Tela | Arquivo (linhas) | Objetivo | Uso | Elementos |
|---|---|---|---|---|
| Aba Clientes | `menu_navigation/home_customer_list.dart` (315) | Achar um cliente | S/D | "+", busca, ~8–10 linhas / 0 / 0 |
| Escolher cliente | `customers/customer_list_screen.dart` (331) | Escolher o cliente da OS | D | ~8–10 / 0 / 0 |
| Novo cliente | `customers/customer_form_screen.dart` (242) | Salvar nome e telefone | D | 5 campos fixos + os do segmento / 0 |
| Tela do cliente | **não existe** | Ver as OS de um cliente e ligar para ele | — | Hoje o toque leva para a aba Início com um filtro |

### Veículos / aparelhos → `2026-10-09-telas-veiculos-design.md`

| Tela | Arquivo (linhas) | Objetivo | Uso | Elementos |
|---|---|---|---|---|
| Lista / escolher | `device_list_screen.dart` (393) | Escolher o veículo da OS | D (na OS), R (em Mais) | ~8–10 / 0 / 4 cores |
| Novo veículo | `device_form_screen.dart` (520) | Cadastrar o veículo que entrou | D | 4–5 campos, 3 abrem outra tela / 1 |
| Marca / modelo / categoria | `accumulated_value_list_screen.dart` (564) | Escolher um valor já usado | D (3 vezes por veículo) | N linhas / 0 |
| Detalhe do aparelho | `devices/device_detail_screen.dart` (584) | Histórico e contratos | R | 11 cores |
| Vários aparelhos na OS | `widgets/device_picker_sheet.dart` (207) | A qual aparelho o item se aplica | R | 1 preenchido |

### Catálogo → `2026-10-09-telas-catalogo-design.md`

| Tela | Arquivo (linhas) | Objetivo | Uso | Elementos |
|---|---|---|---|---|
| Serviços (escolher / cadastro) | `service_list_screen.dart` (328) | Pôr um serviço na OS / manter a lista | D na OS, R em Mais | "+", busca, N linhas, 2 gestos ocultos |
| Produtos | `product_list_screen.dart` (328) | Igual, para produtos | D na OS, R em Mais | Cópia da de serviços |
| Novo serviço / produto | `service_form_screen.dart`, `product_form_screen.dart` (301 cada) | Nome, preço e foto | S no início, depois R | 2 campos + foto / 1 |
| Itens da OS | `order_service_screen.dart`, `order_product_screen.dart` | Valor e quantidade do item na OS | D | Fora de escopo (OS) |

### Financeiro → `2026-10-09-telas-financeiro-design.md`

| Tela | Arquivo (linhas) | Objetivo | Uso | Elementos |
|---|---|---|---|---|
| Aba Financeiro | `dashboard/financial_dashboard_simple.dart` (2859) | Quanto entrou, quanto falta e de quem | S (dono) | ~11 ações, ~9 números antes da 1ª lista, 4 filtros, 2 gráficos / 0 / 5 cores |
| Pagamentos da OS | `payment_management_screen.dart` (1313) | Anotar o que o cliente pagou | D | 4 ações azuis (alinhar com a OS) |
| Cobrança na OS / nova cobrança | `payments/*` (Asaas) | Mandar Pix ou boleto | S (piloto) | 1 preenchido |
| Integrações / conexão Asaas | `integrations/*` | Ligar o Asaas, links do ChatGPT/Claude | 1× | — |

### Mais, empresa, equipe e o resto → `2026-10-09-telas-mais-equipe-design.md`

| Tela | Arquivo (linhas) | Objetivo | Uso | Elementos |
|---|---|---|---|---|
| Aba Mais | `menu_navigation/settings.dart` (897) | Achar onde mudar empresa, equipe, cadastros e plano | S | ~23 linhas em 6–7 seções / 0 / 12 cores de ícone |
| Dados da empresa | `menu_navigation/company_form_screen.dart` (834) | Nome, logo, contato, ramo, funções | R | 8 campos + 4 interruptores |
| Equipe | `menu_navigation/collaborator_list_screen.dart` (663) | Ver quem está, convidar, mudar permissão | R | 3 cores de status |
| Convidar pessoa | `menu_navigation/collaborator_form_screen.dart` (413) + `widgets/invite_share_sheet.dart` (366) | Criar e mandar o convite | R | 2 botões preenchidos no compartilhar |
| Meu perfil | `user_profile_edit_screen.dart` (538) | Nome, foto, apagar conta | R | 4 |
| Checklists (modelos) | `forms/form_template_list_screen.dart` (655), `form_template_form_screen.dart` (894) | Montar checklists | R | N botões "Importar" preenchidos |
| Checklist na OS | `forms/form_selection_screen.dart` (327), `form_fill_screen.dart` (1177) | Escolher e preencher | S | Alinhar com a OS |
| Contratos | `contracts/contract_list_screen.dart` (231) | Contratos de manutenção | R | 2 cores |
| Link da OS | `widgets/share_link_sheet.dart` (881) | Mandar a OS para o cliente | S | 1–2 preenchidos |
| Assinatura | Paywall nativo do RevenueCat (`services/paywall_launcher.dart`) | Ver e trocar de plano | R | Só inventário |

### Primeiro acesso → `2026-10-09-telas-primeiro-acesso-design.md`

| Tela | Arquivo (linhas) | Uso |
|---|---|---|
| Login, e-mail | `login.dart` (335), `email_login_screen.dart` (314) | 1× |
| Roteamento e telas de erro | `auth_wrapper.dart` (543) | 1× / R |
| Boas-vindas, dados, contato, ramo, especialidades, "Quase lá", questionário | `onboarding/*` (welcome 304, company_info 243, company_contact 213, select_segment 257, select_subspecialties 243, confirm_bootstrap 518, segmentation_onboarding 250) | 1× |
| Convites | `onboarding/pending_invites_screen.dart` (404), `accept_invite_screen.dart` (379) | 1× |
| WhatsApp | `onboarding/whatsapp_onboarding_screen.dart` (172) | Desligado (flag do bot) |

Hoje um dono novo passa por **10 telas e ~15 toques** até ver a primeira OS.

## O que se repete em todas as áreas

1. **Nenhuma tela usa o padrão novo.** Não há `AppColors` nem `AppTypography` em `lib/screens/`. O app inteiro herda `primaryColor: CupertinoColors.activeBlue` (`lib/main.dart:149`), que dá 4,02:1 com texto branco.
2. **Status só pela cor (R7).** Na Início, a linha da OS não escreve o status: ele aparece só como a cor do selo do número (`home.dart:944-962`), com roxo e laranja fora do padrão. O mesmo mapa de cores está copiado em `agenda_screen.dart:485-500` e no detalhe do aparelho. O status do aparelho é um ponto de 8px sem texto (`device_list_screen.dart:301-309`).
3. **Nenhuma tela responde "o que eu faço agora?" (R1).** Nenhuma das telas de uso diário tem próximo passo nem um botão azul único. "Nova OS" é um "+" com o mesmo peso do sino.
4. **"Salvar" escondido.** Em todos os formulários do dia (cliente, veículo, serviço, produto), "Salvar" é um texto no canto da barra.
5. **Recursos raros na frente (R4).** O novo cliente sempre mostra CPF/CNPJ, e-mail e endereço. A categoria vem antes da placa. O desconto é o primeiro controle dos pagamentos. A aba Mais tem 4 lembretes no meio.
6. **Português quebrado ou técnico (R3).** Exemplos: "Não cliente cadastrado" (`home_customer_list.dart:125`), "Não equipamento cadastrado" (`device_list_screen.dart:141`), "Faturamento", "Composição", "Saldo", "Label", "Nova OS" como título do editor de checklist, o item "Aceitar" na aba Mais e erros crus (`e.toString()`) no onboarding.
7. **Texto pequeno e cinza claro.** Rótulos de 10 a 14px, cabeçalhos em caixa alta de 13px e datas importantes em `systemGrey` aparecem em todas as áreas.
8. **Ações que só funcionam por gesto.** Editar um cliente exige toque longo ou deslizar. Remover um pagamento exige arrastar. No modo escolher, um deslize pode apagar o item do catálogo no meio da OS.

## Código morto (candidato a remoção, em PR separado)

| Arquivo | Prova |
|---|---|
| `lib/screens/modal_menu.dart`, `modal_status.dart`, `modal_bottom_sheet.dart` | Nenhuma chamada fora dos próprios arquivos |
| `lib/screens/info_form_screen.dart` | Só registrado em `lib/routes.dart`; nenhum `pushNamed('/info_form')` |
| `lib/screens/pdf_preview_screen.dart`, `order_item_row.dart`, `customers/customer_os_list.dart` | Nenhuma referência fora do próprio arquivo |
| `lib/widgets/feature_gate_limit_modal.dart`, `feature_gate_warning.dart`, `upgrade_prompt_modal.dart`, `photo_limit_dialog.dart`, partes de `permission_widgets.dart` (~1.000 linhas) | Só se referenciam entre si (detalhes na spec de Mais) |

Antes de apagar: repetir o `grep` na master do dia e rodar `fvm flutter analyze` e `fvm flutter test`.

## Prioridade (confirmada com o Rafael em 2026-10-09)

Ordem pelo uso no dia a dia, sem contar a OS:

| # | Grupo | Por quê | Pranchas |
|---|---|---|---|
| 1 | **Início / lista de OS** | O app abre aqui, várias vezes por dia. É onde o status só por cor mais atrapalha | Início · lista de OS, · modo escuro, · primeira vez |
| 2 | **Clientes** | Toda OS começa escolhendo ou cadastrando um cliente. Falta a tela do cliente | Clientes · aba, · tela do cliente (nova), · escolher na OS, · novo cliente |
| 3 | **Veículos / aparelhos** | Todo veículo novo passa por 3 telas antes da placa | Veículos · escolher na OS, · novo (uma tela só) |
| 4 | **Catálogo** | É o seletor de toda OS, mas hoje é o mesmo código do cadastro raro | Catálogo · escolher serviço, · criar pela busca, · seus serviços, · novo serviço |
| 5 | **Financeiro** | Aba principal do dono, mas não responde "quem me deve?" | Financeiro · aba, · modo escuro |
| 6 | Mais e equipe | Passar de ~23 linhas para ~15, sem cores | Mais · aba, · equipe |
| 7 | Primeiro acesso | Acontece uma vez, mas é a primeira impressão: de 10 telas para 3–4 | Primeiro acesso · login, · ramo, · seu negócio |

## Ordem de implementação (geral)

1. **Base** (risk:low): `OrderStatusStyle` + `StatusDot` e troca do mapa de cores nas 3 cópias. Isso corrige o R7 na Início, na agenda e no aparelho sem mudar o layout. No mesmo passo, as frases quebradas ("Não cliente cadastrado") passam a usar `EntityPhrases`.
2. **Início** (risk:low): 6 zonas, `NextStepBlock`, "Em aberto | Todas" e "Nova OS" fixo.
3. **Formulários do dia** (risk:low): `AppBottomBar` + `AppFormField` + `MoreFieldsLink` no novo cliente, no novo veículo e no novo serviço/produto.
4. **Seletores da OS** (risk:low): separar o modo escolher do modo cadastro em clientes, veículos e catálogo (`AddRow`, sem deslize).
5. **Tela do cliente** (risk:low, tela nova).
6. **Veículo numa tela só** (risk:low): `SuggestField`.
7. **Financeiro** (risk:low): a lista "Falta receber" sobe para o topo e os gráficos vão para o "…".
8. **Mais e equipe** (risk:low).
9. **Primeiro acesso**: risk:high na parte de auth e criação de empresa, risk:low nos textos.
10. **Remoção do código morto** (risk:low, PR próprio).

A troca do `primaryColor` global entra com a primeira tela redesenhada, seja a OS (outra sessão) ou a Início. Cada passo vira um PR pequeno, com teste de widget novo e as strings nos 3 `.arb`.
