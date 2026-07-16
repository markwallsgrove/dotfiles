{ pkgs, username, ... }:

{
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  system.primaryUser = username;
  users.users.${username}.home = "/Users/${username}";

  system.keyboard.enableKeyMapping = true;
  system.keyboard.remapCapsLockToControl = true;

  # nix-darwin's own /etc/zprofile doesn't call macOS's path_helper, so
  # /etc/paths.d/homebrew (added by the Homebrew installer) is never read —
  # add its bin dirs to nix-darwin's own PATH construction instead.
  environment.systemPath = [ "/opt/homebrew/bin" "/opt/homebrew/sbin" ];

  # GUI/macOS-only apps that aren't packaged in nixpkgs: managed declaratively
  # here but still installed via `brew`. Run `brew bundle dump` first if you
  # already have other casks/taps installed that should be preserved.
  homebrew = {
    enable = true;
    onActivation = {
      autoUpdate = false;
      # "zap" would uninstall any cask/brew not listed below on every
      # `darwin-rebuild switch` — left off by default since that's destructive.
      cleanup = "none";
    };
    taps = [
      "nikitabobko/tap" # required for the aerospace cask below
    ];
    brews = [
      "openspec" # Spec-driven development CLI for AI coding assistants
    ];
    casks = [
      "1password-cli"
      "nikitabobko/tap/aerospace"
      "claude-code"
      "dbeaver-community"
      "ghostty"
      "headlamp" # Kubernetes UI: Electron GUI, not a CLI nixpkgs pkg
      "meetingbar"
      "obsidian" # Markdown knowledge base: GUI app, not a CLI nixpkgs pkg
      "orbstack" # Docker/Linux VM runtime: GUI app, replaces Docker Desktop/colima
      "tomatobar"
      "twingate" # Zero trust network access: GUI app, not a CLI nixpkgs pkg
    ];
  };

  # NOTE: verify against `sw_vers` / nix-darwin release notes on first
  # `darwin-rebuild switch` — this should match the value it suggests, not be
  # changed after the fact.
  system.stateVersion = 6;
  nixpkgs.hostPlatform = "aarch64-darwin";
}
