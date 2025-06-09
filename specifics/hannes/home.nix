{ config, pkgs, ... }:

{
    programs.git = {
      userName = "Hannes";
      userEmail = "33062605+HannesGitH@users.noreply.github.com";

      extraConfig = {
        commit.gpgsign = true;
        user.signingkey = "418631D259CF0368999E14E35339BFCE9A05036C";
      };
    };
}