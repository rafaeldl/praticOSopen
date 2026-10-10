# Telas do app: aba Mais e equipe

Status: proposta · 2026-10-09 · base: `docs/APP_DESIGN_SYSTEM.md` · componentes: `2026-10-09-telas-componentes-design.md`

Protótipos: canvas https://claude.ai/artifact/NfHsv1Ge52LXGdpd9ZYihz, página "Telas do app".

Grupo: aba Mais, dados da empresa, equipe e convites, meu perfil, checklists (modelos), contratos, assinatura/paywall e compartilhamento. Só a aba Mais e a Equipe têm prancha; as outras telas recebem correções pontuais.

Achados que valem para quase todas as telas do grupo (não repetidos nas tabelas): nenhuma usa `AppColors` (ação em `activeBlue`, 4,02:1 com branco); cabeçalhos em caixa alta por `.toUpperCase()` ou por string já em caixa alta no `.arb`; ajudas em 11–14; "Salvar"/"Adicionar" como texto no canto do topo.

## Telas do grupo

| Tela | Arquivo | Uso | O que muda |
|---|---|---|---|
| Aba Mais | `lib/screens/menu_navigation/settings.dart` (897 l.) | Semanal (entrada para Serviços/Produtos/Aparelhos) | Prancha nova: ~23 → ~15 linhas, sem ícones coloridos, raros em sub-telas |
| Dados da empresa | `menu_navigation/company_form_screen.dart` (834 l.) | Rara | Textos, tamanhos, `AppBottomBar` "Salvar dados" |
| Equipe | `menu_navigation/collaborator_list_screen.dart` (663 l.) | Mensal | Prancha nova: convite esperando como próximo passo, papel em uma frase |
| Novo colaborador | `menu_navigation/collaborator_form_screen.dart` (413 l.) | Rara | Texto falso do e-mail, rótulos, `AppBottomBar` "Criar convite" |
| Compartilhar convite | `screens/widgets/invite_share_sheet.dart` (366 l.) | Rara | Um botão azul só, sem verde WhatsApp |
| Meu perfil | `lib/screens/user_profile_edit_screen.dart` (538 l.) | Rara | i18n (tudo fixo em pt) |
| Checklists (modelos) | `forms/form_template_list_screen.dart`, `forms/form_template_form_screen.dart` | Rara | Textos errados, um nome só ("Checklists") |
| Contratos | `contracts/contract_list_screen.dart` (231 l.) | Rara | Frase quebrada, ponto sem sentido |
| Assinatura / limites | `services/paywall_launcher.dart`, `widgets/photo_limit_dialog.dart` | Rara | Textos; paywall é RevenueCat nativo (só inventário) |
| Compartilhar OS | `screens/widgets/share_link_sheet.dart` (881 l.) | Semanal | Mesmo problema do verde; alinhar com a sessão da OS |

## Problema atual (achados)

