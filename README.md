# finbank-v2-infra

Ambiente local da fundação do FinBank V2 (DEV-004; papéis separados no banco na DEV-012): Docker Compose com PostgreSQL, migração, API e web. Este repositório é público. O ambiente completo precisa só dos repositórios públicos `finbank-v2-api` e `finbank-v2-web`. Não há infraestrutura de produção, worker ou observabilidade nesta fase.

## Convenção de checkout

Os repositórios ficam lado a lado na mesma pasta, cada um com seu próprio Git:

```
<pasta>/
├── finbank-v2-api/     # build da API e da migração (contexto ../finbank-v2-api)
├── finbank-v2-web/     # build do web (contexto ../finbank-v2-web)
└── finbank-v2-infra/   # este repositório: compose.yaml
```

```sh
mkdir finbank && cd finbank
git clone <remoto>/finbank-v2-api.git
git clone <remoto>/finbank-v2-web.git
git clone <remoto>/finbank-v2-infra.git
```

O `compose.yaml` referencia `../finbank-v2-api` e `../finbank-v2-web` explicitamente. Execute os comandos a partir de `finbank-v2-infra/`. A equipe usa o mesmo arranjo dentro do workspace interno.

## Requisitos

Docker Engine com Compose v2 (verificado com Docker 29.7.2 e Compose v5.5.1). O primeiro build baixa imagens e pacotes npm.

## Serviços

| Serviço | Origem | Função | Porta no host (padrão) |
|---|---|---|---|
| `postgres` | `postgres:18.6-alpine` | Banco com volume nomeado e healthcheck `pg_isready` | `127.0.0.1:15432` |
| `migrate` | `../finbank-v2-api`, estágio `migrate` | Executa `prisma migrate deploy` uma vez e termina | — |
| `api` | `../finbank-v2-api`, estágio `runtime` | NestJS (`node dist/main.js`), usuário sem root; sobe só depois do `migrate` terminar com sucesso; healthcheck pelo readiness | `127.0.0.1:13000` |
| `web` | `../finbank-v2-web` | Build Vite servido por `nginxinc/nginx-unprivileged:1.30.6-alpine`; healthcheck pelo `index` | `127.0.0.1:18080` |

- **Identidade:** projeto `finbank-v2`. Rede `finbank-v2_foundation`, volume `finbank-v2_postgres-data`, containers `finbank-v2-<serviço>-1`.
- **Portas:** todas ligadas a `127.0.0.1` e configuráveis no `.env`.
- **Volume:** no PostgreSQL 18, o volume é montado em `/var/lib/postgresql`, e os dados ficam em `/var/lib/postgresql/18/docker`.
- **Healthchecks (DEV-005):** os checks do Compose usam o mesmo contrato HTTP dos endpoints, e por isso `up --wait` só termina com a API realmente pronta.
  - `api`: `node dist/healthcheck.js` só é saudável com `GET /health/ready` → 200. O contrato está no README da API.
  - `web`: `wget` em `/`.
  - Parâmetros técnicos (não são SLO): interval 5 s, timeout 3 s, retries 3, start_period 10 s (API) e 5 s (web).
- **Banco cai depois da subida:** a API continua `running`, mas fica `unhealthy` (`/health/ready` → 503, `/health/live` → 200) e volta a `healthy` quando o banco retorna. O Compose não reinicia containers `unhealthy`; `restart: unless-stopped` age só quando o processo termina.

## Configuração (segredos fora do Git)

```sh
cp .env.example .env   # .env é ignorado pelo Git; troque os valores fictícios
```

- **Obrigatórias:** `POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_DB`, `RUNTIME_DB_USER` e `RUNTIME_DB_PASSWORD`. Se alguma faltar, `docker compose config` e `up` falham com a mensagem "defina … no .env".
- **Dois papéis no banco (DEV-012):** `POSTGRES_USER` é o dono do esquema e só o serviço `migrate` o usa. A API conecta com `RUNTIME_DB_USER`, um usuário sem posse de objetos e com privilégios mínimos (membro do papel `finbank_runtime`). A cada `up`, o `migrate` aplica as migrações e cria ou atualiza esse usuário com a senha do `.env` (idempotente; só o verificador SCRAM chega ao banco). `RUNTIME_DB_USER` deve ser diferente de `POSTGRES_USER`: 3 a 63 caracteres `a-z`, `0-9` ou `_`. `RUNTIME_DB_PASSWORD`: 16 a 128 caracteres.
- **Senhas e `DATABASE_URL`:** as URLs do dono (migração) e do usuário de execução (API) são montadas a partir dessas variáveis, apontando para o host interno `postgres`. Por isso, as senhas devem usar só letras, dígitos, `-`, `_` e `.`.
- **Ambiente existente:** quem já tem `.env` precisa acrescentar `RUNTIME_DB_USER` e `RUNTIME_DB_PASSWORD`; sem elas, `config` e `up` falham com a mensagem "defina … no .env". O volume de dados não é alterado: o próximo `up` cria o usuário de execução e concede os privilégios.
- **Segredos fora das imagens:** nenhum segredo entra nas imagens. As variáveis são fornecidas só quando os containers rodam.

## Comandos

```sh
docker compose config --quiet          # valida a configuração
docker compose up -d --build --wait    # constrói e sobe tudo
docker compose ps -a                   # estado (api/web "healthy"; migrate "Exited (0)")
curl http://127.0.0.1:13000/health/live    # API viva → {"status":"ok"}
curl http://127.0.0.1:13000/health/ready   # API pronta → {"status":"ok","checks":{"database":"up"}} (503 se o banco cair)
curl http://127.0.0.1:18080/           # web
docker compose logs -f api             # logs
scripts/down.sh                        # para e remove os containers, PRESERVANDO os dados
```

- **Dados preservados por padrão:** `scripts/down.sh` (ou `docker compose down`, sem `-v`) mantém o volume `finbank-v2_postgres-data`. O `down.sh` recusa `-v` e `--volumes`.
- **Migrações:** são reaplicadas a cada `up`, de forma idempotente.

## Verificação estática (DEV-007)

```sh
scripts/verify.sh   # compose config com .env.example (passa) e sem segredos (falha), bash -n e shellcheck (koalaman/shellcheck:v0.11.0 via Docker)
```

Não sobe containers nem toca volumes.

## Operação destrutiva (separada e explícita)

```sh
scripts/reset-data.sh                                        # só mostra o que seria apagado; não remove nada (exit 1)
scripts/reset-data.sh --confirm-destroy-finbank-v2-data      # APAGA os containers, a rede e o volume do projeto finbank-v2
scripts/reset-data.sh --confirm-destroy-finbank-v2-data --project finbank-v2-smoke   # outro projeto finbank-v2-*
```

- **Projetos aceitos:** o script só aceita `finbank-v2` ou `finbank-v2-<sufixo>`.
- **Autorização:** não execute o reset no ambiente persistente sem autorização explícita. Use `docker compose down -v` diretamente só em projetos descartáveis.

## Smoke em projeto descartável

Para validar sem tocar no ambiente persistente, use outro nome de projeto, outro arquivo de variáveis e outras portas:

```sh
docker compose -p finbank-v2-smoke --env-file /caminho/smoke.env up -d --build --wait
# ... verificações ...
COMPOSE_ENV_FILES=/caminho/smoke.env scripts/reset-data.sh --confirm-destroy-finbank-v2-data --project finbank-v2-smoke
```

As imagens construídas (`finbank-v2-<projeto>-api`, `-migrate` e `-web`) continuam no cache local. Remova-as com `docker image rm` se quiser liberar espaço.
