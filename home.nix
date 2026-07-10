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
    docker # CLI only — Docker Desktop/colima still needed for the daemon
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
