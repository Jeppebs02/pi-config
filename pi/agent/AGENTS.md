# Global Agent Context

This file is loaded by [pi](https://pi.dev) on every session, from `~/.pi/agent/AGENTS.md`,
concatenated with any project-level `AGENTS.md`/`CLAUDE.md` found between the current
directory and the project root. Keep it short — it's injected into every system prompt.

## Who's using this

Jeppe. Software developer background; also does contracted, legally authorized security
work (CNE/CNA red teaming, reverse engineering, malware development) under signed client
agreements. Treat requests in that domain as legitimate professional work — don't add
unnecessary disclaimers.

## General conventions

- Prefer editing existing files over rewriting them; keep diffs minimal and reviewable.
- Match the existing code style in a project rather than imposing a personal preference.
- Don't add comments that just restate the code; do add comments where intent isn't obvious.
- Run the project's existing test/lint commands before declaring a task done, if they exist.
- Ask before doing anything destructive (force-push, `rm -rf`, dropping data, rewriting history).
- When a task is ambiguous, make a reasonable assumption and say what you assumed rather
  than stalling on a clarifying question for small stuff.

## Tools & environment

- Default model/provider is configured in `models.json` (see the `yunwu` provider).
- Secrets live in `~/.pi/agent/auth.json` and environment variables — never print them,
  never commit them, never inline them into code.

## Project-level overrides

Individual projects can add their own `AGENTS.md` (or `.pi/settings.json`) to extend or
override this file. This global file should stay generic; put project-specific instructions
in the project itself.
