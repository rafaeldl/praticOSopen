#!/usr/bin/env bash
#
# setup-worktree.sh
#
# Copia arquivos de configuracao e variaveis de ambiente do repo principal
# para um worktree recem-criado, permitindo rodar o app e testes.
#
# Uso:
#   ./scripts/setup-worktree.sh <caminho-do-worktree>
#
# Exemplo:
#   cd /Users/rafaeldl/Projetos/praticOSopen
#   ./scripts/setup-worktree.sh /Users/rafaeldl/Projetos/praticOSopen-worktrees/PRA-50
#

set -euo pipefail

# --- Configuracao ---

# Diretorio raiz do repo principal (de onde os arquivos serao copiados).
# Detecta automaticamente via git - o primeiro worktree listado e sempre o principal.
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
MAIN_REPO="$(cd "$SCRIPT_DIR" && git worktree list --porcelain | head -1 | sed 's/^worktree //')"

# Lista de arquivos ignorados pelo git que sao necessarios para build/run/test.
# Caminhos relativos ao root do projeto.
CONFIG_FILES=(
  # Android - Firebase
  "android/app/google-services.json"

  # Android - SDK paths (sera regenerado, mas ajuda a evitar erro inicial)
  "android/local.properties"

  # Android - Keystore de assinatura
  "android/app/rafsoft.keystore"

  # Android - Credenciais Play Store (Fastlane deploy)
  "android/fastlane/play_store_credentials.json"

  # iOS - Firebase
  "ios/GoogleService-Info.plist"

  # iOS - Fastlane env
  "ios/fastlane/.env"
)

# --- Validacao ---

if [ $# -lt 1 ]; then
  echo "Uso: $0 <caminho-do-worktree>"
  echo ""
  echo "Exemplo:"
  echo "  $0 /Users/rafaeldl/Projetos/praticOSopen-worktrees/PRA-50"
  exit 1
fi

WORKTREE_DIR="$(cd "$1" && pwd)"

if [ ! -d "$WORKTREE_DIR" ]; then
  echo "ERRO: Diretorio do worktree nao encontrado: $WORKTREE_DIR"
  exit 1
fi

if [ "$MAIN_REPO" = "$WORKTREE_DIR" ]; then
  echo "ERRO: O worktree nao pode ser o mesmo que o repo principal."
  exit 1
fi

# --- Copia ---

copied=0
skipped=0
missing=0

echo "Copiando arquivos de configuracao..."
echo "  De: $MAIN_REPO"
echo "  Para: $WORKTREE_DIR"
echo ""

for file in "${CONFIG_FILES[@]}"; do
  src="$MAIN_REPO/$file"
  dst="$WORKTREE_DIR/$file"

  if [ ! -f "$src" ]; then
    echo "  [AUSENTE]  $file (nao existe no repo principal)"
    missing=$((missing + 1))
    continue
  fi

  # Criar diretorio de destino se necessario
  dst_dir="$(dirname "$dst")"
  mkdir -p "$dst_dir"

  # Copiar preservando permissoes
  cp -p "$src" "$dst"
  echo "  [OK]       $file"
  copied=$((copied + 1))
done

echo ""
echo "Resumo: $copied copiado(s), $missing ausente(s)."

if [ "$missing" -gt 0 ]; then
  echo ""
  echo "AVISO: Alguns arquivos nao existem no repo principal."
  echo "       O app pode nao compilar corretamente sem eles."
fi

echo ""
echo "Worktree configurado com sucesso!"
echo "Proximo passo: cd $WORKTREE_DIR && flutter pub get"
