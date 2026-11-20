# Antigravity (`agy` CLI & App) Configuration

This directory manages the declarative, blocklist-based Antigravity setup across both the **Antigravity CLI (`agy`)** and the **Antigravity App/IDE**.

## How the Files Fit Together

| File in `dotfiles/gemini/` | How it is loaded | Scope | Purpose |
| :--- | :--- | :--- | :--- |
| `antigravity-cli/settings.json` | Passed via `agy --settings` alias in `dotfiles/bash/bashrc` | `agy` CLI | Session-only declarative policy (`toolPermission`, `agentMode`, `permissions`, `editorMode`). Never saved back by `agy`. |
| `config/config.json` | Symlinked to `~/.gemini/config/config.json` by `home.nix` (`force = true`) | App/IDE & shared global settings | Global preset (`AGENT_PERMISSION_PRESET_TURBO`), plugins (`swarm`), and `globalPermissionGrants` mirroring CLI `permissions`. |
| `config/hooks.json` | Symlinked to `~/.gemini/config/hooks.json` by `home.nix` | Both CLI & App | Registers the `PreToolUse` `block-secrets` hook using an absolute path to `block-secrets.py`. |
| `config/hooks/block-secrets.py` | Symlinked via `~/.gemini/config/hooks` by `home.nix` | Both CLI & App | Inspects file/search/shell tool calls to block relative/workspace `.env` files, private keys, and credential paths (while allowing `.env.example`/`.sample`/`.template`/`.dist`). |

### Why `antigravity-cli/settings.json` is NOT symlinked
`agy` atomically rewrites `~/.gemini/antigravity-cli/settings.json` whenever you switch models or accept a workspace trust prompt—replacing symlinks with regular files and resetting `trustedWorkspaces` on rebuilds.

To avoid that:
- `~/.gemini/antigravity-cli/settings.json` stays a **local, mutable file** owned by `agy` (storing `model` and `trustedWorkspaces`).
- `dotfiles/bash/bashrc` aliases `agy` to pass `--settings "$HOME/nixos-conf/dotfiles/gemini/antigravity-cli/settings.json"`, overlaying the declarative policy on every session without mutating the local file.

> **Gotcha:** Do **not** add `$schema`, `model`, or `trustedWorkspaces` to `antigravity-cli/settings.json`. `agy --settings` rejects `$schema` as an unknown key, and `model`/`trustedWorkspaces` belong in the local mutable file.

## Permission Model & NixOS Notes

- **Blocklist approach:** Routine operations run without prompting (`toolPermission: "always-proceed"` / `AGENT_PERMISSION_PRESET_TURBO` + broad `allow` wildcards). Antigravity always enforces **`Deny > Ask > Allow`** on top of presets.
- **Why the terminal sandbox is disabled (`enableTerminalSandbox: false`):** On NixOS, Antigravity's `bwrap` sandbox lacks full `/nix/store` + profile mounts, causing basic utilities (`ls`, `find`) to fail with exit code 127. Safety is enforced through explicit `deny`/`ask` rules and `PreToolUse` hooks instead.
- **Policy summary:**
  - **`allow`**: All routine file reads/writes (including non-workspace paths), shell commands, web access, and MCP tools.
  - **`ask`**: Writing to agent config directories/files (`opencode`, `gemini`, `hermes`). Reading/diffing them never prompts.
  - **`deny`**:
    - Secrets & credentials (`.ssh`, `.hermes/.env`, `.aws/credentials`, `.kube/config`, `.docker/config.json`, `sops/age`, `/var/lib/sops-nix`, `/run/secrets`, plus workspace `.env` and private keys via `block-secrets.py`).
    - Privilege escalation (`sudo`, `doas`, `pkexec`, `su`).
    - Destructive/remote git (`git push`, `git reset --hard`, `git clean`; soft/mixed `git reset` stays allowed).
    - Catastrophic / active-system mutations (`rm -rf /` or `~`, `mkfs.*`, `dd`, `nixos-rebuild switch|boot`; `nixos-rebuild test` and dry-runs stay allowed).

## Rule Maintenance Gotchas

1. **Keep `antigravity-cli/settings.json` and `config/config.json` in sync** when editing `allow`/`ask`/`deny` rules (both files keep the same `allow` → `ask` → `deny` order for easy diffing).
2. **`read_file(...)` / `write_file(...)` rules must use absolute paths**—relative paths like `read_file(.env)` cause Antigravity to fail command execution with a non-absolute path error. Relative secret paths are handled by `config/hooks/block-secrets.py`.
3. **`command(regex:...)` evaluates per token:** each whitespace-separated token in the pattern is matched as an anchored regex `^(?:pattern)$`.
4. **Keep the `.json` files strict JSON** (no `//` comments or `_comment` keys—`agy --settings` rejects unknown keys).

## Headless & Delegated Use

`agy -p` is how scripts, cron jobs, and other agents drive this setup. Two properties of the alias matter there:

- **The `bashrc` alias does not apply.** Aliases only exist in interactive shells, so a script or another agent's `terminal(...)` call resolves the bare binary and loads only the local mutable `~/.gemini/antigravity-cli/settings.json`. That file carries `toolPermission: "always-proceed"` and the broad `allow` wildcards but **no `ask` block**, so agent-config writes are *not* gated and `enableTerminalSandbox` may be absent. Pass the policy explicitly on every delegated call:

  ```sh
  agy -p '<task>' --model <slug> \
      --settings "$HOME/nixos-conf/dotfiles/gemini/antigravity-cli/settings.json" \
      --print-timeout 180s --output-format json
  ```

- **Nothing can answer a prompt headless.** An `ask` match is never shown to anyone, so the call is blocked. A `deny` match (or a `block-secrets.py` hook denial) still exits 0 with `status: SUCCESS`, an empty or `DENIED` `response`, and a `denied_actions` array in the envelope. Callers must inspect `status`/`denied_actions`, not the exit code.

Verified against this configuration (`agy` 1.5.6):

| Behaviour | Result |
| :--- | :--- |
| Unlisted shell command (`python3 -m unittest discover`) | runs, no prompt |
| Write outside the workspace (`/tmp/...`) | allowed (`allowNonWorkspaceAccess: true`) |
| Read a canary `*.pem` | denied silently by `block-secrets.py` (`SUCCESS` + `DENIED`) |
| Multi-file edit + test run in one turn | 3 files changed, tests green, 12–21 s |
| Three concurrent `agy -p` runs in separate directories | 17–20 s each, no cross-talk |
| `--json-schema` report | `structured_output` filled correctly |
| `--conversation <id>` follow-up edit | context retained (input tokens roughly double) |

One quirk when steering: on a resumed conversation `structured_output` can echo the *previous* turn's object, so re-pass `--json-schema` and read the answer from `response`.
