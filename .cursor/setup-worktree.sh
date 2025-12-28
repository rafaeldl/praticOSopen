#!/bin/bash
set -e

# Script para configurar worktree do Flutter
# Copia arquivos não commitados do projeto original
# $ROOT_WORKTREE_PATH é fornecido automaticamente pelo Cursor

echo "=========================================="
echo "  Configurando worktree do Flutter"
echo "=========================================="
echo ""

# Verificar se ROOT_WORKTREE_PATH está definido
if [ -z "$ROOT_WORKTREE_PATH" ]; then
  echo "⚠️  AVISO: ROOT_WORKTREE_PATH não está definido"
  echo "   O script pode não funcionar corretamente"
  echo ""
fi

# Determinar comando Flutter (FVM ou direto)
FLUTTER_CMD="flutter"
if command -v fvm &> /dev/null; then
  FLUTTER_CMD="fvm flutter"
  echo "🔧 Usando FVM para gerenciar Flutter"
elif ! command -v flutter &> /dev/null; then
  echo "⚠️  AVISO: Flutter não encontrado no PATH e FVM não está instalado"
  echo "   Pulando instalação de dependências e build_runner"
  echo ""
  FLUTTER_CMD=""
fi

# Executar comandos Flutter se disponível
if [ -n "$FLUTTER_CMD" ]; then
  echo "📦 Instalando dependências do Flutter..."
  $FLUTTER_CMD pub get
  
  echo ""
  echo "🔨 Gerando arquivos .g.dart (MobX e json_serializable)..."
  $FLUTTER_CMD pub run build_runner build --delete-conflicting-outputs
  echo ""
fi

# Copiar .fvmrc se não existir no worktree (configuração FVM)
if [ -f "$ROOT_WORKTREE_PATH/.fvmrc" ]; then
  if [ ! -f ".fvmrc" ]; then
    echo "📋 Copiando .fvmrc..."
    cp "$ROOT_WORKTREE_PATH/.fvmrc" ".fvmrc"
    echo "   ✓ Arquivo copiado com sucesso"
  else
    echo "✓ .fvmrc já existe no worktree"
  fi
fi

# Copiar GoogleService-Info.plist se não existir no worktree
if [ -f "$ROOT_WORKTREE_PATH/ios/GoogleService-Info.plist" ]; then
  if [ ! -f "ios/GoogleService-Info.plist" ]; then
    echo "📋 Copiando GoogleService-Info.plist..."
    mkdir -p "ios"
    cp "$ROOT_WORKTREE_PATH/ios/GoogleService-Info.plist" "ios/GoogleService-Info.plist"
    echo "   ✓ Arquivo copiado com sucesso"
  else
    echo "✓ GoogleService-Info.plist já existe no worktree"
  fi
else
  echo "⚠️  GoogleService-Info.plist não encontrado no projeto original"
fi

# Copiar google-services.json se não existir no worktree (para Android)
if [ -f "$ROOT_WORKTREE_PATH/android/app/google-services.json" ]; then
  if [ ! -f "android/app/google-services.json" ]; then
    echo "📋 Copiando google-services.json..."
    mkdir -p "android/app"
    cp "$ROOT_WORKTREE_PATH/android/app/google-services.json" "android/app/google-services.json"
    echo "   ✓ Arquivo copiado com sucesso"
  else
    echo "✓ google-services.json já existe no worktree"
  fi
else
  echo "ℹ️  google-services.json não encontrado (pode não ser necessário)"
fi

echo ""
echo "=========================================="
echo "  ✅ Setup do worktree concluído!"
echo "=========================================="

