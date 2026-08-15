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

## Environment

- Default model/provider lives in models.json (the yunwu provider).
- Secrets live in auth.json and env vars — never print, commit, or inline them.
