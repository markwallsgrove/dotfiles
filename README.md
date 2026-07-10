# dotfiles

macOS system + home environment, managed with nix-darwin and home-manager.
Replaces stow (dotfile linking), brew (CLI packages), nvm/pyenv (toolchains).

## Layout

- `flake.nix` / `darwin-configuration.nix` — system-level config (Homebrew casks, keyboard, PATH).
- `home.nix` — home-manager config: dotfile symlinks, packages, tmux, secrets templating.
- `shell/`, `git/`, `vim/`, `config/`, `tmux/` — the actual dotfiles/config linked into `$HOME` by `home.nix`.
- `scripts/` — CLI helpers linked to `~/.local/bin`.
- `build`, `check`, `switch`, `validate` — entrypoint scripts (see below).

## Setup

Requires Nix with flakes enabled and an unlocked 1Password CLI session
(`op`, from the `1password-cli` cask — secrets templating needs it at
switch time).

## Workflow

- `./validate` — validate the flake (evaluation + flake-level checks).
- `./build` — dry-build the darwin system closure; no changes applied.
- `./check` — pre-commit-style gate: shellcheck/shfmt + `./validate` + `./build`.
- `./switch` — apply the config: installs packages, links dotfiles, runs
  activation (including the `op inject` secrets template).

## Secrets

`shell/secrets.tpl` holds `{{ op://vault/item/field }}` references only — no
secret material, safe to commit. `home.nix`'s activation step runs
`op inject` to render it to `~/.secrets` (mode 600) on every `./switch`.
