#!/usr/bin/env bash
set -euo pipefail

# Provide these through a private shell or CI secret store; never use set -x.
: "${MUSKAAN_STORE_FILE:?Provide the upload keystore path}"
: "${MUSKAAN_STORE_PASSWORD:?Provide the upload keystore password}"
: "${MUSKAAN_KEY_ALIAS:?Provide the upload key alias}"
: "${MUSKAAN_KEY_PASSWORD:?Provide the upload key password}"
: "${ORG_GRADLE_PROJECT_admobAppId:?Provide the production AdMob app ID}"
: "${ADMOB_INTERSTITIAL_ID:?Provide the production interstitial ID}"
: "${ADMOB_REWARDED_ID:?Provide the production rewarded ID}"
: "${MUSKAAN_SYMBOL_DIR:?Provide a private per-version symbol directory outside the repository}"

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
symbol_dir=$(realpath -m "$MUSKAAN_SYMBOL_DIR")
case "$symbol_dir" in
  "$repo_root"|"$repo_root"/*)
    printf '%s\n' 'Symbol directory must be outside the repository.' >&2
    exit 1
    ;;
esac
umask 077
mkdir -p "$symbol_dir"
cd "$repo_root"
"${FLUTTER_BIN:-flutter}" build appbundle --release --obfuscate \
  --split-debug-info="$symbol_dir" \
  --dart-define="ADMOB_INTERSTITIAL_ID=$ADMOB_INTERSTITIAL_ID" \
  --dart-define="ADMOB_REWARDED_ID=$ADMOB_REWARDED_ID"
