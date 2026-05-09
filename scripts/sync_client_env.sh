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

mkdir -p assets/env

for target in .env.client assets/env/client.env; do
  cat > "$target" <<EOF
# Client-safe Flutter config only.
# assets/env/client.env is bundled for local \`flutter run\`, so never add server secrets here.

SUPABASE_URL=$SUPABASE_URL
SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY
EOF
done

printf 'Updated .env.client and assets/env/client.env with client-safe Supabase values.\n'
