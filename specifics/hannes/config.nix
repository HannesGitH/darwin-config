{ pkgs, config,inputs,... }: {

  nixpkgs.overlays = [ inputs.prismLauncher.overlays.default ];

  environment.systemPackages = with pkgs; [
    prismlauncher
  ];

  sops.secrets = {
    "gpg.key" = {
      format = "binary";
      sopsFile = ./secrets/hannes/gpg.key;
      owner = "blingmember";
      mode = "0400";
      path = "/Users/blingmember/.gnupg/private-keys-v1.d/B36A4C516860D789671E2010E8A907F623EB6C32.key";
    };
  };

  homebrew = {
    enable = true;
    casks = [
      "displaylink"
    ];
  };
}