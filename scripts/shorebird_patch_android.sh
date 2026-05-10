#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

SUPABASE_URL="${SUPABASE_URL:-https://kmeuuwqcngxhcfeevzsy.supabase.co}"
RELEASE_VERSION="${RELEASE_VERSION:-latest}"

SHOREBIRD_BIN="${SHOREBIRD_BIN:-shorebird}"
if ! command -v "$SHOREBIRD_BIN" >/dev/null 2>&1; then
  if [[ -x "$HOME/.shorebird/bin/shorebird" ]]; then
    SHOREBIRD_BIN="$HOME/.shorebird/bin/shorebird"
  fi
fi

if ! command -v "$SHOREBIRD_BIN" >/dev/null 2>&1; then
  cat >&2 <<'EOF'
Missing Shorebird CLI.

Install and sign in first:

  curl --proto '=https' --tlsv1.2 https://raw.githubusercontent.com/shorebirdtech/install/main/install.sh -sSf | bash
  shorebird login
EOF
  exit 1
fi

if [[ ! -f shorebird.yaml ]]; then
  cat >&2 <<'EOF'
Missing shorebird.yaml.

Run shorebird init first, then create a base release with scripts/shorebird_release_android.sh.
EOF
  exit 1
fi

if [[ -z "${SUPABASE_ANON_KEY:-}" ]]; then
  cat >&2 <<'EOF'
Missing SUPABASE_ANON_KEY.

Publish a Shorebird patch with:

  SUPABASE_ANON_KEY=sb_publishable_... scripts/shorebird_patch_android.sh

Use RELEASE_VERSION=1.0.0+1 if you need to patch a specific installed version.
EOF
  exit 1
fi

"$SHOREBIRD_BIN" patch android --release-version "$RELEASE_VERSION" -- \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY"

echo
echo "Published Shorebird patch for release version: $RELEASE_VERSION"
echo "Users receive the patch after app restart."
