# FinBank V2 — repositório filho

@../CLAUDE.md

Este repositório é público. Os caminhos `../` abaixo (import, rules e histórias) só existem no workspace interno da equipe; num clone isolado, siga o README.md.

Este diretório possui Git independente. Documentação oficial, regras e skills estão na coordenação, um nível acima. Não criar cópias locais do PRD ou backlog.

Antes de trabalhar, ler `../.claude/rules/` e a história solicitada em `../_bmad-output/implementation-artifacts/stories/`. Para descoberta consistente das skills compartilhadas, iniciar Claude na raiz da coordenação. Se a sessão foi aberta aqui, reabrir na raiz ou invocar a skill lendo seu caminho explicitamente; não presumir descoberta de catálogo entre repositórios.

Comandos Git e testes do componente executam neste diretório. Project-root do BMAD continua sendo a pasta pai, nunca instalar outra cópia aqui. Estado: DEV-004 implementada (Compose do projeto `finbank-v2` com PostgreSQL, migração, API e web; builds a partir de `../finbank-v2-api` e `../finbank-v2-web`) e DEV-012 (API conecta com usuário de execução `RUNTIME_DB_USER`, provisionado pelo serviço `migrate`; o dono `POSTGRES_USER` só migra e atende a linha de comando do operador, serviço `admin` sob demanda por `scripts/admin.sh`, DEV-019). A web encaminha `/api/` à API (DEV-021). Nunca executar `down -v` nem `scripts/reset-data.sh --confirm-destroy-finbank-v2-data` no projeto persistente `finbank-v2` sem autorização explícita; smokes usam projeto descartável `finbank-v2-<sufixo>`. Nunca tocar recursos Docker do legado (`finbank_*`). Verificação estática: `scripts/verify.sh`. Detalhes no README.md.
