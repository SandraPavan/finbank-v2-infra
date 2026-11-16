#!/usr/bin/env bash
# OPERAÇÃO DESTRUTIVA: remove containers, rede e o volume de dados de UM projeto Compose do FinBank V2.
# Exige a flag explícita --confirm-destroy-finbank-v2-data. Só aceita projetos finbank-v2 ou finbank-v2-<sufixo>.
# Uso: scripts/reset-data.sh --confirm-destroy-finbank-v2-data [--project NOME]
set -euo pipefail
cd "$(dirname "$0")/.."

confirm_flag="--confirm-destroy-finbank-v2-data"
confirmed=false
project="${COMPOSE_PROJECT_NAME:-finbank-v2}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    "$confirm_flag") confirmed=true; shift ;;
    --project)
      [[ $# -ge 2 ]] || { echo "erro: --project exige um nome" >&2; exit 2; }
      project="$2"; shift 2 ;;
    *) echo "erro: argumento desconhecido: $1" >&2; exit 2 ;;
  esac
done

if [[ ! "$project" =~ ^finbank-v2(-[a-z0-9]+)*$ ]]; then
  echo "erro: projeto '$project' recusado; somente finbank-v2 ou finbank-v2-<sufixo>" >&2
  exit 2
fi

echo "Projeto: $project"
echo "Serão removidos os containers e a rede do projeto e o volume ${project}_postgres-data."

if [[ "$confirmed" != true ]]; then
  echo "Nada foi removido. Para confirmar, execute novamente com $confirm_flag" >&2
  exit 1
fi

docker compose -p "$project" down --volumes --remove-orphans
echo "Dados do projeto '$project' removidos."
