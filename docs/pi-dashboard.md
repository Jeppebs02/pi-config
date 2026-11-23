# PI Dashboard — browser access to pi sessions

Replacement for toilet-pi (removed 2026-11-20, server torn down 2026-11-23).
[PI Dashboard](https://github.com/BlackBeltTechnology/pi-agent-dashboard) mirrors
every running pi session to a browser: read transcripts live, answer prompts,
abort runs, resume/spawn sessions — from the laptop itself or a phone.

## What's where

- **pi package** — `pi install npm:@blackbelt-technology/pi-agent-dashboard`
  added the ref to `settings.json` (the only repo-tracked part). The bridge
  extension auto-starts the dashboard server whenever a pi session runs.
- **Dashboard server** — binds `127.0.0.1:8000`, state in `pi/dashboard/`
  (gitignored, machine-local). Requires Node 26 (satisfied via mise).
- **Cloudflare Tunnel `pi-laptop`** — `~/.cloudflared/config.yml` +
  `pi-laptop.json` credentials (machine-local secrets), serving
  `https://pi-laptop.jeppebs.xyz` → `localhost:8000`. DNS CNAME + tunnel
  managed via the `cf` CLI.
- **Chooser page** — `pi.jeppebs.xyz` on the homelab (`/home/jeppe/pi-chooser`,
  nginx + Traefik, see NetworkInfo map). Buttons for laptop/desktop with
  green/red reachability lights (nginx probes each target's `/api/health`).
- **Cloudflare Access** — the chooser hostname is gated by an Access app
  (owner-email allow policy, 24 h sessions). The dashboard hostnames rely on
  PI Dashboard's own pairing/device auth (its designed-for-tunnels model).

## Machine-local services (recreate, don't commit)

`~/.config/systemd/user/pi-dashboard.service` and
`cloudflared-pi-laptop.service`, both `WantedBy=default.target`:

```bash
systemctl --user enable --now pi-dashboard cloudflared-pi-laptop
```

## First-use pairing

Opening `https://pi-laptop.jeppebs.xyz` in a new browser shows the
dashboard's pairing flow (trust mode `pair`) — approve once per browser.
`publicBaseUrls` in `pi/dashboard/config.json` must contain the public URL
or the server answers `host_not_allowed`.

## Adding the Windows desktop (TODO)

1. `pi install npm:@blackbelt-technology/pi-agent-dashboard` (Node 26 needed)
2. Create tunnel `pi-desktop` (cf CLI), `~/.cloudflared` config → `localhost:8000`
3. DNS CNAME `pi-desktop.jeppebs.xyz` → `<tunnel-id>.cfargotunnel.com`
4. cloudflared as a scheduled task; the chooser button goes green automatically

## Secrets

Tunnel credentials (`~/.cloudflared/pi-laptop.json`) and the dashboard
pairing identity (`pi/dashboard/identity.key`) are machine-local secrets —
never commit. Gitignored defensively via `pi/dashboard/`.
