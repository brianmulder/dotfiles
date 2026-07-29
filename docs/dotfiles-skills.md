# Dotfiles-managed agent skills

The public dotfiles repository owns the portable management mechanism. It does
not declare which skills are used. Desired subscriptions, private skills, and
host profiles live in independently configured private source repositories.

The command requires Python 3.11 or newer, or Python 3.10 with `tomli`.

## State layout

- configuration: `${XDG_CONFIG_HOME:-~/.config}/dotfiles-skills/`
- source descriptors: `sources.d/*.toml`
- generated packages: `${XDG_DATA_HOME:-~/.local/share}/dotfiles-skills/build/`
- deployment receipts: `${XDG_STATE_HOME:-~/.local/state}/dotfiles-skills/deployments.json`

On native Windows the same directories live beneath `%USERPROFILE%`.

## Private source contract

Register a checked-out private composition repository locally:

```bash
dotfiles-skills source add private \
  --path "$HOME/code/private/skills-estate" \
  --profile wsl \
  --frozen
```

This writes only to the host-local XDG configuration. The source URL, profile,
and subscribed skill names never enter the public dotfiles repository.

The source repository contains `estate.toml`, skill packages, and a generated
`skills.lock.json`:

```toml
version = 1

[profiles.wsl]
targets = ["codex", "claude-code"]
skills = ["example-skill"]

[skills.example-skill]
path = "skills/example-skill"
targets = ["codex", "claude-code"]
```

Profiles may override target roots:

```toml
[profiles.vps.target_paths]
codex = ["{home}/.codex/skills"]
claude-code = ["{home}/.claude/skills"]
openclaw = [
  "{home}/.agents/skills",
  "{home}/.openclaw/workspace-agent/skills",
]
```

## Workflow

```bash
dotfiles-skills lock        # update private content hashes intentionally
dotfiles-skills plan        # read-only proposed changes
dotfiles-skills adopt       # take ownership of byte-identical existing packages
dotfiles-skills apply       # refuse unmanaged collisions, then project consumers
dotfiles-skills doctor      # compare desired, locked, built, and deployed state
```

Codex receives portable frontmatter only. Claude Code retains Claude invocation
metadata. OpenClaw consumers are copied rather than linked so runtime-side edits
show up as drift instead of mutating canonical source. Unix Codex/Claude
consumers are links into the generated store; native Windows uses managed copies.

The manager never removes or replaces an unmanaged destination. `adopt` is a
one-time migration command: it records ownership only when every colliding
package is byte-identical to its declared source, and otherwise changes nothing.
