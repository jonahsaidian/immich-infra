# immich-infra

Self-hosted Immich stack (Google Photos replacement) for the home server.
Public at `photos.jonahsaidian.com` via the tunnel in the sibling
`home-server-infra` repo.

## Architecture

```
home-server-infra's cloudflared --- edge network ---> immich-server (2283)
                                                             |
                                              default network (internal only)
                                                             |
                                          immich-machine-learning, redis, postgres
```

`immich-server` is the only service reachable from outside this compose
project -- it joins both the internal `default` network (talking to
postgres/redis/machine-learning) and the external `edge` network (so
`cloudflared` in `home-server-infra` can reach it). Everything else stays
internal.

## Storage layout

- App code, Docker images, and the Postgres database live on the mini
  PC's internal SSD (256GB -- too small for the photo library itself).
- The photo/video library lives entirely on an external HDD, mounted at
  `/mnt/photos`.
- **`scripts/check-library-mount.sh` guards every start and every deploy.**
  It refuses to proceed unless `/mnt/photos` is a real mount *and*
  contains a canary marker file (`.immich-library-marker`) that only
  exists on the actual drive. This prevents Immich from silently writing
  the library into an empty folder on the internal disk if the external
  drive is ever unplugged or fails to mount.

### One-time drive setup

```bash
# Find the drive's UUID after formatting (ext4 recommended)
sudo blkid

# Add to /etc/fstab (mounts at boot, doesn't block boot if missing):
UUID=<your-drive-uuid>  /mnt/photos  ext4  defaults,nofail  0  2

sudo mount -a
touch /mnt/photos/.immich-library-marker   # the canary check.sh looks for
```

### Running as a systemd service

`systemd/immich.service` runs `docker compose up -d` only after the mount
guard passes, and retries every 30s indefinitely if the drive isn't
present yet (rather than failing once and staying down):

```bash
sudo cp systemd/immich.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now immich.service
```

## Backups (Phase 2 -- not active yet)

`scripts/backup-to-secondary.sh`, `systemd/immich-backup.service`, and
`udev/99-backup-drive.rules` scaffold an automatic backup: plugging in a
second external HDD (matched by its filesystem UUID) triggers a `restic`
backup of `/mnt/photos` to it. Not wired up yet -- Jonah is sourcing the
second drive soon; wire it up when it arrives (see the comments in each
file for install steps at that point). Restic encrypts backups
client-side, so adding an offsite Cloudflare R2 copy later is a small
change, not a redesign.

## Users

Create the 3 family accounts from the Immich admin panel after first
boot, then **disable public self-registration** and enable 2FA per
account (see the Security section in the project plan). Each account only
sees its own library unless a shared album is explicitly created; the
admin account can see all libraries.

## Deploys

Push to `main` and the self-hosted GitHub Actions runner (installed on the
mini PC) re-runs the mount-guard check, pulls new images, and redeploys.
See `.github/workflows/deploy.yml`.

## Key Files

| File | Purpose |
|------|---------|
| `docker-compose.yml` | immich-server, immich-machine-learning, postgres, redis |
| `.env` | DB creds, `IMMICH_VERSION` pin, `IMMICH_LIBRARY_PATH`; gitignored, copy from `.env.example` |
| `scripts/check-library-mount.sh` | Mount-guard, run before every start and every deploy |
| `systemd/immich.service` | Boot-time service with retry-until-mounted behavior |
| `scripts/backup-to-secondary.sh`, `udev/`, `systemd/immich-backup.service` | Phase 2 backup-drive automation |
