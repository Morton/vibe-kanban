# Repository Guidelines

## Project Structure & Module Organization
- `crates/`: Rust workspace crates — `server` (API + bins), `db` (SQLx models/migrations), `executors`, `services`, `utils`, `git` (Git operations), `api-types` (shared API types for local + remote), `review` (PR review tool), `deployment`, `local-deployment`, `remote`.
- `packages/local-web/`: Local React + TypeScript app entrypoint (Vite, Tailwind). Shell source in `packages/local-web/src`.
- `packages/remote-web/`: Remote deployment frontend entrypoint.
- `packages/web-core/`: Shared React + TypeScript frontend library used by local + remote web (`packages/web-core/src`).
- `shared/`: Generated TypeScript types (`shared/types.ts`, `shared/remote-types.ts`) and agent tool schemas (`shared/schemas/`). Do not edit generated files directly.
- `assets/`, `dev_assets_seed/`, `dev_assets/`: Packaged and local dev assets.
- `npx-cli/`: Files published to the npm CLI package.
- `scripts/`: Dev helpers (ports, DB preparation).
- `docs/`: Documentation files.

### Crate-specific guides
- [`crates/remote/AGENTS.md`](crates/remote/AGENTS.md) — Remote server architecture, ElectricSQL integration, mutation patterns, environment variables.
- [`docs/AGENTS.md`](docs/AGENTS.md) — Mintlify documentation writing guidelines and component reference.
- [`packages/local-web/AGENTS.md`](packages/local-web/AGENTS.md) — Web app design system styling guidelines.

## Managing Shared Types Between Rust and TypeScript

ts-rs allows you to derive TypeScript types from Rust structs/enums. By annotating your Rust types with #[derive(TS)] and related macros, ts-rs will generate .ts declaration files for those types.
When making changes to the types, you can regenerate them using `pnpm run generate-types`
Do not manually edit shared/types.ts, instead edit crates/server/src/bin/generate_types.rs

For remote/cloud types, regenerate using `pnpm run remote:generate-types`
Do not manually edit shared/remote-types.ts, instead edit crates/remote/src/bin/remote-generate-types.rs (see crates/remote/AGENTS.md for details).

## Full Local Dev Setup (with auth + all features)

Running `pnpm run dev` alone only supports workspace creation — login and the kanban board require the remote backend. Follow these steps once to get everything working.

### Prerequisites
- Docker Desktop running
- Rust via **rustup** (not Homebrew) with the `nightly-2025-12-04` toolchain — `rustup toolchain install nightly-2025-12-04`
- `cargo-watch` — `cargo install cargo-watch`
- A GitHub OAuth App with callback URL `http://localhost:3000/v1/oauth/github/callback` ([create one here](https://github.com/settings/developers))

### One-time setup

1. Create `crates/remote/.env.remote`:
   ```env
   VIBEKANBAN_REMOTE_JWT_SECRET=<output of: openssl rand -base64 48>
   ELECTRIC_ROLE_PASSWORD=localdevpassword
   GITHUB_OAUTH_CLIENT_ID=<your client id>
   GITHUB_OAUTH_CLIENT_SECRET=<your client secret>
   VITE_RELAY_API_BASE_URL=http://localhost:8082
   REMOTE_DB_PORT=5439
   ```
   > Use `REMOTE_DB_PORT=5439` (or any free port) if 5433 is taken by another local Postgres container.

2. Build and start the remote stack (Docker):
   ```bash
   cd crates/remote
   docker compose --env-file .env.remote -f docker-compose.yml up --build
   ```
   Wait for `remote-server-1 | INFO remote: Server listening on 0.0.0.0:8081`.
   Subsequent starts are fast (images already built): use `up -d` instead of `up --build`.

### Running the dev server

Always start the dev server with `VK_SHARED_API_BASE` pointing at the local remote:

```bash
VK_SHARED_API_BASE=http://localhost:3000 pnpm run dev
```

- Frontend: http://localhost:3001
- Local backend: port auto-assigned (3002 or 3003), written to `/tmp/vibe-kanban/vibe-kanban.port`
- Remote server: http://localhost:3000
- Relay server: http://localhost:8082

### Port conflicts
If port 5433 is already in use by another Postgres container, set `REMOTE_DB_PORT` in `.env.remote` to a free port (e.g. 5439). The `docker-compose.yml` respects this variable.

### Note on first build
The initial Rust compilation takes ~25 minutes. Subsequent incremental builds are fast. The build cache lives in `target/` — if that directory is deleted a full rebuild is required.

## Build, Test, and Development Commands
- Install: `pnpm i`
- Run dev (web app + backend with ports auto-assigned): `pnpm run dev`
- Backend (watch): `pnpm run backend:dev:watch`
- Web app (dev): `pnpm run local-web:dev`
- Type checks: `pnpm run check` (frontend + all backend Rust workspaces) and `pnpm run backend:check` (all backend Rust workspaces, including `crates/remote`)
- Rust tests: `cargo test --workspace`
- Generate TS types from Rust: `pnpm run generate-types` (or `generate-types:check` in CI)
- Prepare SQLx (offline): `pnpm run prepare-db`
- Prepare SQLx (remote package, postgres): `pnpm run remote:prepare-db`
- Local NPX build: `pnpm run build:npx` then `pnpm pack` in `npx-cli/`
- Format code: `pnpm run format` (runs `cargo fmt` for all backend Rust workspaces + web-core/web Prettier)
- Lint: `pnpm run lint` (runs web/ui ESLint + `cargo clippy` for all backend Rust workspaces)

## Before Completing a Task
- Run `pnpm run format` to format all Rust workspaces and web code.

## Coding Style & Naming Conventions
- Rust: `rustfmt` enforced (`rustfmt.toml`); group imports by crate; snake_case modules, PascalCase types.
- TypeScript/React: ESLint + Prettier (2 spaces, single quotes, 80 cols). PascalCase components, camelCase vars/functions, kebab-case file names where practical.
- Keep functions small, add `Debug`/`Serialize`/`Deserialize` where useful.

## Testing Guidelines
- Rust: prefer unit tests alongside code (`#[cfg(test)]`), run `cargo test --workspace`. Add tests for new logic and edge cases.
- Web app: ensure `pnpm run check` and `pnpm run lint` pass. If adding runtime logic, include lightweight tests (e.g., Vitest) in the same directory.

## Security & Config Tips
- Use `.env` for local overrides; never commit secrets. Key envs: `FRONTEND_PORT`, `BACKEND_PORT`, `HOST` 
- Dev ports and assets are managed by `scripts/setup-dev-environment.js`.