| Regra | Evidência | O que o usuário vê | Correção |
|---|---|---|---|
| **Aba Mais** | | | |
| R3 / Z2 | aba `more`="Mais" (`navigation_controller.dart:82`), título `settings`="Configurações" (`settings.dart:72`) | Toca "Mais" e chega em "Configurações" | Título "Mais" |
| R3 | `settings.dart:484` linha com `acceptInvite`="Aceitar" | Linha chamada só "Aceitar" | "Entrar com código de convite" |
| R4 | Raros no mesmo nível de Serviços: Configurações Iniciais (`:299-322`), 3 switches de lembrete (`:346-414`), Gerenciar assinatura e Restaurar compras (`:829-841`) | ~23 linhas; o que se usa toda semana fica no meio | Sub-telas "Avisos" e "Plano"; configuração inicial dentro de Dados da empresa |
| Cor | 12 cores de ladrilho, `systemPurple` (`:151`, `:309`, `:374`, `:815`), hex `0xFFFFD700` (`:246`); nome da empresa em `activeBlue` sem ser link (`:115`) | Arco-íris de ícones; texto azul que parece link | Sem ícone; nome em `textSecondary` |
| Escuro / T3 | `systemGrey5`/`systemGrey` sem `resolveFrom` (`:100-101`); papel 13 (`:125`), versão 13 (`:511`) | Avatar e versão com cor errada no escuro; texto miúdo | `AppColors.*.resolveFrom`; 15 |
| **Equipe** | | | |
| R7 / contraste | selo "Pendente" 11 com fundo `systemOrange` (`collaborator_list_screen.dart:251-264`); validade em `systemOrange` 12 (`:180-194`), ≈2,2:1 | Selo colorido e "Expira em 2 dias" quase ilegível | `StatusDot` `warning` + "Convite enviado · vence em 2 dias" em 15 |
| R1 / R6 | vazio "Nenhum colaborador encontrado" (`:116-118`); convidar só pelo "+" sem rótulo (`:50-62`) | Não sabe como chamar alguém | `NextStepBlock` / `AppBottomBar` "Convidar outra pessoa" |
| R3 | emoji "👷 Técnico" (`:268`, `:447`; `permission.dart:188-200`); erro cru do store (`:80-83`, `:384`) | Emoji e mensagem técnica | Papel em texto + frase; "Não deu para carregar a equipe. Tente de novo." |
| R3 (texto falso) | `collaborator_form_screen.dart:338` "O usuário receberá um convite por email.", mas o fluxo abre `InviteShareSheet` (`:119-126`) e não há envio de e-mail em `firebase/functions/src` | Promete e-mail que nunca chega | "Depois você manda o código pelo WhatsApp." |
| R2 / contraste | `invite_share_sheet.dart:161` e `share_link_sheet.dart:545` botão `0xFF25D366` com texto branco ≈1,98:1; mais um `activeBlue` preenchido (`invite_share_sheet.dart:191`) | Dois botões principais; texto do verde difícil de ler | Um `PrimaryButton` "Mandar pelo WhatsApp"; "Copiar código" e "Outros apps" em `SecondaryButton` |
| **Checklists** | | | |
| R3 (texto errado) | título `editOrder`/`newOrder`="Editar OS"/"Nova OS" (`form_template_form_screen.dart:150`); placeholder `companyName`="Nome da Empresa" (`:196`); campo "Label" com dica "Tipo" (`:729-731`) | Acha que está criando uma OS; escreve o nome da empresa | "Novo checklist"/"Editar checklist"; "Ex.: Revisão de entrada"; "Pergunta" / "Ex.: Nível do óleo" |
| R3 (3 nomes) | "Procedimentos" (menu e título, `form_template_list_screen.dart:45`), "formulários" no limite (`photo_limit_dialog.dart:26-29`), "Procedimento concluído" no preenchimento | Três nomes para a mesma coisa | Um nome: "Checklists" (menu, título, limite, OS); "Procedimentos Globais" (`:215`) vira "Modelos prontos" |
| R2 | botão `activeBlue` preenchido "Importar" em cada modelo global (`:486-505`) | Pilha de botões azuis | Texto `accentText` "Usar" |
| **Contratos** | | | |
| R3 / R7 | `contract_list_screen.dart:141-143` monta "Intervalo 2 Mensal"; ponto verde sem texto (`:161-170`) numa lista que já filtra ativos (`:80`); raio laranja sem texto (`:205-210`) | Frase quebrada; sinais sem sentido | "A cada 2 meses"; tirar ponto; linha 2 "Cria a OS sozinho" |

## Tela proposta

### Mais · aba

Prancha: **"Mais · aba"**.

1. **Topo:** nenhum (raiz de aba).
2. **Título** (`ScreenTitle`): "Mais".
3. **Próximo passo:** não tem na prancha. Só aparece com pendência real, um de cada vez: pagamento do plano com problema ("O pagamento do plano não passou." → `PrimaryButton` "Resolver pagamento") ou convite vencendo (mesmo bloco da Equipe).
4. **Conteúdo** (`AppListRow` sem ícone colorido, com seta):
   - Linha de perfil: "Rafael" / "Oficina Exemplo · Dono" → Meu perfil.
   - `SectionLabel` **"Sua empresa"**: "Dados da empresa" · "Equipe" / "2 pessoas · 1 convite esperando" · "Plano" com o nome do plano à direita ("Starter") e linha 2 "Renova em 10/11/2026" (no Grátis: "Ver o que os planos liberam") (só com `paidPlansEnabled`, `settings.dart:420`).
   - `SectionLabel` **"Cadastros"**: "Serviços" · "Produtos" · "Veículos" (rótulo do segmento) · "Checklists" · e, conforme permissão, "Contratos", "Avaliações", "Integrações".
   - Fora da prancha, depois: **"Este aparelho"**: "Idioma" (Português) · "Aparência" (Automático) · "Avisos" (sub-tela com os 4 lembretes). **"Conta"**: "Trocar de empresa" (só com mais de uma) · "Entrar com código de convite" · "Sair" (`danger`, sem ícone). Rodapé "PraticOS 1.56.1" em 15.
