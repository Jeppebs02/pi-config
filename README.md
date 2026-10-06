# pi-config

Personal config for the [pi coding agent](https://pi.dev) (`@earendil-works/pi-coding-agent`).
Symlinked to `~/.pi` so `pi/agent/AGENTS.md`, `pi/agent/models.json`, and friends become
pi's live global config.

## Structure

```
pi-config/
├── pi/
│   └── agent/
│       ├── AGENTS.md      # global context file, loaded every session
│       ├── models.json    # custom providers — yunwu (openai-completions compat)
│       ├── mcp.json       # MCP servers for pi-mcp-adapter (x64dbg, Resolve, Packet Tracer)
│       ├── skills/        # global skills (Agent Skills standard)
│       ├── prompts/       # global prompt templates (/name to expand)
│       ├── extensions/    # global TypeScript extensions
│       ├── agents/        # subagent definitions (researcher, makers)
│       └── themes/        # global themes
├── install.sh             # symlinks pi/ -> ~/.pi on Linux/macOS
├── install.ps1             # symlinks pi/ -> ~/.pi on Windows
├── .gitignore              # excludes auth.json and other local-only state
└── README.md
```

`auth.json` is **never committed**. Pi writes it locally on `/login`, and it's excluded via
`.gitignore`. It's also where custom provider keys (`yunwu`, etc.) can live instead of an
env var — see [Providers](#providers) below.

## Install

**Linux / macOS**

```bash
git clone <this-repo-url> ~/pi-config
cd ~/pi-config
./install.sh
```

**Windows (PowerShell) — run as Administrator**

Right-click PowerShell → **Run as administrator**, then:

```powershell
git clone <this-repo-url> $HOME\pi-config
cd $HOME\pi-config
.\install.ps1
```

Administrator is needed for two things:

- **Windows Defender exclusion.** The `hack-skills` / `ctf-skills` docs contain
  reverse-shell and web-shell payload examples that Defender's real-time protection
  flags as malware (`Backdoor:*`) and silently deletes. `install.ps1` adds an
  exclusion for the repo folder so the files survive. Only Administrator can call
  `Add-MpPreference`.
- **Symlink creation** — unless Developer Mode is enabled (Settings → Update &
  Security → For developers), which lets the symlink step run without elevation.

If you run it **without** Administrator, the script still creates the symlink (under
Developer Mode) but prints a "run me as admin" warning and skips the Defender
exclusion. You can add it later from an elevated shell:

```powershell
Add-MpPreference -ExclusionPath "$HOME\pi-config"
```

Both scripts are idempotent: re-running them is a no-op if `~/.pi` already points at this
repo's `pi/` folder, and they refuse to overwrite a real (non-symlink) `~/.pi` directory.

Then install pi itself if you haven't:

```bash
npm install -g --ignore-scripts @earendil-works/pi-coding-agent
# or: curl -fsSL https://pi.dev/install.sh | sh
```

## Providers

`pi/agent/models.json` registers **yunwu** as a custom OpenAI-compatible provider:

- `api`: `openai-completions`
- `baseUrl`: `https://yunwu.ai/v1`
- `apiKey`: `"YUNWU_API_KEY"` — this is only the **fallback** used if no credential is found
  earlier in pi's resolution order
- `models`: currently just `claude-fable-5:floor`

### Setting the yunwu key

Pi resolves credentials in this order (see
[docs/providers.md](https://github.com/badlogic/pi-mono/blob/main/packages/coding-agent/docs/providers.md#resolution-order)):

1. `--api-key` CLI flag
2. `~/.pi/agent/auth.json` entry
3. Environment variable
4. The literal `apiKey` value in `models.json`

`auth.json` isn't limited to built-in providers — it's looked up by provider id, so a
`yunwu` entry works the same way `anthropic` or `openai` entries do for `/login`. It's
already gitignored and written with `0600` permissions, so this is the recommended spot
for the key instead of a shell-profile env var:

```json
// ~/.pi/agent/auth.json
{
  "yunwu": { "type": "api_key", "key": "sk-..." }
}
```

`key` supports the same resolution tricks as `models.json`'s `apiKey`: a literal, `"$ENV_VAR"`
interpolation, or a `"!command"` (e.g. `"!op read 'op://vault/item/yunwu'"` for a password
manager). If you'd rather use a plain env var instead, that still works too:

```bash
export YUNWU_API_KEY="sk-..."
```

### Adding another model to yunwu

Add an entry to the `models` array in `pi/agent/models.json`:

```json
{
  "id": "some-model-id",
  "name": "Some Model (Yunwu)",
  "reasoning": true,
  "input": ["text", "image"],
  "contextWindow": 200000,
  "maxTokens": 16384,
  "cost": { "input": 0, "output": 0, "cacheRead": 0, "cacheWrite": 0 }
}
```

Only `id` is strictly required — everything else has a default (see
[pi's models.json docs](https://github.com/badlogic/pi-mono/blob/main/packages/coding-agent/docs/models.md#model-configuration)).
The file reloads on `/model`, no restart needed. Confirm what's registered with:

```bash
pi --list-models yunwu
```

### Adding a second custom provider

Add another key under `providers` in `pi/agent/models.json`, same shape:

```json
{
  "providers": {
    "yunwu": { "...": "..." },
    "some-other-provider": {
      "name": "Some Other Provider",
      "baseUrl": "https://api.example.com/v1",
      "api": "openai-completions",
      "apiKey": "SOME_OTHER_API_KEY",
      "authHeader": true,
      "models": [{ "id": "model-id", "name": "Model (Some Other Provider)" }]
    }
  }
}
```

`api` can be `openai-completions`, `openai-responses`, `anthropic-messages`, or
`google-generative-ai` depending on what the provider actually speaks.

Built-in providers (Anthropic, OpenAI, etc.) still work as normal via `/login` or their
usual API key env vars; `models.json` only adds custom ones alongside them.

### abliteration.ai

OpenAI-compatible custom provider with two abliterated models:

- `baseUrl`: `https://api.abliteration.ai/v1`
- `apiKey`: `"$ABLIT_KEY"` — env-var interpolation; set `ABLIT_KEY=ak_...` in your shell
  (get the key at <https://abliteration.ai/console>). `auth.json` works the same way as
  for yunwu.
- `compat.sendSessionAffinityHeaders: true` — Pi sends `x-session-affinity` from the
  session id so abliteration can route requests to the same prompt-cache group. Don't
  hardcode a custom header; Pi derives a stable value per session.
- Models: `abliterated-model-large-v2` (text-only, 1M ctx) and `abliterated-model`
  (text+image, 262K ctx). Pick `Abliterated Model` when you need image input.

## Editing pi's own config (via pi itself, or by hand)

`~/.pi` is a symlink into this repo's `pi/` folder — not a copy. That means:

- If you ask pi to edit `AGENTS.md`, add a skill, write a prompt template, or run
  `pi config` to enable/disable a resource, it's writing directly into this git repo.
- Nothing auto-commits. Those changes just sit as an uncommitted diff in
  `C:\Users\jeppe\Documents\GitHub\pi-config` until you commit them.

Workflow: make changes (by hand or by asking pi), then check in on the repo periodically:

```bash
cd C:\Users\jeppe\Documents\GitHub\pi-config
git status
git diff
git add -A
git commit -m "..."
git push   # whenever you want to publish
```

There's a `/sync` prompt template (`pi/agent/prompts/sync.md`) that does the status/diff/
commit dance for you from inside a `pi` session — just run `/sync`. It reviews the diff,
summarizes it, and asks before committing; it never pushes on its own.

Because `pi/agent/sessions/`, `auth.json`, `pi/agent/bin/`, `pi/agent/npm/`, and
`pi/agent/git/` are all gitignored (see below), `git status` only surfaces changes to the
stuff actually worth versioning: `AGENTS.md`, `models.json`, `settings.json`, skills,
prompts, extensions, and themes.

## Installing packages

```bash
pi install npm:@foo/bar
pi install git:github.com/user/repo
```

`pi install` (without `-l`) writes an entry to the `packages` array in the **global**
`~/.pi/agent/settings.json` — which, via the symlink, is `pi/agent/settings.json` in this
repo. Unlike `auth.json`/`bin/`/session data, **`settings.json` is tracked**, specifically
so the package list travels with the repo: clone this on another machine, run
`install.ps1`/`install.sh`, start `pi`, and it installs any packages listed in
`settings.json` automatically.

The actual downloaded package code goes to `pi/agent/npm/` or `pi/agent/git/<host>/<path>`
— those are gitignored (same idea as `node_modules`); only the reference in `settings.json`
is committed.

`settings.json` also holds machine-ish bits like `theme` and `lastChangelogVersion` — those
will occasionally show up as noise in `git diff` when pi updates itself or you switch
themes. That's expected; just fold them into whatever commit you're already making.

```bash
pi remove npm:@foo/bar
pi list                # installed packages
pi update --extensions # update all non-pinned packages
pi config               # enable/disable resources from installed packages
```

See [pi's package docs](https://github.com/badlogic/pi-mono/blob/main/packages/coding-agent/docs/packages.md)
for the full reference (git/local sources, pinning versions/refs, package filtering, and
how to build your own package).

## Learning capability

Ported from [amosblomqvist/learn](https://github.com/amosblomqvist/learn) — a teaching
system built on pi: a skill that encodes a specific teaching philosophy, plus extensions
for interactive quizzes, popup questions, and a markdown session log. Ask pi to teach
you anything and it runs a **probe → plan → teach** loop instead of dumping facts.

### What was added

| Piece | Where | What it does |
| --- | --- | --- |
| `teach` skill | `pi/agent/skills/teach/` | Teaching philosophy: unconditional truths first, "how could I have discovered this?" motivation, quiz-check every node |
| `visualize` skill | `pi/agent/skills/visualize/` | Delegates diagrams to the maker subagents when a picture beats prose |
| `quiz` extension | `pi/agent/extensions/quiz.ts` | Graded multiple-choice popups (✓/✗, correct answer, explanation) |
| `ask-user-question` ext | `pi/agent/extensions/ask-user-question.ts` | Popup questionnaires — **replaces** the `@juicesharp/rpiv-ask-user-question` package (see below) |
| `md-log` extension | `pi/agent/extensions/md-log.ts` | Mirrors the session to a markdown file (Obsidian-friendly: LaTeX + mermaid render) |
| `visual-tools` extension | `pi/agent/extensions/visual-tools/` | write/edit/render tools for Mermaid and SVG subagents |
| `agents/` | `pi/agent/agents/` | `researcher` (web fact-checking), `mermaid-maker`, `svg-maker` |

### Using it

Nothing to enable — the skill is picked up automatically. Just ask:

```
teach me how the internet works
explain why TCP handshakes exist
walk me through how Merkle trees work
```

The `teach` skill runs its loop: **probe** your current level with `quiz` and your goal
with `ask_user_question`, **plan** a dependency map (drawn as a mermaid graph), then
**teach** node-by-node, quiz-checking each one so it actually locks in.

Optional session log — mirror the conversation to a markdown file you can read rendered
(Obsidian renders the LaTeX and mermaid in it):

```
/md-log <path-to-an-existing-note.md>   # link + backfill the current session
/md-unlog                               # stop logging
```

### Subagents: pi-sub-agent (works on Windows)

The `researcher` (fact-checking) and the two makers (diagrams) are **subagents** —
spawned by the [pi-sub-agent](https://pi.dev/packages/pi-sub-agent) package (already in
`settings.json`'s `packages`). It's multiplexer-free: each subagent is a child
`pi --mode json -p --no-session` process, so no tmux needed — works on Windows as-is.
It discovers the agents from `pi/agent/agents/` (same frontmatter format), and the
makers' custom tools (`write_mermaid`, `render_svg`, …) are registered by the
`visual-tools` extension, which child processes load automatically.

### Visuals: both mermaid and SVG render on Windows, no system tools needed

The npm deps are installed in `pi/agent/extensions/visual-tools/` (gitignored; re-run
`npm install` there on a fresh clone), and the renderer auto-detects system Chrome
(Windows + macOS paths, avoiding a puppeteer download).

- **mermaid** renders via `@mermaid-js/mermaid-cli` + Chrome.
- **SVG** renders via `rsvg-convert` (mac/Linux) → ImageMagick → **Chrome headless**
  as a universal fallback (Chrome is already a requirement, and it's the only one of
  the three that renders SVG text properly — ImageMagick's built-in MSVG delegate
  doesn't). So the `svg-maker` works out of the box here; no extra installs.

The maker renders, **looks at the PNG**, and publishes it to `<cwd>/viz/`; embed it
in the lesson log with `![[viz-<slug>.png|500]]`.

The agent definitions were repointed to this machine's models
(`deepseek/deepseek-v4-flash`, `deepseek-v4-flash-vision-exp`) since the author's
`openrouter/z-ai/glm-5.3` and `anthropic/claude-sonnet-5` aren't configured here.

### Note: `ask_user_question` provider swap

`settings.json` no longer lists `npm:@juicesharp/rpiv-ask-user-question`. The learn repo's
bundled `ask-user-question.ts` registers the same `ask_user_question` tool
(feature-equivalent: multiSelect, "Type something." row), and popups from different
implementations don't serialize through the same UI lock — so only one should be loaded.
To revert: add the package back to `settings.json`'s `packages` and delete
`pi/agent/extensions/ask-user-question.ts`.

## Prompt snippets

Mix-and-match single-purpose instruction snippets toggled onto a message before
sending. Reset to all-off after each send and at session start. Sourced from
amosblomqvist's [pi-config](https://github.com/amosblomqvist/pi-config) — files
live in `pi/agent/extensions/prompt-snippets/snippets/`, one markdown file per
snippet. Drop a new `.md` in there and it's in the menu on next `/reload`.

### Keybind

**`alt+s`** — opens the toggle menu. Same menu is reachable as `/snippets`.

In the menu: `↑`/`↓` navigate, `space` toggles, `tab` previews the highlighted
snippet, `enter` applies, `esc` cancels. Active snippets show as a widget above
the editor (`↑ prepend: …` in accent, `↓ append: …` in warning). When you send,
bodies are merged in `order`-sorted groups around your text and toggles reset.

### Snippet file format

```markdown
---
name: Concise
description: Keep answers short
placement: prepend
order: 10
---
Keep your response concise. Skip preamble and unnecessary explanation.
```

| Field | Required | Default |
| --- | --- | --- |
| `name` | no | filename without `.md` |
| `description` | no | shown in the menu |
| `placement` | no | `append` (`prepend` or `append`) |
| `order` | no | `9999` (lower sorts first within group) |

Files are re-scanned every time the menu opens — edits take effect immediately,
no `/reload` needed.

### Shipped snippets

| Snippet | Placement | Effect |
| --- | --- | --- |
| `ask-questions` | append | Clarify until shared understanding, then wait |
| `verify-not-assume` | append | Verify before acting; ask if you can't |
| `delegate-exploration` | append | Subagents read code, you verify critical parts |
| `diagnose-report` | append | Investigate only; report findings + proposed fix |
| `orchestrator-mode` | prepend | Outsource mechanical work; keep your context lean |
| `session-kickoff` | prepend | Orient first, report back, then wait for alignment |

## Observational memory

[pi-observational-memory](https://github.com/amosblomqvist/pi-observational-memory)
— tiered memory for long sessions. Parallel **observers** (subprocess `pi`
workers) distill raw conversation chunks into atomic observations; a
deterministic compaction block renders the buffer verbatim; a **consolidator**
promotes the oldest observations into durable `.memory/<sessionId>/` topic
files. Survives `/tree` and `/resume`.

### On/off (default OFF)

The extension ships gated off per session — completely invisible until you turn
it on.

- `/om` — toggle for this session
- `/om on` / `/om off` — set explicitly

State persists in the ledger and survives resume. When off, every trigger,
hook, widget, and subprocess returns immediately.

### Status & manual triggers

- `/om:status` — workers in flight, pool size, topic-file count, journey size, **session cost**
- `/om:compact` — force a compaction now (ignores threshold)
- `/om:consolidate` — force a consolidation now (ignores threshold)

### When to enable it

Long single-topic sessions: multi-day debugging, a CTF challenge with 50 turns
of recon, a security engagement across multiple hosts. Short, discrete
questions — leave it off. Observers fire every `chunkTokens` (default 10k) of
conversation, so the cost is real (visible in `/om:status`). The footer shows
the running total right of the gauges.

### Durable state

`.memory/<sessionId>/` lives in the project, keyed by the immutable session id
(set in the session header). Two sessions in the same project never share
output. A fork seeds its dir from the parent on first touch. **Not** rolled
back by `/tree` — memory persists across timeline jumps. Already in
`.gitignore` — per-machine, not shared across clones.

### Model config

Worker subprocesses (observers + consolidator) are configured in
`pi/agent/settings.json`:

```jsonc
"observational-memory": {
  "models": {
    "observer":     { "provider": "deepseek", "id": "deepseek-v4-flash", "thinking": "low" },
    "consolidator": { "provider": "deepseek", "id": "deepseek-v4-flash", "thinking": "medium" }
  }
}
```

Other knobs (`chunkTokens`, `poolTargetTokens`, `compactAtContextTokens`,
`tailTokens`, `journeyTargetTokens`, `observerConcurrency`, `passive`,
`debugLog`) live in the same block — see the
[upstream configuration reference](https://github.com/amosblomqvist/pi-observational-memory#configuration).

`PI_OM_PASSIVE=1` forces `passive` (disables all triggers) for clean `/tree`
testing. `passive` is a power-user setting distinct from the per-session
on/off gate.

## toilet-pi remote control

[toilet-pi](https://github.com/mrexodia/toilet-pi) lets you watch and control `pi`
sessions on this machine from a browser. It's vendored as a `pi` package (see
[Installing packages](#installing-packages) above) — committed in `settings.json`,
cloned by `pi` itself — and `install.ps1`/`install.sh` additionally register its
supervisor process as a Windows Scheduled Task / systemd `--user` service so it keeps
running in the background. See [docs/toilet-pi.md](docs/toilet-pi.md) for setup,
connecting a machine via `/toilet-pi setup <machine-url>`, and an important note about
treating the machine connect URL and server token as secrets.

## DaVinci Resolve MCP

Exposes DaVinci Resolve's scripting API (440+ tools: project/timeline/media-pool
management, color grading, Fusion compositing, rendering) via MCP, from
[lordhoell/davinci-resolve-mcp](https://github.com/lordhoell/davinci-resolve-mcp). Two halves:

- **Pi side** (committed, travels with the repo): `pi/agent/mcp.json`'s `davinci-resolve`
  entry, and the skill at `pi/agent/skills/davinci-resolve-mcp/` (copied from the repo's
  `skill/davinci-resolve-mcp/` — object registry pattern, workflow recipes, Fusion/render
  references).
- **Server side** (machine-local, NOT in the repo): the `davinci-resolve-mcp` Python
  package, installed into a local Python's site-packages, and DaVinci Resolve (Studio)
  itself.

### Setting up a new machine

1. **Find which Python `fusionscript.dll` actually links against.** Resolve's
   `fusionscript.dll` (`C:\Program Files\Blackmagic Design\DaVinci Resolve\fusionscript.dll`)
   is hard-linked to one specific Python minor version at install time (on this machine:
   **3.13**, matching whichever Python was registered/installed when Resolve set itself
   up) — it is *not* the generic "any Python >= 3.6" story the upstream docs imply.
   Loading it from a mismatched interpreter (e.g. 3.11 or 3.12 installed alongside)
   doesn't error cleanly — it **crashes the Python process with an access violation**
   (`0xc0000005`) the instant the DLL is loaded, regardless of PATH order, the "External
   scripting using" preference, or anything else. Confirm the right version by checking
   Windows Event Viewer → Application log after a crash for "Faulting module path" — it
   names the exact `pythonXXX.dll` Resolve's copy of fusionscript wants — then install
   for *that* Python.
2. **Install the server.** ⚠️ `pip install davinci-resolve-mcp` installs the *wrong*
   package — that name on PyPI belongs to an unrelated `filmcademy` project and will
   segfault on import regardless of Python version. Install lordhoell's version straight
   from GitHub instead, using the Python version identified in step 1:

   ```bash
   "<path-to-that-python>\python.exe" -m pip install "mcp[cli]<2" "git+https://github.com/lordhoell/davinci-resolve-mcp.git"
   ```

   The `mcp<2` pin is also required — the repo's `mcp[cli]>=1.0` dependency is too loose
   and pip will otherwise grab `mcp` 2.x, which renamed `FastMCP` and breaks the
   server's imports.
3. **Update `mcp.json`'s `command`** to the full path of the `davinci-resolve-mcp.exe`
   that install produced (`<that-python>\Scripts\davinci-resolve-mcp.exe`) — a bare
   command name is fragile across machines with multiple Pythons on PATH, and here it's
   flat-out wrong for every Python except the one matching fusionscript.dll.
4. DaVinci Resolve must already be running before the MCP server starts. (Also sanity
   check Preferences → System → General → "External scripting using" is `Local` or
   `Network`, though on this machine that wasn't the actual blocker — the Python
   version mismatch was.)
5. **Restart pi** and verify with `/mcp` or a proxy tool call.

## Cisco Packet Tracer MCP

Drives a running Cisco Packet Tracer (plan/validate/live-deploy topologies, ACL/NAT, raw
Script-Engine JS) via [Mats2208/MCP-Packet-Tracer](https://github.com/Mats2208/MCP-Packet-Tracer).
Two halves:

- **Pi side** (committed): `pi/agent/mcp.json`'s `packet-tracer` entry
  (`python -m packet_tracer_mcp --stdio`) and the skill at `pi/agent/skills/packet-tracer/`.
- **Machine side** (NOT in the repo): the `packet_tracer_mcp` Python package and the
  MCP Control Center extension loaded inside Packet Tracer (HTTP bridge on `:54321`).

### Setting up a new machine

1. Install the server per the upstream README so `python -c "import packet_tracer_mcp"`
   works for whichever `python` is first on PATH (or change `command` to a full path).
2. Load the bridge extension in Packet Tracer as described upstream.
3. **Restart pi** and verify with `/mcp` or `mcp({ search: "pt_" })`.

## x64dbg / x32dbg MCP debugger access

Exposes the x64dbg/x32dbg debuggers to pi via MCP so an agent can drive a debugging
session (breakpoints, registers, memory, disassembly). Two halves:

- **Pi side** (committed, travels with the repo): the `pi-mcp-adapter` package
  (already in `settings.json`'s `packages`) and `pi/agent/mcp.json`.
- **Debugger side** (machine-local, NOT in the repo): the `x64dbg-MCP-Server` plugin
  and its auto-generated `mcp_config.json` auth tokens.

### Committed config

`pi/agent/mcp.json` registers both servers:

```json
{
  "mcpServers": {
    "x64dbg": { "type": "http", "url": "http://localhost:9094/", "auth": "bearer", "bearerTokenStore": true },
    "x32dbg": { "type": "http", "url": "http://localhost:9095/", "auth": "bearer", "bearerTokenStore": true }
  }
}
```

No secrets here — tokens live in the OS credential store, bound to each server's URL
(`bearerTokenStore: true`). The adapter package auto-installs on first pi start from
the committed `settings.json` package list.

### Setting up a new machine

1. **Install the debugger plugin.** Copy the `x64dbg-MCP-Server` dist contents into the
   x64dbg root so `x64/plugins/x64dbg-MCP-Server.dp64` and
   `x32/plugins/x64dbg-MCP-Server.dp32` exist.
2. **Get the auth tokens.** On first launch the plugin writes `mcp_config.json` next to
   the binary (`release/x64/` and `release/x32/`):

   ```json
   { "IpAddress": "0.0.0.0", "Port": 9094, "AutoStart": true, "AuthToken": "32-hex-chars" }
   ```

   Ports: x64 = 9094, x32 = 9095. Either launch each debugger once and read the
   generated token, or pre-create the file with a fresh random one:

   ```bash
   node -e "console.log(require('crypto').randomBytes(16).toString('hex'))"
   ```

3. **Store each token** (the committed config reads it from the credential store):

   ```bash
   printf '%s' '<token>' | pi-mcp-adapter token set x64dbg
   printf '%s' '<token>' | pi-mcp-adapter token set x32dbg
   ```

   The token must match what the plugin wrote. If the plugin ever regenerates it (e.g.
   the config file gets deleted), re-run `token set`.
4. **Restart pi**, launch the debugger(s), verify with `/mcp` (panel) or by calling the
   proxy tool: `mcp({ search: "..." })`. Servers connect lazily on first tool call.

### CLI quirk: `token set` from a fresh clone

`pi-mcp-adapter token set` fails when run from inside `node_modules` — Node's type
stripping refuses `.ts` files under `node_modules` (also needs Node 22.18+). Run it
from a throwaway copy outside instead:

```bash
mkdir -p /tmp/pi-mcp-cli
cp -r <repo>/pi/agent/npm/node_modules/pi-mcp-adapter/* /tmp/pi-mcp-cli/
cd /tmp/pi-mcp-cli && npm install --omit=dev
printf '%s' '<token>' | node cli.js token set <server>
```

Stored records live in the OS credential store, so the copy is throwaway.

## Pushing to GitHub

This repo is initialized locally. To publish it:

```bash
gh repo create pi-config --private --source=. --remote=origin --push
# or, without gh:
git remote add origin git@github.com:<you>/pi-config.git
git branch -M main
git push -u origin main
```
