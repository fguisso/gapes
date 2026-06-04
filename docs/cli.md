# The CLI

The binary is `gapes`. Every command auto-rotates your refresh token and only requests the smallest scope it needs.

| Command                                | What it does                                            |
|----------------------------------------|---------------------------------------------------------|
| `gapes login [--automation]`           | Device-flow login. `--automation` cannot do destructive ops, period. |
| `gapes whoami`                         | Current device plus which credential store you're on.   |
| `gapes deploy <dir> [--uuid X]`        | Zip and upload. Omit `--uuid` to create, pass it to update. |
| `gapes ls`                             | Your pages.                                             |
| `gapes get <uuid>`                     | Metadata for one page.                                  |
| `gapes stats <uuid> [--range 7d]`      | ASCII analytics: views, uniques, top paths, referrers.  |
| `gapes share <uuid> --public`          | Flip visibility. `--public` requires step-up.           |
| `gapes share <uuid> --password secret` | Password-gate it.                                       |
| `gapes share <uuid> --csp off`         | Per-page CSP knob. Use `strict` (default) or `off` to let pages load CDN assets. Also accepted on `gapes deploy`. |
| `gapes rm <uuid>`                      | Delete. Always step-up, opens a QR for browser confirm. |
| `gapes devices [revoke <id>]`          | List or revoke logged-in devices.                       |
| `gapes activity --range 7d`            | Recent audit events.                                    |
| `gapes comments enable <uuid>`         | Turn comments on for a page.                            |
| `gapes comments ls <uuid>`             | Moderation queue (visible, pending, hidden).            |

```sh
gapes stats 01HXYZ --range 7d
─── last 7 days ────────────────────────────────────────
views        342    █████████████████░░░░  uniques  87
top paths
  /index.html              198
  /about                    71
top referrers
  google.com                 88
  (direct)                  120
─────────────────────────────────────────────────────────
```

Refresh tokens land in the best available store, with no silent downgrades:
**macOS Keychain / Windows Credential Manager / libsecret → `pass` → age-encrypted file → `~/.config/gapes/auth.toml` (chmod 600) → `GAPES_REFRESH_TOKEN` env var**.
