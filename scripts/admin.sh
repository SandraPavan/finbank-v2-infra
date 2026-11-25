#!/usr/bin/env bash
# Linha de comando do operador (DEV-019). Exige o ambiente no ar (docker compose up).
# A senha é digitada no terminal, sem eco, ou lida da entrada padrão; nunca é argumento nem variável.
# Uso: scripts/admin.sh [--project NOME] COMANDO [OPÇÕES]   (sem comando: mostra os comandos)
set -euo pipefail
cd "$(dirname "$0")/.."

project=()
if [[ "${1:-}" == "--project" ]]; then
  [[ $# -ge 2 ]] || { echo "erro: --project exige um nome" >&2; exit 2; }
  if [[ ! "$2" =~ ^finbank-v2(-[a-z0-9]+)*$ ]]; then
    echo "erro: projeto recusado; somente finbank-v2 ou finbank-v2-<sufixo>" >&2
    exit 2
  fi
  project=(-p "$2")
  shift 2
fi

# Sem terminal na entrada, o Compose não pode alocar um.
terminal=()
[[ -t 0 && -t 1 ]] || terminal=(-T)

compose=(docker compose ${project[@]+"${project[@]}"} --profile admin)
"${compose[@]}" build --quiet admin </dev/null
exec "${compose[@]}" run --rm --no-deps ${terminal[@]+"${terminal[@]}"} admin "$@"
