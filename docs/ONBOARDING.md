# ONBOARDING.md

## Visão Geral

Primeiro acesso do dono sem empresa: **Seu ramo → [Especialidades] → Seu negócio → Início**.
Substitui Boas-vindas, Dados básicos, Contatos, "Quase lá" e o questionário de 3 passos
(10 telas → 2 ou 3). Specs: `docs/superpowers/specs/2026-10-09-telas-primeiro-acesso-design.md`,
`2026-10-09-telas-mapa-design.md` (decisão 1: questionário sai), `2026-10-11-telas-paridade-design.md`
e `2026-10-11-financeiro-opcional-design.md`.

## Arquitetura

| Peça | Arquivo |
|---|---|
| Entrada e dependências (`OnboardingFlow`, `OnboardingDeps`, `OnboardingSession`) | `lib/screens/onboarding/onboarding_flow.dart` |
| Seu ramo | `lib/screens/onboarding/select_segment_screen.dart` |
| Especialidades (só ramo com especialidades) | `lib/screens/onboarding/select_subspecialties_screen.dart` |
| Seu negócio | `lib/screens/onboarding/your_business_screen.dart` |
| Criação da empresa (`OnboardingSetup`, `FirebaseOnboardingSetup`) | `lib/services/onboarding_service.dart` |
| Decisão de rota | `lib/screens/auth_wrapper.dart` |
| Login (Apple, Google, link para e-mail) | `lib/screens/login.dart` |
| Entrar com e-mail | `lib/screens/email_login_screen.dart` |
| Convites recebidos / código de convite | `lib/screens/onboarding/pending_invites_screen.dart`, `accept_invite_screen.dart` |
| Carregando | `lib/screens/loading_screen.dart` |

`OnboardingDeps.firebase(authStore)` liga o app real; os testes usam fakes
(`test/screens/onboarding/onboarding_flow_test.dart`).

### Firestore

Mesmas escritas de antes (nenhuma regra nova):

- Empresa nova: `UserStore.createCompanyForUser` → `AuthService.signup` (empresa + vínculo do usuário + papel admin).
- Empresa que já existe sem ramo: `CompanyStore.updateCompany` (mantém endereço, e-mail, site e logo).
- Depois: `ClaimsService.waitForCompanyClaim`, `BootstrapService.syncCompanyFormsFromSegment` e,
  com exemplos, `BootstrapService.executeBootstrap`.

Campos gravados na empresa: `name`, `phone` (só se preenchido), `segment`, `subspecialties`
(`null` se nenhuma), `fieldService` (padrão do ramo), `useScheduling: true`,
`termsOfService` (padrão do ramo, empresa nova) e **`useFinancial`** (novo).

## Fluxo de Dados

```
AuthWrapper (sem empresa e sem convite pendente, ou empresa sem ramo)
  → OnboardingFlow → Seu ramo (toque no ramo avança; ✓ no escolhido)
  → [Especialidades: todas marcadas; "Continuar" sempre ativo]
  → Seu negócio ("Como você aparece para o cliente"): nome opcional — vazio usa o nome
    da pessoa (só é obrigatório se a conta não tiver nome), telefone (opcional), "Valores e cobrança"
  → "Criar meu PraticOS" (com exemplos) ou "Começar sem exemplos"
  → saveCompany → seedCompany → finish (recarrega AuthStore) → '/' (Início)
```

Convite pendente pelo e-mail continua com prioridade (`PendingInvitesScreen`); "Criar minha
empresa" de lá abre o `OnboardingFlow`. "Recebi um código de convite" na tela do ramo abre
`AcceptInviteScreen` e, aceito, recarrega o `AuthStore` e volta para `/`.

## Regras de Negócio

1. Telefone é opcional; em branco não grava `phone`.
2. "Valores e cobrança" começa no padrão do ramo (`segments/{id}.useFinancial`, ausente = ligado).
3. Agenda ligada e atendimento fora pelo padrão do ramo (sem interruptores no primeiro acesso).
4. Especialidades: nenhuma marcada grava `subspecialties: null`; para checklists e exemplos
   usa todas as do ramo (o `_default` do bootstrap pode não existir em ramo com especialidades).
5. Erro mostra uma frase fixa e "Tentar novamente"; nunca a exceção. A nova tentativa reaproveita
   a empresa já salva (não cria uma segunda).
6. Carregando: uma frase só, "Preparando seu PraticOS…".
7. "Sair" no topo do ramo, para quem entrou com a conta errada.
8. O questionário (`users/{uid}.onboardingSegment`) não aparece mais para ninguém.
9. Erro ao criar a empresa tem saída: botão de voltar no topo devolve ao formulário com o que
   foi digitado; "Tentar novamente" refaz.

## Padrão visual

Segue `docs/APP_DESIGN_SYSTEM.md`:

- Cada passo usa `OnboardingPage` com `AppNavBar` (título grande, voltar de vidro com o nome do
  passo anterior: "‹ Seu ramo", "‹ Especialidades").
- Ramo e especialidades usam as mesmas linhas de `AppListRow` dos seletores de Ajustes
  (`company_editors.dart`): emoji, nome e ✓ azul no escolhido. Título em pergunta
  ("Qual é o seu ramo?", "O que você atende?") e uma frase embaixo.
- Um botão azul por tela (`PrimaryButton`, 58); o resto é `TextLink`. Exceção: o botão preto
  "Continuar com Apple" no login (padrão exigido pela Apple).
- Entrar com e-mail: campos `AppFormField`, olho com rótulo falado e alvo de 44, erro numa frase
  fixa acima do botão (nunca a mensagem do Firebase) e "Esqueceu a senha?" sempre à mão.
- Vários convites: tocar num convite abre a tela dele (mesmo botão "Entrar na equipe" e link
  "Recusar convite"), nunca um menu de ações.
- Código de convite: voltar de vidro no topo, no lugar do botão "Cancelar".
- Cores só de `AppColors` com `.resolveFrom(context)`; o fundo do login é `accentSoft`.

## Analytics

`tutorial_begin` (`variant: setup`, primeiro toque num ramo), `company_created`,
`tutorial_complete`: ver `docs/FIREBASE_ANALYTICS.md`.

## Modo individual (iOS 3.1.1)

O app não fala em "cadastro de empresa": a empresa continua existindo por baixo (assinatura,
OS, permissões), mas para o usuário é a conta dele. Spec:
`docs/superpowers/specs/2026-10-16-modo-individual-design.md`. Equipe é recurso pago: no Free,
"Convidar" abre os planos (IAP) antes do formulário.
