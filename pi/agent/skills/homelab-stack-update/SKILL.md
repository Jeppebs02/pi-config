---
name: homelab-stack-update
description: Update and restart the Docker Compose stacks on the Ubuntu homelab host (10.10.10.10) over SSH — pull images, recreate only the services that were already running, skip Minecraft and CI-deployed stacks, then verify container health and every Traefik-routed site. Use when asked to update, upgrade, pull, or restart the homelab docker containers or stacks.
---

# Homelab stack update

Target: `root@10.10.10.10` (Ubuntu docker host, Proxmox VM 100; credentials also in
the NetworkInfo `llms.txt`). Both scripts run **on the host** — pipe them over ssh,
nothing needs copying:

```bash
SKILL=~/.pi/agent/skills/homelab-stack-update/scripts
SSH="ssh -i ~/.ssh/ubuntu_w_docker -o BatchMode=yes root@10.10.10.10"
```

`update.sh` handles every compose project that has a running container and skips
Minecraft stacks and CI-deployed checkouts (runner workdirs) on its own.

## Procedure

1. **Preflight** — confirm the host is reachable, compose exists, and there is disk room:

   ```bash
   $SSH 'hostname; docker compose version; df -h / | tail -1'
   ```

   Expect `ubuntu` and comfortably more than 20G free. Stop and report if not.

2. **Update**:

   ```bash
   $SSH 'bash -s' < "$SKILL/update.sh"
   ```

   Check the `SUMMARY` line. Pull errors are *not* failures of the run — see the
   table below for what each one means.

3. **Wait ~60s**, then **verify** (re-run it after another minute if things are
   still warming up):

   ```bash
   $SSH 'bash -s' < "$SKILL/verify.sh"
   ```

   Pass = empty "regressions" section, empty "restarting/unhealthy" section (or
   only rows marked pre-existing), and no `FAIL` line. A 401 is Traefik basic
   auth, not an error.

4. **Diagnose** anything flagged — always look before reporting:

   ```bash
   $SSH 'docker logs --tail 30 <container>'
   ```

5. **Report** in one table: per stack `recreated` / `unchanged` / `skipped (why)` /
   `pull failed (why)`, then a "not working" list. Always include pre-existing
   failures and say they predate the update — compare with the `before:` column.

## Error recovery

| Symptom | Meaning / fix |
|---|---|
| `ssh` connect timeout or "Permission denied" | The workstation is on a VPN that swallows the 10.10.10.0/24 route. Disconnect the VPN and retry. |
| `pull access denied` for a locally built image (`banking-dashboard-api`, `copy-party-feedback-api`) | Built by the project's GitHub runner from its repo, not pulled from a registry. Redeploy by pushing to the repo. |
| `unauthorized` for `ghcr.io/...` | Private package; only the CI runner is logged in. Redeploy via CI. |
| `pull access denied` for `minio/minio` | Image removed from Docker Hub. The running container keeps working; it cannot be updated this way. |
| `error while interpolating ... variable is not set` | That project's `.env` is missing or incomplete (`pantio`). Supply values inline (`VAR=x docker compose ...`) or fix `.env`. |
| Container `Restarting (1)` with a huge restart count, and compose warns it is an **orphan** | Leftover from a removed compose service. Confirm it is gone from the compose file, then `docker rm -f <name>`. |
| Runner log: `Runner version ... is deprecated and cannot receive messages` | GitHub retired that runner version. Recreate the runner container on `myoung34/github-runner:latest` with the same env and mounts. |
| `FAIL ... 404` | Traefik has the router but no backend on the `proxy` network, or the container is label-only. `docker inspect` its networks; check Traefik logs. |
| `FAIL ... 000` | TLS or connection failure: Traefik down or the site is not served on 127.0.0.1:443. |
| Traefik `Error renewing ACME certificate ... NXDOMAIN` | The domain is dead. Remove its router labels from the owning compose file and, with Traefik stopped, drop the certificate entry from `traefik/letsencrypt/acme.json`. |

## Not handled by the scripts — do these by hand

- **Nextcloud AIO children** (apache, nextcloud, database, …): managed by the
  AIO mastercontainer. Update through its UI
  (`ssh -L 8080:127.0.0.1:8080 root@10.10.10.10`, then `https://localhost:8080`).
- **Portainer** (not compose-managed):

  ```bash
  $SSH 'docker rm -f portainer && docker run -d --name portainer --restart=always -p 9443:9443 -v /var/run/docker.sock:/var/run/docker.sock -v portainer_data:/data portainer/portainer-ce:latest'
  ```

- **CI-deployed stacks** (`networkinfo-web`, `tglabs-frontend`, `tglabs-contact-relay`):
  deployed by their own GitHub runners. "Updating" them means pushing to the repo.
