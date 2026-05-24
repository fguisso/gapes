# packaging/

Build artifacts, install scripts, and OS-level integration for `gapes-server`.
Everything here is downstream of the binary — nothing in this directory is
linked into the Rust build.

## What's in here

| Path                              | Purpose                                                                 |
|-----------------------------------|-------------------------------------------------------------------------|
| `install.sh`                      | One-shot installer for Linux. Downloads a release, verifies SHA256, drops the systemd unit + default config, prints next steps. |
| `systemd/gapes-server.service`    | Hardened systemd unit. Runs as the `gapes` user with `NoNewPrivileges`, `ProtectSystem=strict`, and friends. |

## Conventions

- The binary is installed to `/usr/local/bin/gapes-server` by default.
  Override with `GAPES_PREFIX`.
- Config lives at `/etc/gapes/pages.toml` (mode `0640`, owner `root:gapes`).
- Mutable state (SQLite, pages, key material) lives at `/var/lib/gapes/`
  (owner `gapes:gapes`, mode `0750`).
- The service user is `gapes` / group `gapes`, system account, no login
  shell, no home directory of its own besides `/var/lib/gapes`.
- TLS is **always** external. The unit binds HTTP on `127.0.0.1:8080` and
  expects Caddy (or another reverse proxy) in front of it. See
  `../Caddyfile.example` and `../.claude/project-docs/adr/0005-tls-termination.md`.

## Future layout

The intent is for this directory to host packaging metadata for the main
distros and package managers as they land:

```
packaging/
├── install.sh                  # done
├── systemd/                    # done
├── debian/                     # planned — debhelper rules, .deb postinst
├── rpm/                        # planned — .spec file for Fedora / openSUSE
├── homebrew/                   # planned — formula for macOS dev installs
└── nix/                        # planned — flake + NixOS module
```

When adding a new packaging target, prefer to call into `install.sh`'s logic
(or factor shared bits into a helper) rather than re-implement user/dir
creation per packager.

## Releasing (rough sketch)

The install script downloads from
`https://github.com/meistrari/gapes/releases/download/<TAG>/gapes-server-<TAG>-<TRIPLE>.tar.gz`
with a sibling `.sha256` file. The release pipeline (TBD, lives in
`.github/workflows/`) must:

1. Build `gapes-server` for `x86_64-unknown-linux-gnu` and `aarch64-unknown-linux-gnu`.
2. `tar -czf gapes-server-<TAG>-<TRIPLE>.tar.gz gapes-server`.
3. `sha256sum gapes-server-<TAG>-<TRIPLE>.tar.gz > gapes-server-<TAG>-<TRIPLE>.tar.gz.sha256`.
4. Upload both as release assets.