5. **Resumo:** não tem.
6. **Barra de baixo:** não tem (aba).

- Sai da 1ª tela: os 12 ícones coloridos; "Configurações Iniciais" (vira `TextLink` "Refazer configuração inicial" no fim de Dados da empresa); os 4 lembretes (sub-tela Avisos); "Ver planos", "Gerenciar assinatura", "Restaurar compras" (sub-tela Plano, que abre o paywall). Não-admin vê "Plano" com a frase "Peça ao dono da empresa para mudar de plano." (hoje `:843-846`).
- Itens sem permissão não aparecem (regras atuais de `settings.dart:180-258` mantidas).

### Mais · equipe

Prancha: **"Mais · equipe"**.

1. **Topo:** "‹ Mais".
2. **Título:** "Equipe" / "2 pessoas e 1 convite".
3. **Próximo passo** (`NextStepBlock` `warning`): rótulo "Convite esperando", frase "Lucas ainda não entrou. O convite vence em 2 dias." + `PrimaryButton` "Reenviar convite". Aparece para o convite pendente mais perto de vencer. Sem convite pendente e só o dono na equipe: "Chame quem trabalha com você para ver as OS." + `PrimaryButton` "Convidar pessoa".
4. **Conteúdo:**
   - `SectionLabel` "Esperando entrar" (só se houver): nome (19) / `StatusDot` `warning` "Convite enviado · vence em 2 dias". Vencido: `StatusDot` `danger` "Convite vencido". Toque → `MoreMenu`: "Reenviar convite" · `DestructiveAction` "Cancelar convite".
   - `SectionLabel` "Na equipe": inicial em círculo `secondaryFill`, nome / papel explicado em uma frase (os 5 de `RolesType`, `lib/models/user_role.dart:20-45`; "Dono" na prancha é o administrador dono da empresa, não um papel à parte): "Administrador — vê e muda tudo", "Gerente — vê faturamento e custos", "Supervisor — organiza a equipe, não vê valores", "Consultor — faz orçamentos e vê só os dele", "Técnico — faz os serviços, não vê preços". Toque → "Mudar o que pode fazer" · `DestructiveAction` "Tirar da equipe".
5. **Resumo:** não tem.
6. **Barra de baixo:** `AppBottomBar` com `SecondaryButton` "Convidar outra pessoa" (o azul já está no bloco). Sem bloco de próximo passo, vira `PrimaryButton` "Convidar pessoa".

- **Vencimento existe no código:** `Invite.expiresAt` (`lib/models/invite.dart:55-56`), 7 dias por padrão (`invite_repository.dart:13` e `:185`); a lista já calcula dias e horas (`collaborator_list_screen.dart:171-195`). O texto "vence em 2 dias" usa as chaves que já existem (`inviteExpiresInDays`, `app_pt.arb:1246`), trocando "Expira" por "vence".
- **"Reenviar" hoje só recompartilha o mesmo código** (`_reshareInvite`, `:355-362`); não renova o prazo e não há método para isso no repositório (`invite_repository.dart` só tem `create`, `updateStatus`, `cancel`, `delete`). Ver Perguntas em aberto.
- Sai: o "+" do canto; a busca (só aparece com mais de 8 pessoas); o emoji do papel.
- Erro ao carregar: `EmptyState` "Não deu para carregar a equipe." + `TextLink` "Tentar de novo".

### Outras telas do grupo

Pranchas: "Mais · dados da empresa", "Mais · convidar pessoa", "Mais · mandar convite" (`ShareSheet`), "Mais · sua conta", "Mais · plano", "Mais · preferências", "Mais · checklists", "Mais · editar checklist", "Mais · contratos". O plano usa os limites reais de `SubscriptionLimits.defaults` (`lib/models/subscription.dart:163-190`; Starter: 200 fotos, 3 checklists, 3 pessoas contando convites). Correções por tela:

