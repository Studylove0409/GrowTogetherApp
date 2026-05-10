#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

SUPABASE_URL="${SUPABASE_URL:-https://kmeuuwqcngxhcfeevzsy.supabase.co}"

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
  shorebird init --display-name "一起进步呀"

Then run this script again.
EOF
  exit 1
fi

if [[ ! -f shorebird.yaml ]]; then
  cat >&2 <<'EOF'
Missing shorebird.yaml.

Initialize this app first:

  shorebird login
  shorebird init --display-name "一起进步呀"

shorebird.yaml contains the app_id used by installed apps to find patches, so it must be checked into git.
EOF
  exit 1
fi

if [[ -z "${SUPABASE_ANON_KEY:-}" ]]; then
  cat >&2 <<'EOF'
Missing SUPABASE_ANON_KEY.

Create the Shorebird Android release with:

  SUPABASE_ANON_KEY=sb_publishable_... scripts/shorebird_release_android.sh

Without this dart-define the app falls back to MockStore and ships static data.
EOF
  exit 1
fi

"$SHOREBIRD_BIN" release android --artifact=apk -- \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY"

echo
echo "Built Shorebird release APK:"
echo "$ROOT_DIR/build/app/outputs/flutter-apk/app-release.apk"
echo
echo "Send this APK once. Future Dart/UI updates can be shipped with scripts/shorebird_patch_android.sh."
