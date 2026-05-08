#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

SUPABASE_URL="${SUPABASE_URL:-https://kmeuuwqcngxhcfeevzsy.supabase.co}"

if [[ -z "${SUPABASE_ANON_KEY:-}" ]]; then
  cat >&2 <<'EOF'
Missing SUPABASE_ANON_KEY.

Build the Android release APK with:

  SUPABASE_ANON_KEY=sb_publishable_... scripts/build_release_android.sh

Without this dart-define the app falls back to MockStore and ships static data.
EOF
  exit 1
fi

flutter build apk --release \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY"

echo
echo "Built APK:"
echo "$ROOT_DIR/build/app/outputs/flutter-apk/app-release.apk"