- **Dados da empresa:** "Funcionalidades" → "O que usar no app"; "Gestão de ativos" → "Controle de {aparelhos}"; "Jurídico" → "Termos para o cliente" (`company_form_screen.dart:705`, `:736`, `:768`); ajudas 12 → 15 (`:712-772`); `Icons.business` Material (`:591`) → Cupertino; "Salvar" do topo (`:556`) → `AppBottomBar` "Salvar dados".
- **Novo colaborador:** rótulos "Quem você quer chamar?", "O que pode fazer", "WhatsApp"; placeholder fixo "+55 11 99999-9999" (`:368`) por l10n; tirar o ícone 100×100 (`:319-333`); "Adicionar" (`:301-307`) → `AppBottomBar` "Criar convite".
- **Meu perfil:** tudo fixo em pt ("Editar Perfil", "Salvar", "Toque para alterar", "INFORMAÇÕES PESSOAIS", `user_profile_edit_screen.dart:103-237`) → `context.l10n` (chaves `name`, `required`, `account`, `email`, `save` já existem).
- **Checklists (modelos):** os textos da tabela; i18n dos textos fixos do editor (`form_template_form_screen.dart:255`, `:266`, `:300`, `:368`, `:386`, `:560-570`); alternativa por toque a arrastar e deslizar (`:404-460`): "Mover para cima/baixo" e "Apagar pergunta" no editor do item; selo "Inativo" (`form_template_list_screen.dart:354-368`) → `StatusDot` "Desligado".
- **Contratos:** "Próxima geração" (`:195`) → "Próxima OS em 10/11/2026" em `textSecondary` 15; vazio diz onde nasce um contrato: "Para criar, abra uma OS e ligue o contrato recorrente nela." (contratos nascem dentro da OS, `order_form.dart:380-400`).
- **Assinatura / limites:** "Você atingiu o limite de formulários" → "Você já criou 3 checklists, o máximo do plano grátis."; "Faça upgrade…" → "Assine para tirar mais fotos."; dica 13 → 15 (`photo_limit_dialog.dart:26-58`).
- **Acesso negado:** aba Financeiro sempre montada (`navigation_controller.dart:30-37`) cai em "Acesso Negado" fixo em pt (`permission_widgets.dart:298`, `:332`) para técnico, supervisor e consultor. Montar a aba só com `viewFinancialReports`. Fica com a spec do financeiro; aqui só registro.

## Componentes usados

`AppTopBar`, `ScreenTitle`, `NextStepBlock`, `AppBottomBar`, `PrimaryButton`, `SecondaryButton`, `TextLink`, `DestructiveAction`, `MoreMenu`, `SectionLabel`, `AppListRow`, `StatusDot`, `EmptyState`, `AppSearchField`, `AppFormField`.

Componente novo a adicionar no doc comum:

- `ShareSheet` — sheet único para mandar convite e link da OS: um `PrimaryButton` "Mandar pelo WhatsApp" (ícone, sem verde da marca), `SecondaryButton` "Copiar" e "Outros apps", fechar com `Semantics(label:)`. Substitui os botões de `invite_share_sheet.dart` e `share_link_sheet.dart`.
- `RolePickerSheet` — lista de papéis com uma frase cada (as frases da Equipe). Usado pela Equipe e pelo Novo colaborador.

## Código morto (candidato a remoção)

~1.000 linhas de paywall e permissão que nenhuma tela alcança:

| Arquivo | Prova | Linhas |
|---|---|---|
| `lib/widgets/feature_gate_limit_modal.dart` (`FeatureGateLimitModal`) | só citado por `feature_gate_warning.dart` | 367 |
| `lib/widgets/feature_gate_warning.dart` (`FeatureGateWarning`, `FeatureGateWarningBuilder`) | nenhum uso fora do próprio arquivo | 221 |
| `lib/widgets/upgrade_prompt_modal.dart` (`UpgradePromptModal`) | nenhum uso fora do próprio arquivo | 190 |
| `lib/widgets/permission_widgets.dart`: `PermissionGuard`, `MultiPermissionGuard`, `RoleGuard`, `PermissionBuilder`, `RoleBuilder`, `ProtectedValue`, `ProtectedCurrency`, `ProtectedRouteByRole` | sem uso fora do arquivo; ficam só `ProtectedRoute` e `AccessDeniedScreen` | ~250 de 414 |

`menu_navigation/widgets/link_whatsapp_sheet.dart` (278 l.) não é morto: está atrás de `kWhatsAppBotEnabled=false` (bot desligado). Manter até decidir o futuro do bot.

