#!/usr/bin/env bash
# Verificações estáticas do finbank-v2-infra (DEV-007). Não sobe containers nem toca volumes.
# Requer Docker (Compose e imagem do shellcheck).
set -euo pipefail
cd "$(dirname "$0")/.."

SHELLCHECK_IMAGE="koalaman/shellcheck:v0.11.0"

echo "1/4 compose config com .env.example (deve passar)"
docker compose --env-file .env.example config --quiet

echo "2/4 compose config sem segredos (deve falhar)"
if env -u POSTGRES_USER -u POSTGRES_PASSWORD -u POSTGRES_DB \
  docker compose --env-file /dev/null config --quiet >/dev/null 2>&1; then
  echo "erro: compose config aceitou configuração sem segredos obrigatórios" >&2
  exit 1
fi

echo "3/4 sintaxe dos scripts (bash -n)"
for script in scripts/*.sh; do
  bash -n "$script"
done

echo "4/4 shellcheck ($SHELLCHECK_IMAGE)"
scripts_to_check=()
for script in scripts/*.sh; do
  scripts_to_check+=("$(basename "$script")")
done
docker run --rm -v "$PWD/scripts:/mnt:ro" -w /mnt "$SHELLCHECK_IMAGE" "${scripts_to_check[@]}"

echo "verificações do infra concluídas"
