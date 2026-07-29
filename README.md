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
│       ├── skills/        # global skills (Agent Skills standard)
│       ├── prompts/       # global prompt templates (/name to expand)
│       ├── extensions/    # global TypeScript extensions
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

**Windows (PowerShell)**

Symlinks require Developer Mode (Settings → Update & Security → For developers) or an
elevated (Administrator) shell.

```powershell
git clone <this-repo-url> $HOME\pi-config
cd $HOME\pi-config
.\install.ps1
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

## Pushing to GitHub

This repo is initialized locally. To publish it:

```bash
gh repo create pi-config --private --source=. --remote=origin --push
# or, without gh:
git remote add origin git@github.com:<you>/pi-config.git
git branch -M main
git push -u origin main
```
