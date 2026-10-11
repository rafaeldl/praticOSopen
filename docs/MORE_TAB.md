# MORE_TAB.md

## Visão Geral
Aba Mais redesenhada: uma lista plana com 9 linhas (Sua conta, Sua empresa, Equipe, Plano, Catálogo, Checklists, Avaliações, Lembretes, Avançado), sem ícones coloridos.

## Arquitetura
- `lib/screens/menu_navigation/settings.dart`: monta `MoreView` com as linhas que o papel pode ver (mesmas permissões de antes) e abre o destino.
- `more/more_view.dart`: lista (`MoreDestination`, `MoreVisibility`).
- `more/account_screen.dart` + `account_deletion.dart`: perfil, trocar de empresa, entrar com código, Sair e "Apagar minha conta" (duas confirmações, aviso da assinatura da loja, reautenticação; a exclusão continua em `AuthStore.deleteAccount`).
- `more/my_company_screen.dart`: Dados da empresa e "Como você trabalha". "Valores e cobrança" fica desligado (visual) até existir `Company.useFinancial` (passo risk:high separado).
- `more/plan_screen.dart`, `reminders_screen.dart`, `advanced_screen.dart`.
- `invite_form.dart`: "Convidar pessoa" em sheet (nome opcional, e-mail, WhatsApp, 5 papéis incluindo Supervisor, ✓ na escolha).

## Regras de Negócio
- Linhas escondidas por permissão: Sua empresa e Avaliações (`manageCompany`), Equipe (`manageUsers`), Checklists (`manageForms`), Catálogo (`viewServices` ou `viewProducts`), Avançado (só com Integrações ou lista de veículos com `useDeviceManagement`).
- Idioma e aparência seguem o iPhone; o Android mantém a linha Idioma em Lembretes.
- Convite vencido: ação "Cancelar e convidar de novo" (sem mudar regras do Firestore). Convidar com e-mail repetido e vencido cancela o antigo sozinho.
- Catálogo: enquanto a tela única "Serviços | Produtos" não entra, abre a lista existente (pergunta qual quando o papel vê as duas).
