# Telas do app: primeiro acesso

Status: proposta · 2026-10-09 · base: `docs/APP_DESIGN_SYSTEM.md` · componentes: `2026-10-09-telas-componentes-design.md`

Grupo: login, entrada por e-mail, telas de erro do `AuthWrapper`, onboarding inteiro e convites no primeiro acesso. Tudo aqui acontece uma vez por usuário, então o ganho não é polir cada tela: é **cortar telas**. Canvas: https://claude.ai/artifact/NfHsv1Ge52LXGdpd9ZYihz, página "Telas do app".

## Telas do grupo

| Tela | Arquivo | Uso | O que muda |
|---|---|---|---|
| Login | `lib/screens/login.dart` | sem usuário (`main.dart:165-170`) | Textos, tokens, erro mapeado |
| Entrar com e-mail | `lib/screens/email_login_screen.dart` | revisão da Apple, raro | Tokens, alvos 44, sem "CREDENCIAIS" |
| Erros do AuthWrapper | `lib/screens/auth_wrapper.dart:155-211`, `:509-527` | falha ao carregar empresa/ramo | Sem erro cru; `_SegmentLoader` ganha "Tentar de novo" |
| Welcome | `onboarding/welcome_screen.dart` | 1ª tela do dono novo | **Sai** |
| Dados básicos | `onboarding/company_info_screen.dart` | nome, endereço, logo | Vira "Seu negócio" (nome + telefone) |
| Contatos | `onboarding/company_contact_screen.dart` | telefone, e-mail, site | **Sai** (telefone vai para "Seu negócio") |
| Escolha o ramo | `onboarding/select_segment_screen.dart` | ramo | Vira a 1ª tela do onboarding |
| Especialidades | `onboarding/select_subspecialties_screen.dart` | só ramos com especialidades | Fica, mas opcional |
| Quase lá | `onboarding/confirm_bootstrap_screen.dart` | exemplos + 2 interruptores | **Sai** como tela; vira o carregando de "Seu negócio" |
| Questionário 1/3–3/3 | `onboarding/segmentation_onboarding_screen.dart` | pesquisa | **Sai do primeiro acesso** (ver Perguntas em aberto) |
| Convites pendentes | `onboarding/pending_invites_screen.dart` | convite por e-mail | Um botão azul, "Recusar" no lugar de "Excluir" |
| Aceitar convite | `onboarding/accept_invite_screen.dart` | código de convite | Erro mapeado; entra pelo link na tela do ramo |
| WhatsApp | `onboarding/whatsapp_onboarding_screen.dart` | só com `kWhatsAppBotEnabled` (`feature_flags.dart:6`, hoje `false`) | Fora de escopo |

## Fluxo atual vs proposto

Hoje (dono novo, ramo com especialidades, com exemplos), decidido em `auth_wrapper.dart` e na cadeia de push `welcome_screen.dart:45-59` → `company_info_screen.dart:83-97` → `company_contact_screen.dart:94-108` → `select_segment_screen.dart:63-104` → `select_subspecialties_screen.dart:94-110` → `confirm_bootstrap_screen.dart:262-273` → `/` → `auth_wrapper.dart:530-538`:

```
Login → Welcome → Dados básicos → Contatos → Ramo → Especialidades → Quase lá
      → (carregando, 5 mensagens) → Questionário 1/3 → 2/3 → 3/3 → Home
```

**10 telas, ~15 toques e 2 campos digitados antes da home.** O atalho "Configurar Depois" (`welcome_screen.dart:63-148`) cria "Minha Empresa" (`:89`), ramo `other` (`:90`), sem exemplos, e mesmo assim cai no questionário.

Proposto:

```
Login → Qual é o seu ramo? → [Especialidades, só se o ramo tiver, opcional]
      → Como se chama o seu negócio? → (Preparando seu PraticOS…) → Home com OS de exemplo
```

**3–4 telas, ~5 toques e 2 campos.**

### Cortes e a prova de cada um

