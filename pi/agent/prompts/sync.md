Run `git -C "C:\Users\jeppe\Documents\GitHub\pi-config" status --porcelain` and
`git -C "C:\Users\jeppe\Documents\GitHub\pi-config" diff` via the bash tool.

Show me a concise summary of what changed (new/removed skills, prompts, extensions,
themes, or edits to AGENTS.md / models.json / settings.json). Ignore anything under
pi/agent/npm/, pi/agent/git/, pi/agent/bin/, pi/agent/sessions/, or auth.json — those
are gitignored and shouldn't show up anyway.

If there are changes and I confirm, stage everything with `git add -A` and commit with
a short, accurate message describing what changed. Don't push unless I explicitly ask.
