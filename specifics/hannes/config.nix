{ pkgs, inputs,... }: {

  nixpkgs.overlays = [ inputs.prismLauncher.overlays.default ];

  environment.systemPackages = with pkgs; [
    prismlauncher
  ];
}