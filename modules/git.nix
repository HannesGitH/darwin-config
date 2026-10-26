{
  config,
  lib,
  ...
}:

# Wires up the per-user merge tool for git, choosing between Zed and
# Cursor. The Zed binary is always `zed` regardless of
# `myModules.zed.channel` (modules/zed.nix renames nixpkgs' `zeditor`).
#
# `lib.getExe` resolves it by absolute store path. That avoids depending
# on the user's PATH inside the mergetool, which git's
# `git-mergetool--lib` scrubs.
#
# Zed still lacks 3-way merge editing
# (https://github.com/zed-industries/zed/issues/34813), which is why
# the zed entry only passes $MERGED instead of $REMOTE/$LOCAL/$BASE.

let
  inherit (lib) mkOption types;

  cfg = config.myModules.git;

  zedExe = lib.getExe config.programs.zed-editor.package;
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
        follows whichever package `myModules.zed.channel` selects.
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
        cmd = "${zedExe} --wait $MERGED";
        trustExitCode = true;
      };
      merge.tool = cfg.mergetool;
    };
  };
}
