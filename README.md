# CV repository (v1)

Monorepo with a **Go** API and worker, **PostgreSQL** metadata, **filesystem** PDF storage, **Apache Tika** text extraction, **Meilisearch** keyword search, a **Groq** AI layer (profile extraction + ranking + one-pagers + chat), a **Next.js** (TypeScript) web UI, and a **Flutter** exec feed app.

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

   `npm run dev` starts the Go API and worker automatically when they are not already running (via `scripts/ensure-backend.sh`). Open [http://localhost:3000](http://localhost:3000). The UI calls the Go API through Next.js Route Handlers using `API_URL` (default `http://localhost:8080`). Saving files under `web/` triggers **Fast Refresh** in the browser.

   To start everything (backend + web) in one command from the repo root:

   ```bash
   ./scripts/run-all.sh
   ```

   If the API keeps dying or ports are stuck, reset the local stack:

   ```bash
   bash scripts/stop-dev.sh
   cd web && npm run dev
   ```

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
- `POST /v1/jobs` — create reusable job definition (title + JD)
- `GET /v1/jobs` — list job definitions
- `GET /v1/jobs/{id}`
- `PUT /v1/jobs/{id}` — update title and job description
- `DELETE /v1/jobs/{id}`
- `POST /v1/jobs/{id}/rank`
- `GET /v1/jobs/{id}/rank`
- `GET /v1/jobs/{id}/feed?limit=&offset=`
- `POST /v1/jobs/improve` — AI JD improve (no persist)
- `POST /v1/campaigns` — create hiring campaign (role + metadata)
- `GET /v1/campaigns?status=&client=&tag=` — list campaigns
- `GET /v1/campaigns/{id}`
- `PUT /v1/campaigns/{id}` — deactivate (status change only)
- `DELETE /v1/campaigns/{id}` — not allowed (deactivate instead)
- `GET /v1/campaigns/{id}/stats` — ranked/review funnel analytics
- `POST /v1/campaigns/{id}/rank`
- `GET /v1/campaigns/{id}/rank`
- `GET /v1/campaigns/{id}/feed?limit=&offset=`
- `POST /v1/campaigns/improve` — AI JD improve (no persist)
- `POST /v1/cvs/{id}/reactions`
- `POST /v1/cvs/{id}/comments`
- `POST /v1/chat`
- `GET /v1/stats`

## AI configuration

Add Groq settings in `config.yaml` (or use env for key):

```yaml
groq_api_key: ""
groq_model: "llama-3.3-70b-versatile"
groq_base_url: "https://api.groq.com/openai/v1"
```

You can also set `GROQ_API_KEY` in your shell environment.

## Web admin UI

The web app includes separate admin pages:

- **Job management** at `/jobs` — reusable role definitions (title + JD). Create, edit, delete, and rank CVs against a job description.
- **Campaign management** at `/campaigns` — operational hiring campaigns with lifecycle status, client metadata, analytics, ranking, and ranked feed output.

## Flutter exec app

The Flutter app lives in [`mobile/`](mobile/README.md). It provides:

- swipe-like candidate feed reactions (shortlist/pass/star),
- campaign management with lifecycle, metadata, and analytics,
- chat over CVs with citations,
- leaderboard and streak stats.

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
