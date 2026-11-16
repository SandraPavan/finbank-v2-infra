#!/usr/bin/env bash
# Para o ambiente FinBank V2 preservando os dados (nunca remove volumes).
set -euo pipefail
cd "$(dirname "$0")/.."

for arg in "$@"; do
  case "$arg" in
    -v|--volumes|--volumes=*)
      echo "erro: down.sh preserva dados; para remover dados use scripts/reset-data.sh" >&2
      exit 2 ;;
  esac
done

exec docker compose down "$@"
