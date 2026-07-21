{ pkgs, ... }: {

  environment.systemPackages = with pkgs; [
    nodejs # 26.5.0+
  ];

  homebrew = {
    enable = true;
    casks = [
      "ngrok"
    ];
  };
}
