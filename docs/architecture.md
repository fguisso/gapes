# Architecture

```
   internet :443 ──► Caddy (TLS) ──► gapes-server :8080 ──► SQLite + disk
                                       HTTP-only, non-root
```

| Layer       | Choice                                |
|-------------|---------------------------------------|
| Server      | Rust + axum + tokio + sqlx            |
| HTML render | askama (Jinja-style, compile-checked) |
| UI          | Alpine.js, no build step              |
| Storage     | SQLite + local disk (Phase 1)         |
| Auth        | Device flow + scoped HMAC tokens + step-up |
| TLS         | External proxy (Caddy default), **mandatory in prod** |

Both storage layers sit behind traits (`Storage`, `Repository`, `AuthStore`) so a future Phase 5 can swap SQLite for Postgres and disk for S3 without touching business logic.

External TLS is mandatory because `gapes-server` deliberately doesn't embed it. The binary stays small and runs as a non-root user. See [`adr/0005-tls-termination.md`](../.claude/project-docs/adr/0005-tls-termination.md).

## Repo layout

```
crates/
├── gapes-core/         business logic, no I/O           (AGPL-3.0)
├── gapes-adapters/     SQLite + disk + crypto + config  (AGPL-3.0)
├── gapes-server/       axum binary `gapes-server`       (AGPL-3.0)
├── gapes-cli/          CLI binary `gapes`               (AGPL-3.0)
└── gapes-sdk/          HTTP client library              (Apache-2.0)
ui/
├── templates/          (askama, in-binary)
├── public/             alpine, admin assets
└── widget/             comments widget (vanilla JS)
docker/                 Dockerfile + compose + Caddyfile
packaging/              systemd unit + install.sh
```
