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

## Windows desktop (done 2026-11-23)

1. `pi install npm:@blackbelt-technology/pi-agent-dashboard` — was already installed
2. Tunnel `pi-desktop` (`cf tunnels create --config-src local --tunnel-secret …`,
   id `66987e68-05a6-44bb-bb5c-ddf67a9d6e1c`), credentials
   `~/.cloudflared/66987e68-….json`, config `~/.cloudflared/config.yml`
   (ingress `pi-desktop.jeppebs.xyz` → `http://localhost:8000`; the
   credentials-file line is omitted — cloudflared auto-discovers
   `~/.cloudflared/<tunnel-id>.json`)
3. DNS CNAME `pi-desktop.jeppebs.xyz` → `66987e68-….cfargotunnel.com` (proxied)
4. Scheduled tasks `cloudflared-pi-desktop` and `pi-dashboard` (server
   auto-started at logon so the chooser light stays green without a running
   pi session), both with an **S4U principal**
   (`New-ScheduledTaskPrincipal -LogonType S4U`): they run in a
   non-interactive session, so the console apps never show a window and
   keep running after logoff. Registering an S4U task needs one elevated
   `Register-ScheduledTask` (plain Interactive tasks would work without
   admin but pop a visible console window). cloudflared action args:
   `tunnel --no-autoupdate run` — the flag belongs to `cloudflared tunnel`,
   BEFORE `run`; after `run` it exits instantly with usage error (exit code
   0, so the task's restart-on-failure never fires).
5. `publicBaseUrls: ["https://pi-desktop.jeppebs.xyz"]` added to
   `pi/dashboard/config.json`

## Secrets

Tunnel credentials (`~/.cloudflared/66987e68-….json` on the desktop,
`~/.cloudflared/pi-laptop.json` on the laptop) and the dashboard
pairing identity (`pi/dashboard/identity.key`) are machine-local secrets —
never commit. Gitignored defensively via `pi/dashboard/`.

The PI Dashboard server also re-asserts a machine-local absolute path in
`pi/agent/settings.json`'s `packages` list (its extension self-registration;
pi loads the extension from the `npm:` package ref regardless). A git clean
filter (`filters/strip-local-packages.mjs`, wired by `.gitattributes` + the
install scripts) strips those paths so they never show as a diff or get
committed — keep the `npm:@blackbelt-technology/pi-agent-dashboard` entry
as the only dashboard line in the committed file.