| Hoje | Proposta | Prova de que o app já funciona sem isso |
|---|---|---|
| Welcome (vitrine + "Configurar Depois") | Cortar | Não coleta nada (`welcome_screen.dart:225-265`); o "pular" cria empresa genérica que cai no mesmo questionário |
| Logo e endereço | Adiar para Ajustes > Empresa (`company_form_screen.dart`) | Opcionais (`company_info_screen.dart:147-180`, `:201-208`) |
| E-mail e site do negócio | Adiar | Opcionais (`company_contact_screen.dart:165-178`) |
| Nome e telefone em 2 telas | Juntar em "Seu negócio" | O resto das duas telas foi adiado |
| Especialidades obrigatórias | Opcional | Ramo sem especialidade já passa `const []` (`select_segment_screen.dart:100`) |
| Interruptores Agendamento/Atendimento externo | Cortar (padrão do ramo) | `_SegmentLoader` já resolve os padrões (`auth_wrapper.dart:432-450`); a tela diz "pode alterar depois" (`confirm_bootstrap_screen.dart:386`) |
| "Deseja criar dados de exemplo?" | Padrão sim; `TextLink` "Começar sem exemplos" | É o que leva à home com OS (`bootstrap_service.dart:478-492`) |
| Questionário de 3 perguntas | Tirar do primeiro acesso | Só grava em `users/{uid}.onboardingSegment` (`segmentation_onboarding_screen.dart:50-52`); a pergunta 1 repete o ramo (`:82-88`) |
| Convite só por e-mail | Link "Recebi um código de convite" na tela do ramo | Hoje o `AuthWrapper` só procura convite por e-mail (`auth_wrapper.dart:224`, `:272-275`); quem tem código é empurrado a criar empresa |

## Problema atual (achados)

| Regra | Evidência | O que o usuário vê | Correção |
|---|---|---|---|
| **Login** R3 | `login.dart:298`, `:321` `'${errorSignInApple}: $e'` | Snackbar com `[firebase_auth/...]`; cancelar a folha da Apple também vira erro | Mapear códigos como `email_login_screen.dart:57-68`; cancelar não mostra nada |
| Login A11y | `login.dart:255`, `:262` termos 13 em `textTertiary`; link `:150-160` sem padding | Privacidade ilegível; alvo < 44 | `label` 15 `textSecondary`; `TextLink` |
| **E-mail** R3/A11y | `email_login_screen.dart:136` "CREDENCIAIS"; `:188-200` olho sem `Semantics`; `:237` "?" concatenado | Caixa alta; VoiceOver lê "botão"; pontuação montada | Sem cabeçalho; `Semantics(label:)`; string inteira no .arb |
| **AuthWrapper** R3 | `auth_wrapper.dart:188-199` mostra `error` cru em 12 | Exceção em inglês | Esconder; logar no Crashlytics |
| **_SegmentLoader** sem saída | `auth_wrapper.dart:509-527`: `Scaffold` Material, `Colors.red`/`Colors.grey`, texto do erro 12, **nenhum botão** | Só resta fechar o app | `EmptyState` de erro com `PrimaryButton` "Tentar de novo" (reusar `_buildErrorRetryScreen`, `:155-211`) |
| **Welcome** R3 | `welcome_screen.dart:71`, `:81`, `:120` exceções em português; `:158` `'${errorCreatingCompany}: $e'` | "Erro ao criar empresa: Exception: Empresa não foi salva..." | Tela sai; erro de criação vai para "Seu negócio" |
| **Dados básicos** i18n | `company_info_screen.dart:137` `Text('Dados Básicos')` | Título só em português | Tela vira "Seu negócio" com l10n |
| **Contatos** R1 | `company_contact_screen.dart:123`, `:137`, `:157` três rótulos iguais; `:114-118` spinner entre telas | Pisca carregando; mesma palavra 3 vezes | Tela sai |
| **Ramo** R3 | `select_segment_screen.dart:129` `${snapshot.error}` em vermelho; `:162-168` título = nome da empresa; `:190` "SEGMENTOS DISPONÍVEIS" | Exceção crua; título não é a pergunta | `EmptyState` de erro; título "Qual é o seu ramo?" |
| **Especialidades** R1 | `select_subspecialties_screen.dart:77-92`, `:228-231` botão cinza "Selecione ao menos uma opção" | Botão que parece quebrado | Sempre "Continuar"; sem marcar = `[]` |
| **Quase lá** R1/R3 | `confirm_bootstrap_screen.dart:285` `e.toString()`; `:116`, `:141`, `:195` exceções hardcoded; `:359-382` 2 interruptores; `:401-441` cartão de 5 benefícios | "Exception: Usuário não encontrado no Firestore"; 2 decisões técnicas | Tela sai; erro fixo + "Tentar de novo" |
| **Questionário** R3 | `segmentation_onboarding_screen.dart:64` `e.toString()`; `:150` contador "1/3" | Exceção crua; "etapa X de Y" | Sai do primeiro acesso |
| **Convites** R2/R3 | `pending_invites_screen.dart:257` + `:388` dois `filled`; `:139` confirmar "Recusar" com "Excluir"; `accept_invite_screen.dart:87`, `:93`, `:119` erro da API cru | 2+ botões azuis; "Excluir" para recusar | Um `PrimaryButton`; "Recusar"; erros mapeados |

