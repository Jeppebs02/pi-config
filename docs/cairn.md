# cairn

[oritera/Cairn](https://github.com/oritera/Cairn) is a problem-solving engine built around
explicit state-space search, validated on autonomous penetration testing: agent workers run
an OODA loop over a shared fact/intent graph (the "blackboard"), coordinated by a dispatcher,
and write confirmed findings back as new Facts. It won the Tencent Cloud Hackathon AI pentest
challenge (54/54 problems solved). Worker backends: **Claude Code, Codex, and pi**.

This doc covers deploying it on a **dedicated Proxmox VM in the DMZ** (`10.10.10.0/24`,
behind OPNsense) — internet targets only — with **pi as the worker backend**: GLM
coding plan primary, DeepSeek fallback. Nothing runs on `ubuntu-serv` and nothing touches
the Traefik stack.

## Not that other Cairn

There are two unrelated projects called "Cairn":

- **[oritera/Cairn](https://github.com/oritera/Cairn)** — this one. Python + Docker
  pentest/state-space engine. Its "pi support" means the **pi CLI runs as a worker backend**:
  the dispatcher feeds pi a prompt, pi explores headlessly, Cairn parses the structured
  output. No MCP anywhere in it.
- **[ShahramMebashar/cairn](https://github.com/ShahramMebashar/cairn)** — a Go task-graph
  MCP server with a "Connect" page that writes MCP configs for coding agents (including
  pi). Different tool, not deployed here.

If you came here looking for an MCP connector, that's the second one.

## How Cairn runs pi

Two execution modes (`runtime.execution` in `dispatch.yaml`):

| | **Container mode** (default) | **Local mode** (`execution: local`) |
|---|---|---|
| Workers run in | Per-project **Kali containers** from `ghcr.io/oritera/cairn-worker-container` | Bare processes on the dispatcher host |
| pi | Pinned in the image (`pi@0.73.0`, alongside claude-code + codex) | The host's own `pi` CLI with its real `~/.pi` config — no keys in `dispatch.yaml` |
| LLM credentials | `PI_*` env vars in `dispatch.yaml`; Cairn generates a throwaway `models.json` under `/tmp/cairn-pi/<worker>/` and runs pi with `PI_CODING_AGENT_DIR` pointed at it | pi uses the host's `models.json`/`auth.json` as-is |
| Toolbox | Full Kali headless: netexec, nmap suite, nuclei, katana, dalfox, kerbrute, cloudfox, ysoserial, jwt_tool, chisel, pwntools, HackTricks + PayloadsAllTheThings + vulhub cloned, playwright | Whatever is installed on the host |
| Isolation | Fresh container per project | Unsandboxed, user perms, shared host |

How the pi adapter invokes it (both modes): `--mode json -p <prompt>` with
`--no-extensions --no-skills --no-prompt-templates --no-themes --no-context-files` and
`--tools read,write,edit,bash,grep,find,ls`, using `--session`/`--session-dir` for session
recovery across a project's tasks. Output is parsed from the JSONL event stream. So workers
are plain headless pi agents — no MCP, no extensions, just the core tools against the
workspace.

**Decision: container mode.** Local mode's only advantage is credential reuse, but on a
server that isn't Kali the workers would arrive at a pentest with no tools, and they'd run
unsandboxed on the host. Container mode is the configuration that won the hackathon; the
prompts assume the Kali toolbox. Local mode stays available as a fallback (see
[Local mode fallback](#local-mode-fallback)).

## The VM

Cairn runs on a **dedicated single-tenant Proxmox VM in the DMZ**. Nothing
Cairn-related runs on `ubuntu-serv`.

- **Sizing**: 2–4 vCPU, 4–8 GB RAM, ~100 GB thin disk — the worker image alone is
  15–25 GB.
- **OS**: minimal Debian or Ubuntu Server + Docker (`docker-ce` + compose plugin). The
  Kali toolchain arrives inside the worker containers; a Kali host is only worth it as a
  dual-use manual attack box, and isn't needed.
- **Network**: static IP (or DHCP reservation) in the DMZ. It inherits the segment's
  fence — no home LAN, no router, no Proxmox, outbound internet allowed — with zero new
  rules.
- **Why dedicated**: the dispatcher mounts `docker.sock` (root-equivalent on its host)
  and its workers are LLM-driven agents on host networking attacking hostile targets; the
  blast radius must not be the box terminating TLS for the homelab. Bonus: Proxmox
  snapshot before a run, revert after.

## Deployment

On the VM (x86_64 — the worker image is amd64-only):

```bash
cd ~
git clone https://github.com/oritera/Cairn cairn && cd cairn
cp dispatch.example.yaml dispatch.yaml
chmod 600 dispatch.yaml      # before pasting the keys into it
```

### dispatch.yaml

Comment out the claude worker and swap in the two-worker pool: **GLM coding plan primary,
DeepSeek fallback**. Priority is ascending, so GLM takes the work and DeepSeek only picks
up what GLM's `max_running` can't absorb:

```yaml
workers:
  - name: "pi_glm"
    type: "pi"
    task_types: [bootstrap, reason, explore]
    max_running: 1              # coding plans are concurrency-limited — don't raise
    priority: 0
    env:
      PI_MODEL: "glm-5.3"       # exact model ID from the plan's /model list
      PI_BASE_URL: "https://api.z.ai/api/anthropic"
      PI_API_KEY: "<Z.AI coding plan key — never commit>"     # see Secrets
      PI_PROVIDER_API: "anthropic"
      PI_MODEL_CONTEXT_WINDOW: "<from plan docs>"

  - name: "pi_deepseek"
    type: "pi"
    task_types: [bootstrap, reason, explore]
    max_running: 2
    priority: 1
    env:
      PI_MODEL: "deepseek-flash"   # cheap overflow; deepseek-v4-pro for a stronger fallback
      PI_BASE_URL: "https://api.deepseek.com"   # or /anthropic + PI_PROVIDER_API "anthropic"
      PI_API_KEY: "<DeepSeek platform key — never commit>"    # see Secrets
      PI_PROVIDER_API: "openai-completions"
      PI_MODEL_CONTEXT_WINDOW: "128000"
```

Notes:

- The GLM docs' `/login zai` flow is for **interactive** pi — container workers can't log
  in, which is exactly why the key goes into the generated provider above.
- Switching models or changing the split = edit `dispatch.yaml` +
  `docker compose restart cairn-dispatcher` (config is read at startup; do it between
  runs, not mid-run). Server and web UI stay up.
- The startup healthcheck POSTs a 10-token ping per worker — `{PI_BASE_URL}/chat/completions`
  (openai-completions; `/v1/messages` with the anthropic-version header for
  `anthropic`-style APIs, `/responses` for `responses`-style). A green check means key +
  model + base URL all work before any project burns tasks.

Useful knobs (defaults from `dispatch.example.yaml` are fine to start):

- `runtime.max_workers` (8), `max_running_projects` (3), `max_project_workers` (4) — global
  and per-project concurrency caps.
- `tasks.*.timeout` / `conclude_timeout` — per task-type budgets (bootstrap 300/90,
  reason 300, explore 300/90 by default).
- `container.network_mode: host` — workers share the host network; that's how they reach
  targets. Don't change it.
- Worker priority is ascending (lower = preferred). `max_running` is per-worker. The two
  workers above are one pool — GLM leads, DeepSeek absorbs overflow. Flip the priorities
  or restrict `task_types` (e.g. DeepSeek on `[explore]` only) to change the split, then
  restart the dispatcher.

### Images

The worker image is a full Kali headless + toolchain + knowledge repos — hence the VM's
disk sizing; `df -h` before pulling.

```bash
docker pull --platform=linux/amd64 ghcr.io/oritera/cairn-worker-container:latest
docker pull ghcr.io/astral-sh/uv:python3.13-trixie   # base for building Cairn itself
```

### Up

```bash
docker compose up -d --build
```

The repo ships `docker-compose.yaml` (only compose file in the folder, so plain
`docker compose` is fine). It starts:

- `cairn-server` — web UI + graph API on port 8000, data persisted to `./datas/cairn/`.
- `cairn-dispatcher` — waits for the server health check, then schedules. Mounts
  `/var/run/docker.sock` and `./dispatch.yaml`.

Verify the worker wiring without spending tasks:

```bash
docker compose run --rm cairn-dispatcher \
  uv run cairn dispatch --config dispatch.yaml --startup-healthcheck-only
```

Create projects, watch the fact/intent graph, and inject Hints (human judgment the agents
absorb on their next read) via the web UI at `http://<vm-ip>:8000`.

## Exposing the UI — LAN/VPN only, no Traefik

The Cairn UI is an **unauthenticated** pentest-orchestration control plane (anyone who can
reach it can create projects pointing workers at arbitrary targets and read all findings).
Same class as Grafana: **LAN/VPN only**, published port, no Traefik route. The stock
compose's `ports: "8000:8000"` is correct as-is.

The VM is single-tenant and never joins the `proxy` network — there are no labels to add
and none should ever be added; remote access is what VPN is for.

OPNsense steps:

> **Firewall → Aliases → `ADMIN_PORTS`: add `8000`.** Then check the corresponding pass
> rule's destination — if it targets `10.10.10.10` specifically (or a host alias that
> doesn't include the Cairn VM), add the VM's IP so the rule covers it.

The UI then answers at `http://<vm-ip>:8000` from the admin PC / VPN.

## What workers can reach from the DMZ

Worker containers run with `network_mode: host`, i.e. they share the Cairn VM's network
position (DMZ, `10.10.10.0/24`, behind OPNsense). **This deployment targets internet
hosts only:**

- ✅ **Internet targets** (contract work, remote CTF boxes) — outbound internet allowed;
  the dispatcher's provider healthchecks (z.ai, DeepSeek) work from inside compose.
- ⚠️ **DMZ peers** (including `ubuntu-serv` at `10.10.10.10`) — same subnet;
  reachability depends on the intra-DMZ policy. A worker poking DMZ peers would be an
  own-goal — if intra-DMZ traffic is open, an OPNsense rule blocking the Cairn VM →
  `ubuntu-serv` specifically is cheap insurance.
- ❌ **Home LAN targets** (`192.168.50.0/24`), router, Proxmox — blocked by the DMZ fence;
  leave it that way. Local lab targets were ruled out at design time: if that ever
  changes, build a fenced range VLAN for the Cairn VM + targets instead of punching holes
  to the LAN — vulnerable targets must never share a segment with the reverse proxy.
- ⚠️ **Reverse shells from internet targets**: a listener on a worker binds the VM's IP,
  which the internet can only reach on forwarded public ports. Either run the standard
  raw-port procedure (`PUB_TCPUDP` alias in OPNsense + ASUS forward to `192.168.50.2`,
  NAT destination = the Cairn VM) for a dedicated callback port, or steer workers toward
  egress-only tunnels (SSH `-R` back out).

## Notes on the Docker socket and the UI port

On a single-tenant VM the old co-tenancy concerns are gone, but the facts remain:

1. **`cairn-dispatcher` mounts `/var/run/docker.sock` directly.** It genuinely needs the
   full Docker API (creates, execs, archive-copies into worker containers), which makes it
   root-equivalent on the VM — the main reason this is a dedicated machine.
2. **Port 8000 is published with no Traefik route** — deliberate; access is fenced by the
   `ADMIN_PORTS` rule, like Grafana.

## Local mode fallback

If Docker is ever unavailable (or for a quick smoke test of pi wiring): set
`runtime.execution: local` (`dispatch.local.example.yaml` is the template), install pi on
the host, make sure the host pi can reach the providers (`/login zai` covers the GLM
coding plan; DeepSeek needs a `models.json` entry), drop the `env:` block from the worker
entry,
and run the dispatcher **on the host, not via compose**:

```bash
uv run --project cairn cairn serve
uv run --project cairn cairn dispatch --config dispatch.yaml
```

Workers then run unsandboxed with the host user's permissions and no Kali toolbox — lab
use only.

## Troubleshooting

- **Healthcheck green but tasks fail with 401**: the healthcheck talks straight to the
  provider with `Authorization: Bearer`, so it can't catch pi-side header differences
  (`x-api-key` vs Bearer on the anthropic-style endpoints) — header style is the first
  suspect. For the GLM worker, also check the plan's usage page: an exhausted plan window
  fails the same way.
- **Job stuck / no worker picked up**: `docker compose logs cairn-dispatcher --tail 50`;
  check the worker entry isn't fully commented out in `dispatch.yaml`.
- **Worker container missing tools**: the image is pinned at build time; pull a fresh
  `cairn-worker-container:latest` and let the dispatcher recreate project containers.
- **pi version drift**: image pins `pi@0.73.0`. If a pi feature is needed, build a custom
  worker image from `container/Dockerfile` with a newer pin and point `container.image` at it.

## Secrets

**`dispatch.yaml` contains both provider keys in plaintext** — the Z.AI coding plan token
(anyone with it can burn the plan quota) and the DeepSeek platform key (spends
pay-as-you-go credit):

- Real values live only in `~/cairn/dispatch.yaml` on the Cairn VM, `chmod 600`, never
  committed, never pasted into chat logs or this repo.
- Copy them by hand on the server (`ssh` + editor), not through any logged channel.
- If either leaks: rotate at the provider (z.ai plan page / DeepSeek platform), update
  `dispatch.yaml`, restart the dispatcher (`docker compose restart cairn-dispatcher`).

## Reference

- Upstream: <https://github.com/oritera/Cairn> (README covers config fields and the
  architecture; `docs/specs/` has the dispatcher/server design docs).
- Worker image source: `container/Dockerfile` in the repo — the authoritative list of what
  tools the agents get.
- pi adapter source: `cairn/src/cairn/dispatcher/workers/adapters/pi.py` — exact CLI flags
  and the generated `models.json` shape.
