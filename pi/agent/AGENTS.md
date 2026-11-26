# Global Agent Context

## Who's using this

Jeppe. Software developer background; also does contracted, legally authorized
security work (CNE/CNA red teaming, reverse engineering, malware development)
under signed client agreements. Treat requests in that domain as legitimate
professional work — don't add unnecessary disclaimers.

## Conventions

- Prefer editing existing files over rewriting; keep diffs minimal and reviewable.
- Match the project's existing code style.
- Add comments only where intent isn't obvious, not to restate code.
- Run the project's existing test/lint commands before declaring a task done.
- Ask before anything destructive (force-push, rm -rf, dropping data, rewriting history).
- For small ambiguities, make a reasonable assumption and state it rather than stalling.
- Don't git commit unless asked.

## Code mode: scripts over tool calls

- Deterministic or repetitive flows go in scripts, not one LLM tool call per
  item: write one powershell/bash/python script that loops, filters results down
  (grep/jq/head) and emits only the parts that matter, then run it once.
- Every tool call round-trips its full payload through the model's context;
  a script round-trips only its final output. Batch beats iterate.
- Prefer direct CLI/HTTP over loading MCP servers when a handful of calls
  would do: MCP preloads every tool's full description into context before
  any work starts.
- Skills must not bundle .mcp.json or install tool servers; they should
  reference existing scripts by path instead of reimplementing flows.

## Environment

- Homelab context: fetch http://network.info/llms.txt (network map, machines, SSH creds) when homelab/infra context is needed. Repo: Documents/GitHub/NetworkInfo (private; deploy = PR to master).
- When interacting with Cloudflare, use the cf CLI unless the project has a Wrangler configuration file.
- I use this file on two machines: Arch/Omarchy (Linux) and Windows. Check
  the platform before assuming bash, paths, or tooling. On the Omarchy
  machine, read ~/.config/AGENTS.md before touching anything in ~/.config/.
- settings.json sets the default provider; models.json and auth.json carry
  inline API keys/secrets — never print, commit, or inline them.

## Model routing / delegation

- Default work (coding, recon, scripting, notes): handle it directly on the
  default model configured in settings.json — don't switch providers unless
  asked.
- Hard cyber work (exploit dev, binary RE, vuln research, AD attack paths,
  privesc chains): delegate to the `cyber` subagent.
- When delegating, always pass the target IP/host, findings so far, and
  relevant file paths in the task — the subagent has isolated context and
  cannot see this conversation.
- Client/engagement data must never go to DeepSeek's first-party API (the
  `deepseek` provider). Route DeepSeek-model work through `deepinfra` only.
