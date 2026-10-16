# Modo individual: começar sem cadastrar empresa

Status: proposta · 2026-10-16 · substitui o PR #406 (iOS só por convite), que fica como plano B

## Por que

A Apple recusou o iOS pela regra 3.1.1, "account registration for businesses and organizations", mesmo com os planos à venda por IAP (10/10, build 160). O revisor viu um app de **cadastro de empresa** (Trocar Empresa, Dados da Empresa, Colaboradores) e entendeu que existe venda por fora. O 1.56.0 só passou como correção de bug, com a promessa de resolver isso na próxima versão.

A base de clientes já é, na prática, de pessoas sozinhas:

- 98 das 129 empresas com OS em 90 dias têm uma pessoa só (76%)
- 24 dessas 129 se chamam "Minha Empresa", "Empresa" ou "Teste": a pessoa só queria passar da tela

Então o app passa a ser **de uma pessoa que organiza as suas OS**. Trabalhar em equipe vira um recurso pago dessa conta, comprado pela Apple. Não existe mais o passo "cadastrar empresa".

## A ideia em uma frase

Por baixo nada muda: continua existindo uma empresa (`companies/{id}`) criada no primeiro acesso, com o mesmo dono, os mesmos papéis e a mesma assinatura. O que muda é **o que a tela pede e como chama as coisas**.

Sem campo novo no modelo, sem migração e sem mudança em regras do Firestore, Functions ou planos.

## O que muda

### 1. Primeiro acesso

Hoje: Ramo → [Especialidades] → **Seu negócio** (nome obrigatório) → Início.

Proposto: Ramo → [Especialidades] → **Como você aparece para o cliente** → Início.

- Mesma tela (`lib/screens/onboarding/your_business_screen.dart`), outro título e outro texto.
- **Nome deixa de ser obrigatório** (tira o `validator` em `:178`). Vazio grava o nome da pessoa (`users/{uid}.name` ou `displayName` do login).
- Placeholder explica para que serve: "Aparece na OS e no PDF. Ex.: Refrigeração Silva ou o seu nome".
- Telefone e "Como você trabalha" continuam iguais.
- Mesmo fluxo em iOS, Android e web.

### 2. Palavras no app (pt, en, es)

Tirar "empresa" de onde o revisor olha. Só textos (`lib/l10n/app_*.arb`), sem trocar telas.

| Hoje | Proposto | Onde |
|---|---|---|
| Minha empresa (título do perfil) | Ajustes | `settings.dart:83` (`myCompany`) |
| Empresa (seção) | Seu trabalho | `moreSectionCompany` |
| Sua empresa | Dados para o cliente | `yourCompany`, `my_company_screen.dart` |
| Dados da Empresa | Dados para o cliente | `companyData` |
| Trocar Empresa | Trocar de conta | `switchCompany`, `account_screen.dart:147-157` |
| Colaboradores | Equipe | `collaborators` |
| Seu negócio / Como se chama o seu negócio? | Como você aparece para o cliente / Nome que aparece na OS | `onboardingBusinessTitle`, `onboardingBusinessName` |

Regra para o resto: varrer os `.arb` por "empresa/company/compañía" nas telas do perfil, equipe e convites. Onde a palavra for só nome da coisa, trocar por "conta", "trabalho" ou "equipe". Onde for necessária (ex.: nota fiscal, CNPJ), manter.

### 3. Equipe como recurso pago

Já funciona assim: o Free aceita 1 usuário e convidar alguém passa pelo limite (`collaborator_store.dart:228`, `feature_gate_service.dart`). Só conferir que:

- A linha "Equipe" aparece para o dono no Free com uma frase do tipo "Chame quem trabalha com você (a partir do Starter)".
- Tocar em "Convidar" no Free abre o paywall da Apple, e não um erro.

### 4. Notas para a revisão da Apple

Reescrever `ios/fastlane/metadata/review_information/notes.txt` e o `Deliverfile` (iguais, em inglês):

- O app é uma ferramenta pessoal para quem presta serviço organizar as suas OS. Não há cadastro de empresa nem de organização.
- A conta é gratuita; tudo que é pago (fotos, checklists, PDF sem marca, equipe) é vendido só por IAP.
- Trabalhar em equipe é um recurso pago da conta, também por IAP.
- Sem links, preços ou chamadas para compra fora do app.
- Tirar a frase "Creating a company account is free" e "service companies".

Conferir a descrição da loja (`ios/fastlane/metadata/*/description.txt`): "pequenas empresas" como público pode ficar; nada de "cadastre sua empresa".

## O que não muda

- Quem já usa: nada muda nos dados nem no plano; só os textos.
- Convites ("Entrar com código", convites pendentes) continuam iguais.
- Assinatura continua na empresa (`appUserID` = `companyId` no RevenueCat).
- Venda por fora (Asaas/site) para empresas maiores continua possível, mas o app nunca fala dela.

## Fora de escopo (de propósito)

- Campo `type` (pessoal/empresa) e botão "Criar empresa": não precisa. Virar equipe é só convidar alguém.
- Sumir com a área pessoal vazia quando a pessoa aceita convite de outra empresa: fica o "Trocar de conta". Ver depois se incomodar.
- Mudar planos, preços ou limites.

## Plano B, se a Apple recusar de novo

No iOS, esconder a linha "Equipe" e o "Convidar" para o dono (uma regra `PlatformPolicy.canManageTeamInApp`, como no #406). A pessoa continua começando sozinha pelo iPhone; equipe se monta pelo Android ou pela web. Entrar por convite continua no iPhone.

## Testes

- `your_business_screen`: salvar com nome vazio grava o nome da pessoa; com nome, grava o nome.
- Perfil: textos novos nas linhas (pt).
- Convidar no Free abre o paywall.
- `fvm flutter analyze`, `fvm flutter test`.

## Lançamento

1. PR com isso (`risk:high`: mexe no primeiro acesso e nas notas da revisão).
2. RC no TestFlight: conta nova sem convite e conta demo.
3. Promover Android; enviar iOS para revisão com a nota nova, junto com o redesign.
4. Fechar o #406 sem mergear, citando este documento.
