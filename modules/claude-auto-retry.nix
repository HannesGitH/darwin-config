{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

# Home-manager module that installs claude-auto-retry and declares its `claude`
# shell function. Imported from global/home.nix; configure via
# `myModules.claude-auto-retry.*`.
#
# Why this exists as a module at all: upstream's `claude-auto-retry install`
# injects the shell function by *writing to* `~/.zshrc`, which here is a
# read-only symlink into the store (home-manager owns it), so the installer
# dies with EACCES. The function is not optional -- it is the whole mechanism,
# the thing that launches `claude` inside tmux so a monitor can outlive a
# dropped connection -- so it has to be declared instead of injected. Never
# run `claude-auto-retry install` on this machine; it has nothing to add that
# this module does not already do, and it cannot succeed.
#
# The complementary `StopFailure` hook is deliberately *not* managed here: it
# lives in `~/.claude/settings.json`, which is hand-maintained (and rewritten
# by Claude Code itself), so home-manager has no business owning that file.
# Install it once, imperatively, per config dir:
#
#   claude-auto-retry install-hook
#
# It swaps terminal-scrollback scraping for an event Claude Code fires
# directly, so a session can no longer false-positive on the word
# "overloaded" appearing in code or output.

let
  inherit (lib)
    mkEnableOption
    mkIf
    mkOption
    types
    ;

  cfg = config.myModules.claude-auto-retry;

  src = inputs.claude-auto-retry;

  template = builtins.readFile "${src}/src/wrapper.sh";

  # Upstream's template calls `node "__LAUNCHER_PATH__"`, relying on both
  # being on the interactive PATH. Point it at the packaged shim instead,
  # which carries node and tmux by store path (see pkgs/claude-auto-retry).
  bareNodeCall = ''node "__LAUNCHER_PATH__"'';
  launchExe = "${cfg.package}/bin/claude-auto-retry-launch";

  # A silent no-op substitution would leave a wrapper that calls a `node`
  # which is not there, and the failure would only show up the next time the
  # user typed `claude`. Fail the build instead.
  checkedTemplate =
    assert lib.assertMsg (lib.hasInfix bareNodeCall template) ''
      claude-auto-retry: upstream src/wrapper.sh no longer contains
      ${bareNodeCall}, so the launcher shim cannot be substituted in.
      Re-read the template and update modules/claude-auto-retry.nix.
    '';
    template;

  # Order matters: `bareNodeCall` contains `__LAUNCHER_PATH__`, so it has to be
  # tried first at each position. `replaceStrings` matches patterns in list
  # order, so listing the longer one first consumes it before the bare
  # placeholder pattern (which still covers the wrapper's `-e` existence
  # check) gets a look at it.
  wrapperFunction =
    builtins.replaceStrings [ bareNodeCall "__LAUNCHER_PATH__" ] [ ''"${launchExe}"'' launchExe ]
      checkedTemplate;
in
{
  options.myModules.claude-auto-retry = {
    enable = mkEnableOption ''
      claude-auto-retry: a `claude` zsh function that runs Claude Code inside
      tmux with a background monitor, so a subscription rate limit or an API
      overload suspends the session instead of killing it
    '';

    package = mkOption {
      type = types.package;
      default = pkgs.callPackage ./pkgs/claude-auto-retry { inherit src; };
      defaultText = lib.literalExpression "pkgs.callPackage ./pkgs/claude-auto-retry { }";
      description = ''
        The claude-auto-retry package. Also provides the `claude-auto-retry`
        CLI (`install-hook`, `reconcile`, `status`, `logs`) and the
        `claude-auto-retry-tmux-status` status-line segment.
      '';
    };
  };

  config = mkIf cfg.enable {
    # tmux is on the list for the human, not for the tool: the package's own
    # entrypoints already carry it by store path, but the whole point of this
    # module is that a session outlives its terminal -- and reattaching to one
    # (`tmux attach -t <session>`, `tmux ls`) needs tmux on an interactive
    # PATH. Without it the sessions survive somewhere you cannot reach them.
    home.packages = [
      cfg.package
      pkgs.tmux
    ];

    # mkAfter, because the function opens by dropping any pre-existing
    # `claude` alias -- zsh expands an alias while *parsing* `claude() {`, so
    # a later alias definition would turn sourcing .zshrc into a syntax error.
    programs.zsh.initContent = lib.mkAfter wrapperFunction;
  };
}
