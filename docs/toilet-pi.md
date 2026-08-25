# toilet-pi

[toilet-pi](https://github.com/mrexodia/toilet-pi) lets you control `pi` sessions on this
machine from a browser: watch active work, send prompts, abort a run, resume an inactive
session in the background, or start a new session in a project — from a phone or another
computer.

It has two halves:

- **Server** — a central WebSocket hub. This is deployed separately on the homelab, behind
  Nginx Proxy Manager, over public HTTPS. **Out of scope for this repo.**
- **Client** (this repo's concern) — on each desktop/laptop:
  - the `toilet-pi.ts` **extension**, loaded into every interactive `pi` session so it can
    connect to the server and be watched/controlled live, and
  - the **supervisor** (`npm run supervisor`), a standalone Node process that discovers
    local `pi`/OMP sessions and starts matching background processes on request from the
    browser. It needs to run continuously, independent of any interactive `pi` session —
    that's why it's registered as an OS-level service (Windows Scheduled Task / systemd
    user service) rather than something you start by hand.

Connections are always outbound from each machine to the server, so nothing needs to be
exposed on desktop/laptop.

## Install

The extension is vendored as a `pi` package, not a git submodule — `pi` already has a
package manager for exactly this (git-source packages get cloned to
`~/.pi/agent/git/<host>/<path>` and reconciled/`npm install`ed automatically on startup),
so there's no reason to duplicate that with a submodule. The only thing this repo commits
is the reference to it:

```json
// pi/agent/settings.json
"packages": [
  "...",
  "https://github.com/mrexodia/toilet-pi"
]
```

That entry was added by running `pi install https://github.com/mrexodia/toilet-pi` and
committing the resulting `settings.json` diff. On a fresh machine, after `install.ps1` /
`install.sh` symlinks `pi/` to `~/.pi`, starting `pi` once is enough for it to clone
toilet-pi to `~/.pi/agent/git/github.com/mrexodia/toilet-pi` and run its `npm install`.
Re-running `install.ps1` / `install.sh` after that registers the supervisor service (see
below) — it skips that step with a note if the checkout isn't there yet.

## Connecting a machine

1. On the homelab server's web UI, open **Installation** and generate a machine connect
   URL. Generate a **separate URL per machine** — desktop and laptop each need their own.
2. Inside an interactive `pi` session on that machine, run:

   ```text
   /toilet-pi setup wss://your-server/ws?token=...
   ```

   Use the exact `wss://` URL the web UI generated — not the browser admin login URL.
3. Check it took effect with `/toilet-pi status`.

This writes `~/.pi/agent/toilet-pi.json` (i.e. `pi/agent/toilet-pi.json` in this repo,
through the symlink) with the URL and token. See **Secrets** below.

Other subcommands: `/toilet-pi` on its own lists what's available.

## Supervisor service

`install.ps1` / `install.sh` register the supervisor (`npm run supervisor`, run from the
toilet-pi checkout) as an OS service so it survives logoff, reboot, sleep/wake, and
crashes:

- **Windows**: a Scheduled Task named `ToiletPiSupervisor`, triggered at logon and at
  workstation unlock, set to restart on failure (999 retries, 1 minute apart — the retry
  counter resets on the next logon/unlock trigger, so in practice this never gives up).
  ```powershell
  Start-ScheduledTask -TaskName ToiletPiSupervisor   # start now
  Get-ScheduledTask -TaskName ToiletPiSupervisor      # check state
  ```
- **Linux**: a `systemd --user` service, `toilet-pi-supervisor.service`, enabled against
  `default.target` with `Restart=on-failure`, `RestartSec=5`, and start-rate-limiting
  disabled (`StartLimitIntervalSec=0`) so retries never get suppressed.
  ```bash
  systemctl --user status toilet-pi-supervisor.service
  journalctl --user -u toilet-pi-supervisor.service -f
  ```

To tear the service down cleanly (e.g. before decommissioning a machine, or to
reconfigure it from scratch):

```powershell
.\install.ps1 -Uninstall      # Windows
```

```bash
./install.sh --uninstall      # Linux
```

This only removes the scheduled task / systemd unit — it doesn't touch the `~/.pi`
symlink, the Defender exclusion, or `toilet-pi.json`.

## Secrets

**The machine connect URL and the homelab admin/server token are secrets.** Anyone with
the URL can act as that machine in toilet-pi; anyone with the admin token can control the
whole server. Treat them like a password:

- The real values live only in `pi/agent/toilet-pi.json`, which is **gitignored** (see
  `.gitignore`) and written with `0600` permissions by `/toilet-pi setup` itself.
- `pi/agent/toilet-pi.json.example` is committed as a template showing the file's shape
  — placeholders only, never a real URL or token.
- Never paste the real URL/token into a commit, issue, chat log, or this repo's docs.
- If a URL or token leaks, regenerate it from the homelab server's web UI and re-run
  `/toilet-pi setup` with the new one on every affected machine.

## Troubleshooting

- **Machine not visible in the web UI**: the supervisor isn't running — check the
  Scheduled Task / systemd service status above.
- **Interactive session not visible**: confirm the package is installed (`pi list`),
  then `/reload` or restart `pi`.
- **Wrong server configured**: generate a fresh machine URL and re-run `/toilet-pi setup`.

See the [upstream README](https://github.com/mrexodia/toilet-pi) for the full reference,
including server deployment (not needed here — the homelab server is already running).
