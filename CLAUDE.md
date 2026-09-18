# CLAUDE.md

Guidance for Claude Code when working in this repo.

## What this is

Self-hosted Immich (Google Photos replacement) for Jonah + 2 family
members (3 separate accounts), running on a home server (HP EliteDesk 800
G4 — i5 3.1GHz, 16GB RAM, 256GB internal SSD, no dedicated GPU). Public at
`photos.jonahsaidian.com`, exposed via the Cloudflare Tunnel that lives in
the sibling repo `../home-server-infra` (that repo also carries
`farsi-transcriber` and replaces the old `../DO_infra` DigitalOcean setup).

Full original requirements/interview and the approved plan are preserved
at `C:\Users\jonah\.claude\plans\i-want-to-move-floating-tower.md` — read
that for the complete picture if this file is insufficient.

## Current status (as of 2026-09-17)

Deployed on the mini PC at Immich **v3.2.2** (upgraded from the stale v1.118.2
pin on 2026-09-17; see the upgrade bullet under Key decisions). External HDD
mounted at `/mnt/photos` with the canary marker file in place. The database
is fresh and empty — no accounts exist yet; Jonah is about to re-create the
admin account and test uploads via a temporary SSH tunnel forward.
`photos.jonahsaidian.com` is not yet routed through the tunnel — DNS cutover
happens together with Jonah, after his test passes. Committed and pushed to
GitHub (`main`).

Still to do: create the 3 family accounts, disable public self-registration,
enable 2FA per account; install `systemd/immich.service`; install the
self-hosted GitHub Actions runner for this repo; verify push-to-deploy; DNS
cutover + 24-48h monitoring, then decommission `DO_infra` together with
Jonah. Phase 2 backup-drive automation stays inert until the second drive
arrives (udev rule still has a placeholder UUID).

## Key decisions and why

- **Photo library lives entirely on an external HDD (`/mnt/photos`),
  never the internal SSD.** The internal disk is only 256GB — too small
  for a family photo library — so app code/DB stays internal but the
  actual upload volume must be the external drive.
- **Mount-guard (`scripts/check-library-mount.sh`) gates every start and
  every deploy.** This is the direct answer to Jonah's requirement that if
  the drive isn't available, the stack should *wait*, not silently start
  writing into an empty folder on the internal disk. It checks both
  `mountpoint -q` and a canary marker file (an unmounted directory would
  otherwise look like a valid empty mount point). `systemd/immich.service`
  retries every 30s indefinitely (`StartLimitIntervalSec=0`) rather than
  failing once and staying down.
- **`postgres`/`redis`/`immich-machine-learning` never join the `edge`
  network** — only `immich-server` does. Keeps the DB and ML worker
  unreachable from the tunnel/outside world even in principle.
- **Local-only backups for now, but built on restic (not rsync).** Jonah
  is sourcing the second backup drive soon; Cloudflare R2 offsite backup
  remains a later option. Restic was chosen
  specifically so adding an encrypted R2 target later is a small config
  change, not a redesign — restic already encrypts client-side.
- **Disk encryption (LUKS) on the library drive: explicitly skipped** per
  Jonah's call when asked directly — not a concern for where the drive
  will live. Revisit only if that changes.
- **`IMMICH_VERSION` is pinned, not `:latest`**, and auto-deploy will
  never bump it on its own — bumping the pin is also the security-patch
  checkpoint. There's no automated reminder for this yet (candidate:
  Dependabot/Renovate on the `.env` pin), it's currently a manual TODO.
- **Upgraded v1.118.2 to v3.2.2 on 2026-09-18**: the old pin was stale (v1.118.2 dates to ~Oct 2024), not a deliberate choice. Library and DB were still empty, so this was a fresh-DB redeploy rather than an in-place migration. v3 compose conventions now in use: library mounts at `/data` via `UPLOAD_LOCATION` (replaces `IMMICH_LIBRARY_PATH` to `/usr/src/app/upload`); DB path via `DB_DATA_LOCATION`; queue is Valkey (`docker.io/valkey/valkey:9`) but the compose service is still named `redis` so the `REDIS_HOSTNAME` default keeps resolving; postgres image `14-vectorchord0.4.3-pgvectors0.2.0` with `--data-checksums` on init and `shm_size: 128mb`. Service names (`postgres`, `redis`) kept deliberately — `DB_HOSTNAME=postgres` depends on it.
- **Per-user isolation is native Immich behavior**, not something built
  here — each account only sees its own library; the admin account (Jonah)
  can see everything via the admin panel. Confirmed this matches what
  Jonah wants ("my images, not others, except via direct server access").
- **Quick Sync hardware transcoding** (`/dev/dri` passthrough on
  `immich-server`) is scaffolded but commented out in
  `docker-compose.yml` — enable once verified the device exists on the
  actual host and the iGPU driver is set up.

## Related repos

- `../home-server-infra` — owns the Cloudflare Tunnel that exposes
  `immich-server` publicly, plus `farsi-transcriber` and host bootstrap.
  Shares the external `edge` Docker network with this repo.
- `../DO_infra` — unrelated to Immich (never ran it), being replaced by
  `home-server-infra` for the pre-existing app only.
