{ pkgs, config,inputs,... }: {

  nixpkgs.overlays = [ inputs.prismLauncher.overlays.default ];

  environment.systemPackages = with pkgs; [
    prismlauncher
  ];

  homebrew = {
    enable = true;
    casks = [
      "displaylink"
    ];
  };
}