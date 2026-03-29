# CV repository (v1)

Monorepo with a **Go** API and worker, **PostgreSQL** metadata, **filesystem** PDF storage, **Apache Tika** text extraction, **Meilisearch** keyword search, and a **Next.js** (TypeScript) UI.

## Prerequisites

- Go 1.22+
- Node.js 20+ (for the web app)
- Docker and Docker Compose (for Postgres, Meilisearch, Tika)
- Optional: [Air](https://github.com/air-verse/air) for auto-rebuild/restart of the Go API and worker (`go install github.com/air-verse/air@latest`)

## Quick start

1. **Start infrastructure**

   ```bash
   docker compose up -d
   ```

2. **Configure**

   Copy [config.example.yaml](config.example.yaml) to `config.yaml` and edit values (database URL, storage path, Meilisearch, Tika). The file is gitignored. You can point elsewhere with `CONFIG_PATH` or `-config`:

   ```bash
   cp config.example.yaml config.yaml
   ```

   For the web app:

   ```bash
   cp web/.env.example web/.env.local
   ```

3. **Run the Go backend** (from repo root; reads `config.yaml` by default)

   With **Air** (rebuilds on `.go` / `go.mod` / `go.sum` changes):

   ```bash
   air                    # API — uses [.air.toml](.air.toml)
   air -c .air.worker.toml   # worker — second terminal
   ```

   Without Air:

   ```bash
   go run ./cmd/api
   go run ./cmd/worker
   ```

   Binaries are written to `tmp/` when using Air (gitignored).

5. **Run the web UI**

   ```bash
   cd web && npm run dev
   ```

   Open [http://localhost:3000](http://localhost:3000). The UI calls the Go API through Next.js Route Handlers using `API_URL` (default `http://localhost:8080`). Saving files under `web/` triggers **Fast Refresh** in the browser.

   **Web hot reload inside Docker** (bind-mounts `./web`, webpack dev server + polling so saves are picked up reliably):

   ```bash
   cd web && npm ci   # once, so node_modules exists on the host
   docker compose stop web   # if the production web image is already using :3000
   docker compose -f docker-compose.yml -f docker-compose.dev.yml up web
   ```

## Services (Docker Compose)

| Service      | Port  | Purpose              |
|-------------|-------|----------------------|
| Postgres    | 5433→5432 (host→container) | CV metadata |
| Meilisearch | 7700  | Keyword search index |
| Tika        | 9998  | PDF text extraction |

Default DB URL: `postgres://cvrepo:cvrepo@localhost:5433/cvrepo?sslmode=disable` (host port **5433** so it does not fight another Postgres on **5432**). To use 5432 instead, change the `ports` mapping in `docker-compose.yml` and your `database_url`.  
Meilisearch master key (dev): `dev_master_key` (see `.env.example`)

## API (Go)

- `GET /healthz`
- `POST /v1/cvs` — multipart form: `file` (PDF), optional `title`
- `GET /v1/cvs?limit=&offset=`
- `GET /v1/cvs/{id}`
- `DELETE /v1/cvs/{id}`
- `GET /v1/search?q=&limit=`

## Backups

- Dump Postgres as usual.
- Copy the directory at `CV_STORAGE_ROOT`; paths in the database are relative to that root.

## Phase 2 (not implemented here)

- Semantic search (e.g. Milvus / Pinecone + embeddings).
- Docling or OCR for difficult PDFs.
- Swap Meilisearch for Elasticsearch behind the same indexing contract.
- Move storage from disk to S3-compatible object storage if you need multiple API instances without a shared filesystem.

## License

MIT (or your choice; no license file is included by default).
