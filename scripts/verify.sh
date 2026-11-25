#!/usr/bin/env bash
# Verificações estáticas do finbank-v2-infra (DEV-007). Não sobe containers nem toca volumes.
# Requer Docker (Compose e imagem do shellcheck).
set -euo pipefail
cd "$(dirname "$0")/.."

SHELLCHECK_IMAGE="koalaman/shellcheck:v0.11.0"

echo "1/4 compose config com .env.example (deve passar)"
docker compose --env-file .env.example config --quiet

# O modo HTTP local só é aceitável com a API publicada apenas em loopback (DEV-017).
resolved="$(docker compose --env-file .env.example config --format json)"
if ! grep -q '"COOKIE_TRANSPORT": "local-http"' <<<"$resolved"; then
  echo "erro: a API do Compose local deve declarar COOKIE_TRANSPORT=local-http" >&2
  exit 1
fi
if [ "$(grep -c '"published":' <<<"$resolved")" != "$(grep -c '"host_ip": "127.0.0.1"' <<<"$resolved")" ]; then
  echo "erro: toda porta publicada deve estar ligada a 127.0.0.1" >&2
  exit 1
fi

# A linha de comando do operador só roda sob demanda (DEV-019).
if docker compose --env-file .env.example config --services | grep -qx admin; then
  echo "erro: o serviço admin não pode subir por padrão" >&2
  exit 1
fi
with_admin="$(docker compose --env-file .env.example --profile admin config --format json)"
if [ "$(grep -c '"published":' <<<"$with_admin")" != "$(grep -c '"published":' <<<"$resolved")" ]; then
  echo "erro: o serviço admin não pode publicar portas" >&2
  exit 1
fi

echo "2/4 compose config sem segredos (deve falhar)"
if env -u POSTGRES_USER -u POSTGRES_PASSWORD -u POSTGRES_DB -u RUNTIME_DB_USER -u RUNTIME_DB_PASSWORD \
  docker compose --env-file /dev/null config --quiet >/dev/null 2>&1; then
  echo "erro: compose config aceitou configuração sem segredos obrigatórios" >&2
  exit 1
fi
# Sem as credenciais do usuário de execução (DEV-012) também deve falhar.
runtime_missing="$(mktemp)"
trap 'rm -f "$runtime_missing"' EXIT
grep -v '^RUNTIME_DB_' .env.example >"$runtime_missing"
if env -u RUNTIME_DB_USER -u RUNTIME_DB_PASSWORD \
  docker compose --env-file "$runtime_missing" config --quiet >/dev/null 2>&1; then
  echo "erro: compose config aceitou configuração sem o usuário de execução" >&2
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
