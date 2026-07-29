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
- `baseUrl`: `https://yunwu.ai/v1`
- `apiKey`: reads the `YUNWU_API_KEY` environment variable (pi resolves `apiKey` values as
  env var names, literal strings, or `!shell commands` — see
  [pi's models.json docs](https://github.com/badlogic/pi-mono/blob/main/packages/coding-agent/docs/models.md))
- `models`: currently just `claude-fable-5:floor`

Set the key in your shell profile before running `pi`:

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

## Pushing to GitHub

This repo is initialized locally. To publish it:

```bash
gh repo create pi-config --private --source=. --remote=origin --push
# or, without gh:
git remote add origin git@github.com:<you>/pi-config.git
git branch -M main
git push -u origin main
```
