# Per-project opencode prompts

Copy `build.txt` and `plan.txt` into a project's `.opencode/prompts/` to override the global versions for that repo only. OpenCode resolves prompts with `{file:./prompts/build.txt}` from the directory of the active config — per-project configs read from the project's own `.opencode/`.

## Quick start

```sh
# from a project root
mkdir -p .opencode/prompts
cp ~/.config/opencode/.opencode/prompts/build.txt .opencode/prompts/
cp ~/.config/opencode/.opencode/prompts/plan.txt  .opencode/prompts/
```

Then edit the project-local copies to specialize them for that codebase (build/test commands, conventions, architecture notes).

## Prompt layering

- `~/.config/opencode/opencode.json` — global, all machines
- `~/.config/opencode/prompts/{build,plan}.txt` — global prompt bodies referenced by the global config
- `<project>/.opencode/prompts/{build,plan}.txt` — overrides for that repo
- `<project>/.opencode/opencode.json` — overrides for that repo's config

Project-local wins when present.