Vale para todas: `CupertinoButton.filled`/`activeBlue`, títulos 34, textos 13–14 e cores sem `resolveFrom` → `PrimaryButton`, `ScreenTitle`, `AppColors`.

## Tela proposta

### Prancha "Primeiro acesso · login"
1. Topo: nenhum.
2. Título: logo 80; `ScreenTitle` "Entre para começar" / "Use a conta que você já tem no celular."
3. Próximo passo: botão 58 **"Continuar com Apple"** (preto, padrão Apple, `SignInWithAppleButton`). **Exceção documentada** ao "um botão azul": a HIG da Apple exige o estilo dela, e ele não é azul.
4. Conteúdo: `SecondaryButton` 58 "Continuar com Google"; `TextLink` "Entrar com e-mail e senha" (abre `EmailLoginScreen`).
5. Resumo: rodapé `label` 15 "Ao continuar, você aceita a Política de privacidade." (link em `accentText`).
6. Barra: nenhuma.
- Sai: `appSubtitle` genérico. Erro: frase fixa por código ("Não deu para entrar com a Apple. Tente de novo."); cancelar a folha não mostra erro.
- Entrar com e-mail (sem prancha): `AppTopBar` "‹ Voltar"; `AppFormField` "E-mail" e "Senha" (olho com `Semantics`, alvo 44); `PrimaryButton` "Entrar"; `TextLink` "Esqueceu a senha?". Sem cabeçalho de seção.

### Prancha "Primeiro acesso · ramo"
1. Topo: só `TextLink` "Sair" (para quem entrou com a conta errada).
2. Título: "Qual é o seu ramo?" / "Assim o app já vem com os serviços e checklists do seu trabalho."
3. Próximo passo: nenhum. **Tocar no ramo avança**; não há botão azul nesta tela.
4. Conteúdo: `AppListRow` por ramo: ícone do segmento + nome (19) + seta. Sem contador de especialidades, sem maleta, sem cabeçalho.
5. Resumo: `TextLink` "Recebi um código de convite" → `AcceptInviteScreen`.
6. Barra: nenhuma.
- Carregando: lista com `LoadingState` de uma frase. Erro: `EmptyState` "Não deu para carregar os ramos. Confira a internet." + "Tentar de novo".

**Especialidades (1b, prancha "Primeiro acesso · especialidades").** Só para ramo com `subspecialties`. `AppTopBar` "‹ Ramo"; título "O que você atende?" / "Marque o que fizer sentido. Dá para mudar depois."; `AppListRow` selecionável com `Semantics(selected:)`; `AppBottomBar` com `PrimaryButton` "Continuar" sempre ativo (sem marcar = lista vazia).

### Prancha "Primeiro acesso · seu negócio"
1. Topo: `AppTopBar` "‹ Ramo" (ou "‹ Especialidades").
2. Título: "Como se chama o seu negócio?"
3. Próximo passo: `NextStepBlock` variante `info`: "Vamos colocar umas OS de exemplo para você ver como fica. Você apaga quando quiser."
4. Conteúdo: `AppFormField` "Nome" (placeholder "Ex.: Oficina do Zé"); `AppFormField` "Telefone" com máscara do país e dica "Aparece no orçamento que o cliente recebe."
5. Resumo: nenhum.
6. Barra: `AppBottomBar` com `PrimaryButton` "Criar meu PraticOS" e `TextLink` "Começar sem exemplos" (cria sem `runBootstrap`).
- Sai: logo, endereço, e-mail, site (Ajustes > Empresa); interruptores (padrão do ramo); cartão de benefícios.
- Carregando: tela inteira com uma frase, "Preparando seu PraticOS…" (no lugar das 5 mensagens técnicas). Erro: "Não deu para terminar. Confira a internet e tente de novo." + "Tentar de novo", sem `e.toString()`.

