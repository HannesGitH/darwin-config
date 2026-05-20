{
  config,
  lib,
  ...
}:

# Wires up the per-user merge tool for git, choosing between Zed and
# Cursor and -- when Zed is selected -- routing to the right binary
# based on `myModules.zed.channel`:
#
# - nixpkgs `zed-editor` ships its CLI as `zeditor` to dodge the ncurses
#   `zed` name collision, so the `unstable` channel needs to invoke
#   `zeditor --wait $MERGED`.
# - The upstream `zed-industries/zed` flake exposes the same editor with
#   its native `zed` CLI name, so the `nightly` channel uses that.
#
# Zed still lacks 3-way merge editing
# (https://github.com/zed-industries/zed/issues/34813), which is why
# the zed entry only passes $MERGED instead of $REMOTE/$LOCAL/$BASE.

let
  inherit (lib) mkOption types;

  cfg = config.myModules.git;

  zedBin = if config.myModules.zed.channel == "nightly" then "zed" else "zeditor";
in
{
  options.myModules.git = {
    mergetool = mkOption {
      type = types.enum [
        "zed"
        "cursor"
        "vscode"
      ];
      default = "zed";
      description = ''
        Which editor `git mergetool` should launch by default. `zed`
        follows whichever package `myModules.zed.channel` selects
        (the binary is `zed` on `nightly`, `zeditor` on `unstable`).
        `cursor` and `vscode` invoke the respective CLIs and require
        those tools to be on PATH.
      '';
    };
  };

  config = {
    programs.git.settings = {
      "mergetool \"vscode\"" = {
        cmd = "code --wait --merge $REMOTE $LOCAL $BASE $MERGED";
        trustExitCode = true;
      };
      "mergetool \"cursor\"" = {
        cmd = "cursor --wait --merge $REMOTE $LOCAL $BASE $MERGED";
        trustExitCode = true;
      };
      "mergetool \"zed\"" = {
        cmd = "${zedBin} --wait $MERGED";
        trustExitCode = true;
      };
      merge.tool = cfg.mergetool;
    };
  };
}
