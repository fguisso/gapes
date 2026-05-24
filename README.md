# gapes

Self-hosted static site + SPA hosting, with built-in comments and analytics, served behind UUID URLs. Designed to run on a Raspberry Pi and scale to SaaS from the same codebase.

> Status: scaffold / Phase 1 in design. Not yet runnable.

## Stack

- **Server**: Rust + axum + tokio + sqlx (SQLite) — `crates/gapes-server`
- **CLI**: Rust + clap — `crates/gapes-cli`, ships as binary `gapes`
- **UI**: askama templates + Alpine.js, no build step
- **Storage**: disk + SQLite in Phase 1; pluggable to S3 + Postgres in Phase 5
- **TLS**: Caddy in front (separate process)

## Repo layout

```
crates/
├── gapes-core/         business logic, no I/O           (AGPL-3.0)
├── gapes-adapters/     storage / db / auth impls        (AGPL-3.0)
├── gapes-server/       axum binary                      (AGPL-3.0)
├── gapes-cli/          CLI binary `gapes`               (AGPL-3.0)
└── gapes-sdk/          API client library               (Apache-2.0)
ui/
├── templates/          askama templates
├── public/             alpine, css, fonts
└── widget/             comments widget (vanilla JS)
```

## License

- Server, core, adapters, and CLI: **AGPL-3.0-or-later** (see [LICENSE](LICENSE))
- SDK only: **Apache-2.0** (see [crates/gapes-sdk/LICENSE](crates/gapes-sdk/LICENSE)) — kept permissive so third-party tools and AI agents can embed the API client without copyleft obligations
- Contributions via DCO (`git commit -s`). No CLA.

## Dev setup

Requires [mise](https://mise.jdx.dev/). The project pins its Rust toolchain in `mise.toml`.

```sh
mise install                 # pin Rust toolchain
cargo install sqlx-cli cargo-watch   # one-time
mise run check               # type-check the workspace
mise run dev                 # run the server with auto-reload
```

## Production install (Pi / VPS)

One-shot install from a tagged release:

```sh
curl -fsSL https://raw.githubusercontent.com/fguisso/gapes/main/packaging/install.sh \
  | sudo bash
```

This downloads the binary for your CPU arch, verifies its SHA256, creates
the `gapes` system user, drops a default config at `/etc/gapes/pages.toml`,
and installs a hardened systemd unit. Pin a version with
`sudo GAPES_VERSION=v0.1.0 bash install.sh`.

Then put a TLS-terminating proxy in front of it (Caddy is the default and
easiest):

```sh
sudo apt install caddy        # or follow https://caddyserver.com/docs/install
sudo cp Caddyfile.example /etc/caddy/Caddyfile
sudo $EDITOR /etc/caddy/Caddyfile      # set your domain + Let's Encrypt email
sudo systemctl reload caddy
sudo $EDITOR /etc/gapes/pages.toml     # set public_url, trusted_proxy
sudo systemctl enable --now gapes-server
```

Details: [`packaging/`](packaging/) for the systemd unit + install script,
[`Caddyfile.example`](Caddyfile.example) for the proxy config.

## Docker (compose)

```sh
cd docker/
cp ../pages.example.toml ./pages.toml
$EDITOR ./Caddyfile         # change the domain + email placeholders
docker compose up -d
```

Builds the multi-arch (`amd64`/`arm64`) image from
[`docker/Dockerfile`](docker/Dockerfile) and runs it behind Caddy. Only
Caddy is exposed on the host (80/443); `gapes-server` stays on the internal
bridge. Persistent state lives in `docker/data/` and `docker/pages/`.

## Architecture

```
   internet :443 → Caddy (TLS) → gapes-server :8080 → SQLite + disk
                                  HTTP-only, non-root
```

External TLS is mandatory in production — see
[`adr/0005-tls-termination.md`](.claude/project-docs/adr/0005-tls-termination.md).
The server stores metadata in SQLite (`./data/db.sqlite`) and per-page
bundles on disk (`./pages/<uuid>/`). Both adapters are behind traits so
Phase 5 can swap in Postgres + S3 without touching business logic.

More: [`DESIGN.md`](.claude/project-docs/DESIGN.md) for the architecture
tour, [`SECURITY.md`](.claude/project-docs/SECURITY.md) for the always-on
defaults, [`specs/phase-1-core.md`](.claude/project-docs/specs/phase-1-core.md)
for the Phase 1 surface.
