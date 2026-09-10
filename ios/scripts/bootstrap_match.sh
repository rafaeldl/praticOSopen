#!/usr/bin/env bash
#
# Bootstrap do fastlane match para a assinatura iOS do PraticOS.
#
# Rodar UMA vez, localmente, por uma pessoa com acesso a conta Apple:
#
#   ios/scripts/bootstrap_match.sh
#
# O que faz:
#   1. Pede a passphrase do match (sem ecoar na tela).
#   2. Roda `fastlane match appstore`: cria o certificado de distribuicao e o
#      provisioning profile, criptografa e envia para o repo de certificados.
#      Vai pedir login da Apple (Apple ID + 2FA).
#   3. Gera uma deploy key SSH SOMENTE LEITURA para o CI, cadastra a chave
#      publica no repo de certificados e grava a privada como secret.
#   4. Grava MATCH_PASSWORD como secret.
#
# Nenhum valor secreto e impresso, gravado em disco fora de um diretorio
# temporario, ou passado como argumento de linha de comando.
#
# Ver docs/IOS_CODE_SIGNING.md

set -euo pipefail

APP_REPO="rafaeldl/praticOSopen"
CERTS_REPO="rafaeldl/praticos-certificates"
IOS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

die() { printf '\n❌ %s\n' "$*" >&2; exit 1; }
step() { printf '\n▶ %s\n' "$*"; }
confirm() {
  local answer
  read -r -p "$1 [s/N] " answer
  [[ "$answer" =~ ^[sSyY]$ ]]
}

# ---------------------------------------------------------------------------
# 1. Pre-requisitos
# ---------------------------------------------------------------------------
step "Verificando pre-requisitos"

command -v gh >/dev/null || die "gh (GitHub CLI) nao encontrado."
gh auth status >/dev/null 2>&1 || die "gh nao autenticado. Rode: gh auth login"
command -v bundle >/dev/null || die "bundler nao encontrado. Rode: gem install bundler"
command -v ssh-keygen >/dev/null || die "ssh-keygen nao encontrado."

# O push do match para o repo de certificados usa a SUA chave SSH.
ssh_out="$(ssh -T -o BatchMode=yes -o StrictHostKeyChecking=accept-new git@github.com 2>&1 || true)"
[[ "$ssh_out" == *"successfully authenticated"* ]] \
  || die "Sua chave SSH nao autentica no GitHub. Teste com: ssh -T git@github.com"

gh repo view "$CERTS_REPO" >/dev/null 2>&1 \
  || die "Sem acesso ao repo $CERTS_REPO."

if gh secret list --repo "$APP_REPO" 2>/dev/null | grep -qE '^MATCH_(PASSWORD|GIT_PRIVATE_KEY)\b'; then
  echo "⚠️  Ja existem secrets MATCH_* em $APP_REPO."
  confirm "Sobrescrever?" || die "Cancelado."
fi

if gh api "repos/$CERTS_REPO/contents" >/dev/null 2>&1; then
  echo "⚠️  O repo $CERTS_REPO NAO esta vazio: o match vai reutilizar o que ja existe,"
  echo "    e a passphrase precisa ser a MESMA usada antes."
  confirm "Continuar?" || die "Cancelado."
fi

# ---------------------------------------------------------------------------
# 2. Passphrase
# ---------------------------------------------------------------------------
step "Passphrase do match"
echo "Ela criptografa os certificados. Guarde num gerenciador de senhas:"
echo "se for perdida, e preciso revogar o certificado e recomecar."

read -r -s -p "Passphrase: " MATCH_PASSWORD; echo
read -r -s -p "Confirme:    " passphrase_confirm; echo
[[ -n "$MATCH_PASSWORD" ]] || die "Passphrase vazia."
[[ "$MATCH_PASSWORD" == "$passphrase_confirm" ]] || die "As passphrases nao conferem."
unset passphrase_confirm
if (( ${#MATCH_PASSWORD} < 16 )); then
  confirm "A passphrase tem menos de 16 caracteres. Usar mesmo assim?" || die "Cancelado."
fi
export MATCH_PASSWORD

# ---------------------------------------------------------------------------
# 3. Certificado + profile (criptografados no repo de certificados)
# ---------------------------------------------------------------------------
step "Gerando certificado e provisioning profile (vai pedir login da Apple)"

# `env -u CI` garante que o Matchfile nao entre em readonly nesta execucao.
(
  cd "$IOS_DIR"
  env -u CI LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 bundle exec fastlane match appstore
) || die "fastlane match falhou. Nenhum secret foi gravado."

# ---------------------------------------------------------------------------
# 4. Deploy key somente leitura para o CI
# ---------------------------------------------------------------------------
step "Criando deploy key somente leitura para o CI"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

key_title="CI fastlane match (read-only) $(date +%Y-%m-%d)"
ssh-keygen -q -t ed25519 -N "" -C "praticos-ci-match" -f "$tmp_dir/deploy_key"

# Sem --allow-write: a chave so consegue ler o repo de certificados.
gh repo deploy-key add "$tmp_dir/deploy_key.pub" --repo "$CERTS_REPO" --title "$key_title"
gh secret set MATCH_GIT_PRIVATE_KEY --repo "$APP_REPO" < "$tmp_dir/deploy_key"

# ---------------------------------------------------------------------------
# 5. Passphrase como secret (printf e builtin: nao aparece na lista de processos)
# ---------------------------------------------------------------------------
step "Gravando MATCH_PASSWORD"
printf '%s' "$MATCH_PASSWORD" | gh secret set MATCH_PASSWORD --repo "$APP_REPO"
unset MATCH_PASSWORD

printf '\n✅ Bootstrap concluido.\n'
echo "   - Certificado e profile criptografados em $CERTS_REPO"
echo "   - Deploy key somente leitura: \"$key_title\""
echo "   - Secrets MATCH_PASSWORD e MATCH_GIT_PRIVATE_KEY gravados em $APP_REPO"
echo
echo "Proximo passo: disparar o Release iOS (ver docs/IOS_CODE_SIGNING.md)."
