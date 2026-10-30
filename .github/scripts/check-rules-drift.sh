#!/usr/bin/env bash
# Compares the rules published in production with the files in the repo.
# Fails (exit 1) when Firestore or Storage rules differ.
#
# Needs: gcloud authenticated (roles/firebaserules.viewer or admin), curl, jq.
# Usage: .github/scripts/check-rules-drift.sh [project_id]
# Locally, with user credentials, the API needs a quota project:
#   RULES_QUOTA_PROJECT=praticos .github/scripts/check-rules-drift.sh
set -euo pipefail

PROJECT="${1:-praticos}"
API="https://firebaserules.googleapis.com/v1"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TOKEN="$(gcloud auth print-access-token)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

api_get() {
  local headers=(-H "Authorization: Bearer $TOKEN")
  if [ -n "${RULES_QUOTA_PROJECT:-}" ]; then
    headers+=(-H "x-goog-user-project: $RULES_QUOTA_PROJECT")
  fi
  if ! curl -sS --fail-with-body "${headers[@]}" -o "$WORK/response.json" "$API/$1"; then
    echo "::error::firebaserules API falhou em $1" >&2
    cat "$WORK/response.json" >&2
    exit 2
  fi
  cat "$WORK/response.json"
}

drift=0

# Compares the ruleset behind release $1 with local file $2.
compare_release() {
  local release="$1" local_file="$2" label="$3"
  local ruleset deployed="$WORK/deployed.rules"

  api_get "projects/$PROJECT/releases/$release" > "$WORK/release.json"
  ruleset="$(jq -r '.rulesetName' "$WORK/release.json")"
  api_get "$ruleset" > "$WORK/ruleset.json"
  jq -j '.source.files[0].content' "$WORK/ruleset.json" > "$deployed"

  if diff -u --label "produção ($ruleset)" --label "$local_file" \
      "$deployed" "$ROOT/$local_file"; then
    echo "OK: $label igual ao repositório ($ruleset)"
  else
    echo "::error title=$label divergente::As regras publicadas em $PROJECT ($ruleset) diferem de $local_file. Rode o workflow 'Deploy Firestore/Storage Rules' ou investigue quem publicou por fora."
    drift=1
  fi
}

compare_release "cloud.firestore" "firebase/firestore.rules" "Firestore rules"

# Storage releases are named firebase.storage/<bucket>; check every bucket found.
api_get "projects/$PROJECT/releases?pageSize=100" > "$WORK/releases.json"
storage_releases="$(jq -r '.releases[]?.name | select(contains("/releases/firebase.storage/")) | sub("^projects/[^/]+/releases/"; "")' "$WORK/releases.json")"
if [ -z "$storage_releases" ]; then
  echo "::warning::Nenhum release de Storage encontrado em $PROJECT"
fi
for release in $storage_releases; do
  compare_release "$release" "firebase/storage.rules" "Storage rules ($release)"
done

exit "$drift"