**Convite por e-mail (prancha "Primeiro acesso · convite recebido").** Mantém prioridade sobre a criação (`auth_wrapper.dart:224`). Com 1 convite: título "A Oficina Exemplo chamou você para a equipe"; `AppListRow` "Convidado por Ana Ribeiro · você entra como técnico"; `PrimaryButton` "Entrar na equipe"; `TextLink` "Recusar convite" (confirma com "Recusar" / "Voltar"), "Tenho outro código", "Criar minha própria empresa". Com N convites: lista de `AppListRow`, tocar abre a confirmação; nenhum botão azul por linha. Aceitar por código: placeholder "Ex.: 7K2P9QXA" (o prefixo já é posto em `accept_invite_screen.dart:55`); erro com ícone + texto 15 em `danger`.

## Componentes usados

`AppTopBar`, `ScreenTitle`, `NextStepBlock` (variante `info`), `AppBottomBar`, `PrimaryButton`, `SecondaryButton`, `TextLink`, `AppListRow`, `AppFormField`, `EmptyState`.

### Componente novo a adicionar no doc comum
- `LoadingState`: tela ou bloco com uma frase só ("Preparando seu PraticOS…"), sem lista de etapas.
- Variante de erro do `EmptyState`: frase fixa + `PrimaryButton` "Tentar de novo"; nunca mostra exceção (vai para o Crashlytics).
- `AppListRow` selecionável (multisseleção com `Semantics(selected:)`), se o doc comum não cobrir.
- Exceção ao "um botão azul": botão da Apple no login.

## Fora de escopo

- `WhatsAppOnboardingScreen`: tela morta enquanto o flag estiver `false`. Verificar à parte se o pedido de ATT (`whatsapp_onboarding_screen.dart:21-23`) ainda acontece em outro lugar.
- Reabrir onboarding pelo Ajustes (`settings.dart:705-735`): passa a abrir só Ramo + Especialidades; nome e telefone já estão em Ajustes > Empresa.

## Ordem de implementação

1. **Erros sem saída e erros crus** (`_SegmentLoader` com "Tentar de novo"; `AuthWrapper`, login, ramo, aceitar convite com frase fixa). risk:low. l10n: `errorTryAgainGeneric`, `errorSignInAppleFriendly`, `errorSignInGoogleFriendly`, `errorLoadSegments`.
2. **Visual do login e e-mail** (tokens, `TextLink`, alvos 44, sem "CREDENCIAIS", "Esqueceu a senha?" inteiro). risk:low. l10n: `loginTitle`, `loginSubtitle`, `loginWithEmailLink`, `privacyFooter`.
3. **Convites** (um `PrimaryButton`, "Recusar", `AppListRow`, textos). risk:low (só UI; aceitar/recusar não muda). l10n: `inviteTitleOne`, `inviteInvitedBy`, `joinTeam`, `declineInvite`.
4. **Link "Recebi um código de convite" na tela do ramo.** risk:low (abre tela existente).
5. **Especialidades opcionais.** risk:high: muda o que é gravado na criação da empresa (lista vazia), modelo compartilhado.
6. **Nova tela "Seu negócio" + corte de Welcome, Contatos e Quase lá** (bootstrap com exemplos por padrão, sem interruptores, carregando de uma frase). risk:high: mexe na criação de empresa e no `AuthWrapper` (Auth é risk:high no CLAUDE.md). Teste: dono novo sai do login com empresa, ramo e OS de exemplo em 3–4 telas; "Começar sem exemplos" não cria OS. l10n: `onboardingSegmentTitle`, `onboardingSegmentSubtitle`, `onboardingBusinessTitle`, `onboardingPhoneHint`, `onboardingSamplesInfo`, `createMyPraticos`, `startWithoutSamples`, `preparingPraticos`.
7. **Questionário fora do primeiro acesso** (gravar `onboardingSegment` com `serviceType` derivado do ramo, ou parar de exigir). risk:high (fluxo do `AuthWrapper`). **Só depois da resposta abaixo.**

## Perguntas em aberto

1. **Questionário de segmentação: o dado ainda é usado?** Tipo de serviço, volume mensal e tamanho da equipe vão para `users/{uid}.onboardingSegment` e nada no app lê. Rafael, isso alimenta marketing, ads ou algum relatório? Se sim, perguntar depois (uma pergunta, após a primeira OS concluída) em vez de remover. Se não, remover.
2. Telefone continua obrigatório? Hoje é (`company_contact_screen.dart:162`), mas o PDF só imprime se existir (`pdf_main_os_builder.dart:102`). A prancha mantém o campo; falta decidir se bloqueia o "Criar meu PraticOS".
3. "Configurar Depois" some de vez? A proposta remove: com 3–4 telas não há o que pular, e ele hoje cria "Minha Empresa" vazia. Confirmar.