## Fora de escopo / alinhar com a sessão da OS

- `forms/form_selection_screen.dart` (escolher checklist na OS, aberto em `order_form.dart:1004`) e `forms/form_fill_screen.dart` (preencher, `order_form.dart:863` e `:1023`): seguem `AppTopBar`/`AppBottomBar` da OS. Pedidos desta área para a sessão da OS: título "Qual checklist usar?" (hoje "Procedimentos", `form_selection_screen.dart:100`); "Criar checklist" como `AddRow` no fim, não "+" no topo (`:101-109`); seções "Seus checklists" / "Modelos prontos"; no preenchimento, `NextStepBlock` "Faltam 3 perguntas" → "Concluir checklist", botão "Completo" (`form_fill_screen.dart:509-516`) vira "Concluir" na barra de baixo; uma lista em vez de um cartão por pergunta (`:602-614`); "Checklist concluído" com `StatusDot` no lugar da faixa verde (`:523-547`).
- `share_link_sheet.dart`: troca para `ShareSheet` junto com a sessão da OS.
- Paywall e Customer Center são telas nativas do RevenueCat (`paywall_launcher.dart:32-59`): não se mexe.

## Ordem de implementação

1. **Textos errados do checklist e nome único "Checklists"** (`form_template_form_screen.dart:150`, `:196`, `:729-731`; menu, título, limite). Teste: título "Novo checklist" no editor. risk:low. l10n: `newChecklist`, `editChecklist`, `checklistTitleHint`, `checklistQuestion`, `checklistQuestionHint`, `checklists`, `readyTemplates`, troca de `featureLimitReached(formTemplates)`.
2. **Texto falso do convite** (`collaborator_form_screen.dart:338`) + "Aceitar" → "Entrar com código de convite". risk:low. l10n: `inviteSendByWhatsAppHint`, `joinWithInviteCode`.
3. **`ShareSheet`** (convite primeiro) sem o verde WhatsApp. Teste de widget: um só botão preenchido; contraste do texto ≥4,5:1 no claro e no escuro. risk:low. l10n: `sendByWhatsApp`, `copyCode`, `otherApps`, `close`.
4. **Equipe pela prancha**: `NextStepBlock` do convite, `StatusDot`, papel em frase, `AppBottomBar`. Teste: com convite vencendo em 2 dias aparece o bloco com "Reenviar convite" e a barra usa `SecondaryButton`; sem convite, barra com `PrimaryButton`. risk:low. l10n: `team`, `teamSubtitle(count, company)`, `inviteWaiting`, `inviteWaitingMessage(name, days)`, `resendInvite`, `inviteOtherPerson`, `waitingToJoin`, `onTheTeam`, frases de papel (`roleOwnerShort`…), `inviteExpired`.
5. **Aba Mais pela prancha**: sem ícones, seções novas, sub-telas "Avisos" e "Plano", título "Mais". Teste: admin vê "Sua empresa"; técnico não vê "Dados da empresa" nem "Equipe"; nenhum ícone colorido. risk:low (não muda regra de permissão, só layout). l10n: `yourCompany`, `registries`, `thisDevice`, `appearance`, `notices`, `planSeeWhatProUnlocks`, `teamSummary(people, invites)`, `redoInitialSetup`.
6. **i18n de Meu perfil, Dados da empresa, Novo colaborador, Contratos** (textos, 15 mínimo, `AppBottomBar`). risk:low. l10n: `saveData`, `createInvite`, `contractEvery(n, unit)`, `contractNextOrder(date)`, `contractAutoCreates`.
7. **Remover o código morto do paywall/permissão**. Teste: `flutter analyze` limpo. risk:low (não toca billing ativo; nada aqui é alcançável).

## Perguntas em aberto

1. **"Reenviar convite" renova o prazo?** Hoje só recompartilha o mesmo código sem mudar `expiresAt`. Se o convite já venceu, reenviar o código não adianta. Opções: (a) reenviar renova para mais 7 dias (método novo no repositório; `firestore.rules` de `invites` pode precisar mudar → risk:high); (b) convite vencido só pode ser cancelado e refeito. Qual?
2. **Contratos sem tela de criar:** o vazio manda abrir uma OS e usar "… > Repetir". Isso é o caminho que queremos ensinar, ou vale um "Novo contrato" na lista?
