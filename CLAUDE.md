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

## Current status (as of 2026-08-26)

Scaffolded locally, **not yet committed**, **no GitHub remote created**,
**nothing deployed to the mini PC yet**. No external HDD attached/mounted
yet, no Immich accounts created. Jonah is reviewing the code before
committing. See `../home-server-infra/CLAUDE.md` for the full
migration/cutover order — this repo's part of it is roughly:
1. Format and mount the external HDD at `/mnt/photos`, create the canary
   marker file (`.immich-library-marker`) — see README "One-time drive
   setup".
2. Install `systemd/immich.service`, verify the mount-guard actually
   blocks startup with the drive detached before relying on it.
3. Bring the stack up, confirm `photos.jonahsaidian.com` resolves once
   `home-server-infra`'s tunnel is routed to `immich-server` on the shared
   `edge` network.
4. Create the 3 family accounts, disable public self-registration, enable
   2FA per account.
5. Install the self-hosted GitHub Actions runner for this repo
   specifically (separate from the one in `home-server-infra`).

The Phase 2 backup-drive automation (`scripts/backup-to-secondary.sh`,
`udev/99-backup-drive.rules`, `systemd/immich-backup.service`) is
scaffolded but **intentionally inert** — Jonah hasn't bought the second
drive yet. Don't wire it up until he says the drive exists; the udev rule
still has a placeholder UUID.

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
  said the second backup drive and possibly Cloudflare R2 offsite backup
  are coming later, "for now assume local only." Restic was chosen
  specifically so adding an encrypted R2 target later is a small config
  change, not a redesign — restic already encrypts client-side.
- **Disk encryption (LUKS) on the library drive: explicitly skipped** per
  Jonah's call when asked directly — not a concern for where the drive
  will live. Revisit only if that changes.
- **`IMMICH_VERSION` is pinned, not `:latest`**, and auto-deploy will
  never bump it on its own — bumping the pin is also the security-patch
  checkpoint. There's no automated reminder for this yet (candidate:
  Dependabot/Renovate on the `.env` pin), it's currently a manual TODO.
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
