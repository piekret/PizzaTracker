#!/usr/bin/env bash
set -euo pipefail

if [[ ! -f .env ]]; then
  printf 'Missing .env in the project root.\n' >&2
  exit 1
fi

set -a
# shellcheck disable=SC1091
source ./.env
set +a

if [[ -z "${SUPABASE_URL:-}" || -z "${SUPABASE_ANON_KEY:-}" ]]; then
  printf 'SUPABASE_URL and SUPABASE_ANON_KEY must be set in .env.\n' >&2
  exit 1
fi

cat > .env.client <<EOF
# Client-safe Flutter config only.
# This file is bundled into the app for local \`flutter run\`, so never add server secrets here.

SUPABASE_URL=$SUPABASE_URL
SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY
EOF

printf 'Updated .env.client with client-safe Supabase values.\n'
