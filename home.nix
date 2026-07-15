{ config, pkgs, lib, ... }:
let
  # nixpkgs' own test suite for opa is broken on this revision
  # (v1/server/compile_handler_test.go references an undefined `fixture`,
  # unrelated to our config) — skip checkPhase, keep everything else as-is.
  opa = pkgs.open-policy-agent.overrideAttrs (_: { doCheck = false; });
in
{
  home.stateVersion = "24.11";
  home.username = "mark";
  home.homeDirectory = "/Users/mark";
  # --- dotfile linking: replaces `stow .` ------------------------------
  # recursive = true so only files tracked here become symlinks; anything
  # else already in ~/.config or ~/.local/bin is left alone (stow behaved
  # the same way via .stow-local-ignore).
  home.file = {
    ".aliases".source = ./shell/aliases;
    ".exports".source = ./shell/exports;
    ".funcs".source = ./shell/funcs;
    ".gitconfig".source = ./git/gitconfig;
    ".vimrc".source = ./vim/vimrc;
    ".zshrc".source = ./shell/zshrc;
    ".claude" = {
      source = ./.claude;
      recursive = true;
    };
  };
  xdg.configFile = {
    "nvim" = {
      source = ./config/nvim;
      recursive = true;
    };
    "kitty" = {
      source = ./config/kitty;
      recursive = true;
    };
    "ghostty" = {
      source = ./config/ghostty;
      recursive = true;
    };
  };
  home.file.".local/bin" = {
    source = ./scripts;
    recursive = true;
  };
  # --- tmux: plugins managed by Nix instead of TPM/git clones ----------
  # `programs.tmux` writes ~/.config/tmux/tmux.conf itself: tmuxConf, then
  # each plugin's extraConfig + run-shell (in list order), then extraConfig.
  # Catppuccin's options must be set before the plugin sources itself, so
  # they live in its extraConfig rather than in tmux/tmux.conf.
  programs.tmux = {
    enable = true;
    plugins = with pkgs.tmuxPlugins; [
      sensible
      {
        plugin = catppuccin;
        extraConfig = ''
          set -g @catppuccin_flavor 'mocha'
          set -g @catppuccin_session_icon ""
          set -g @catppuccin_window_status_style "basic"
          set -g @catppuccin_window_number_position "right"
          set -g @catppuccin_window_text "#W"
          set -g @catppuccin_window_current_text "#W"
        '';
      }
    ];
    extraConfig = builtins.readFile ./tmux/tmux.conf;
  };
  # --- herdr: terminal workspace manager, themed/keyed to match tmux -----
  # Only tmux bindings with a real herdr equivalent are ported. Bindings
  # that shell out to tmux-coupled scripts (tmux-sessionizer, gwts,
  # tmux-claude-*, tmux-fzf-processes, tmux-task-*, tmux-snippets, the
  # session-name branch paste) are NOT ported: those scripts call tmux
  # directly (display-popup, send-keys, #{pane_current_path}) and won't
  # work against herdr's socket API without a rewrite. herdr's own
  # prefix+? help overlay replaces tmux-help natively.
  programs.herdr = {
    enable = true;
    settings = {
      theme.name = "catppuccin"; # matches tmux's catppuccin mocha flavor
      keys = {
        prefix = "ctrl+a"; # matches tmux's remapped C-a prefix
        # splits: herdr names the action after the split *line's* orientation,
        # tmux names it after the resulting pane *arrangement* — inverted.
        # herdr's split_vertical (Direction::Horizontal, side-by-side result)
        # is tmux's `\` (split-window -h); split_horizontal (Direction::Vertical,
        # stacked result) already defaults to "-", matching tmux's `-` unchanged.
        # Verified against herdr src/app/input/navigate.rs, not assumed.
        split_vertical = [ "prefix+v" "prefix+backslash" ];
        # pane focus: tmux's built-in prefix+arrow default (verified via
        # `tmux list-keys -T prefix`), its -n M-arrow binding, and herdr's
        # own vim-key defaults — all coexist
        focus_pane_left = [ "prefix+h" "prefix+left" "alt+left" ];
        focus_pane_down = [ "prefix+j" "prefix+down" "alt+down" ];
        focus_pane_up = [ "prefix+k" "prefix+up" "alt+up" ];
        focus_pane_right = [ "prefix+l" "prefix+right" "alt+right" ];
        # git worktrees: native equivalent of tmux's C-g (gwts) / C-n (tmux-new-branch)
        new_worktree = [ "prefix+shift+g" "ctrl+n" ];
        open_worktree = [ "prefix+shift+o" "ctrl+g" ];
        remove_worktree = "prefix+alt+d";
        # jump to the agent pane needing attention: native equiv. of tmux-claude-next (C-e)
        open_notification_target = "ctrl+e";
        # jump to a specific agent pane: native equiv. of tmux-claude-finder (C-j), indexed only
        focus_agent = "prefix+alt+1..9";
        # quick jump: closest native equivalent of tmux-sessionizer (C-f); not project-scanning
        goto = [ "prefix+g" "ctrl+f" ];
        # kill session: native equiv. of tmux-session-kill (C-x)
        close_workspace = [ "prefix+shift+d" "ctrl+x" ];
        command = [{
          key = "prefix+shift+r";
          type = "shell";
          command = "herdr server reload-config";
          description = "reload config"; # matches tmux's prefix+r config reload
        }];
      };
    };
  };
  # bat's binary is just `bat` on Nix (already in home.packages below) —
  # `batcat` is a Debian/Ubuntu-only rename, so alias it for muscle memory.
  home.shellAliases = {
    batcat = "bat";
  };
  # --- packages: replaces `brew install ...` ---------------------------
  # Mapped from https://gist.github.com/markwallsgrove/9a5b29215d45ec55ae829b7c7335f331
  # every attr name below has been confirmed with `nix build` against this
  # flake's pinned nixpkgs revision.
  home.packages = with pkgs; [
    # Shell / CLI
    bash fzf zoxide eza bat fd ripgrep entr tree
    # Git
    git git-absorb git-fixup git-lfs git-workspace
    # Languages / toolchains (replaces nvm + pyenv — versions pinned by
    # nixpkgs revision instead of a version manager)
    go
    rustc cargo
    nodejs_22
    python314 # was python@3.14; mise's 3.12 pin dropped, standardizing on 3.14
    dotnet-sdk_8
    # mise itself: not used for this machine's own toolchains (pinned above),
    # but other checked-out repos still ship .mise.toml/.tool-versions
    mise
    # Kubernetes
    kubectl # was kubernetes-cli
    kubernetes-helm # was helm
    argocd stern mirrord
    opa # overridden above: doCheck disabled, see `let`
    k3d k9s krew chart-testing helm-docs
    # AWS
    aws-sso-util
    amazon-ecr-credential-helper # was docker-credential-helper-ecr
    # Databases
    postgresql_16 # psql + pg_dump/restore client (no server daemon needed here)
    # Buf / Protobuf
    buf protobuf
    # CI
    circleci-cli # was circleci
    # Networking / load testing
    grpcurl socat natscli oha vegeta
    # Other CLI
    gh
    jira-cli-go # was jira-cli
    yq-go # was yq
    jq shellcheck shfmt neovim btop htop
    stu exercism
    docker # CLI only — OrbStack (brew cask) provides the daemon
    # was mise-managed
    awscli2 checkmake gitleaks poetry pre-commit prek
    # npm-global replacements
    pnpm # corepack ships with nodejs_22, no separate package needed
    # pip-global replacements
    pyright ruff nodeenv
    claude-code
  ];
  # --- not packaged in nixpkgs: install like today via activation -----
  # npm's default global prefix is inside the nodejs derivation itself, which
  # is read-only in the nix store — point it at a writable dir in $HOME instead.
  home.sessionPath = [ "$HOME/.npm-global/bin" ];
  home.activation.globalToolInstalls = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    run mkdir -p "$HOME/.npm-global"
    run ${pkgs.bash}/bin/bash -c ${pkgs.lib.escapeShellArg ''PATH="${pkgs.nodejs_22}/bin:$PATH" ${pkgs.nodejs_22}/bin/npm install -g --prefix "$HOME/.npm-global" @fission-ai/openspec''}
  '';
  # --- MeetingBar: declarative prefs (cask installed in darwin-configuration.nix) --
  # Only portable settings go here — selectedCalendarIDs are EventKit UUIDs
  # generated per-machine (invalid on a fresh install) and `browsers` just
  # mirrors what MeetingBar auto-detects, so both are left for the app to
  # regenerate rather than hardcoded.
  home.activation.meetingBarDefaults = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    run /usr/bin/defaults write leits.MeetingBar eventStoreProvider -string "MacOS Calendar App"
    run /usr/bin/defaults write leits.MeetingBar joinEventNotificationTime -int 60
    run /usr/bin/defaults write leits.MeetingBar fullscreenNotification -bool true
    run /usr/bin/defaults write leits.MeetingBar fullscreenNotificationTime -int 5
  '';
  # --- ~/.secrets: templated from shell/secrets.tpl via `op inject` ----
  # secrets.tpl holds `{{ op://vault/item/field }}` refs, no secret material —
  # safe to commit. `op` comes from the 1password-cli brew cask (not nixpkgs),
  # so it's not on the Nix-built PATH; requires an unlocked op session at
  # switch time (Touch ID prompt via the 1Password app integration).
  home.activation.secretsTemplate = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    run ${pkgs.bash}/bin/bash -c ${pkgs.lib.escapeShellArg ''
      PATH="/opt/homebrew/bin:$PATH" op inject -i ${./shell/secrets.tpl} -o "$HOME/.secrets"
      chmod 600 "$HOME/.secrets"
    ''}
  '';
}
