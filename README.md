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
`.gitignore`. If you need to seed the `yunwu` provider's key, set the `YUNWU_API_KEY`
environment variable instead — see [Providers](#providers) below.

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
- `baseUrl`: `https://api.yunwu.ai/v1`
- `apiKey`: reads the `YUNWU_API_KEY` environment variable (pi resolves `apiKey` values as
  env var names, literal strings, or `!shell commands` — see
  [pi's models.json docs](https://github.com/badlogic/pi-mono/blob/main/packages/coding-agent/docs/models.md))

Set it in your shell profile before running `pi`:

```bash
export YUNWU_API_KEY="sk-..."
```

The model list in `models.json` is a starting point — edit the `id`s to match whatever
models your yunwu account actually exposes, then confirm with:

```bash
pi --list-models yunwu
```

Built-in providers (Anthropic, OpenAI, etc.) still work as normal via `/login` or their
usual API key env vars; `models.json` only adds `yunwu` alongside them.

## Pushing to GitHub

This repo is initialized locally. To publish it:

```bash
gh repo create pi-config --private --source=. --remote=origin --push
# or, without gh:
git remote add origin git@github.com:<you>/pi-config.git
git branch -M main
git push -u origin main
```
