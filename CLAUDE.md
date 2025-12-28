# PraticOS - Instruções para Claude Code

## Visão Geral
PraticOS é um aplicativo Flutter para gestão de ordens de serviço (OS) para oficinas e prestadores de serviços. O app segue rigorosamente as **Apple Human Interface Guidelines (HIG)** para proporcionar uma experiência nativa iOS.

## Setup do Ambiente

### Requisitos
- Flutter SDK (gerenciado via FVM)
- FVM (Flutter Version Management)

### Configuração Inicial (Worktree)
Ao criar um novo worktree ou clonar o projeto, execute:

```bash
.claude/setup-worktree.sh
```

Este script irá:
1. Instalar dependências (`fvm flutter pub get`)
2. Gerar arquivos MobX e JSON serialization (`build_runner`)
3. Copiar arquivos de configuração Firebase (se disponíveis)

### Comandos Frequentes

```bash
# Instalar dependências
fvm flutter pub get

# Gerar arquivos .g.dart (MobX, json_serializable)
fvm flutter pub run build_runner build --delete-conflicting-outputs

# Analisar código
fvm flutter analyze

# Rodar testes
fvm flutter test

# Build iOS
fvm flutter build ios

# Build Android
fvm flutter build apk
```

## Diretrizes de Código

### UI/UX - Apple HIG
Consulte `UX_GUIDELINES.md` para todas as diretrizes visuais. Principais pontos:

- **Widgets**: Usar `Cupertino*` (não Material)
- **Scaffold**: `CupertinoPageScaffold`
- **Navigation**: `CupertinoNavigationBar`, `CupertinoSliverNavigationBar`
- **Forms**: `CupertinoListSection.insetGrouped` com `CupertinoTextFormFieldRow`
- **Cores**: `CupertinoColors.*` com `.resolveFrom(context)` para dark mode
- **Ícones**: `CupertinoIcons.*`

### Dark Mode
Cores dinâmicas DEVEM usar `.resolveFrom(context)`:
```dart
// Correto
color: CupertinoColors.label.resolveFrom(context)

// Incorreto
color: CupertinoColors.label
```

### Estrutura do Projeto
```
lib/
├── models/          # Modelos de dados
├── mobx/            # Stores MobX (*.dart + *.g.dart)
├── repositories/    # Acesso ao Firestore
├── screens/         # Telas do app
├── services/        # Serviços (photo, auth, etc)
└── widgets/         # Widgets reutilizáveis
```

### MobX
- Stores em `lib/mobx/`
- Arquivos `.g.dart` são gerados automaticamente
- Após modificar stores, rodar: `fvm flutter pub run build_runner build`

### Firebase
- Firestore para persistência
- Firebase Storage para fotos
- Arquivos de config (`GoogleService-Info.plist`, `google-services.json`) não são commitados

## Arquivos Importantes

| Arquivo | Descrição |
|---------|-----------|
| `UX_GUIDELINES.md` | Diretrizes de UI/UX (HIG) |
| `lib/screens/order_form.dart` | Formulário principal de OS |
| `lib/mobx/order_store.dart` | Store principal de ordens |
| `lib/models/order.dart` | Modelo de ordem de serviço |

## Convenções

- **Idioma**: Interface em Português (BR)
- **Moeda**: R$ (BRL) com formatação `pt_BR`
- **Datas**: Formato `dd/MM/yyyy`
