{
  description = "darwin config for bling";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-darwin.url = "github:LnL7/nix-darwin";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
    
    nix-index-database.url = "github:nix-community/nix-index-database";
    nix-index-database.inputs.nixpkgs.follows = "nixpkgs";

    home-manager.url = "github:nix-community/home-manager";

    prismLauncher.url = "github:HannesGitH/prismlauncherc";
    nix-search-cli.url = "github:peterldowns/nix-search-cli";
    mergiraf.url = "git+ssh://git@codeberg.org/HannesGitH/mergiraf";

    # secrets management
    sops-nix.url = "github:Mic92/sops-nix";
  };

  outputs = inputs@{ self, nix-darwin, nixpkgs, home-manager, ... }:
  let name = "maccaroni"; 
  in 
  let
    configuration = { pkgs, ... }: {

      ids.gids.nixbld = 350;

      nixpkgs.config.allowUnfree = true;

      environment.variables.LANG = "en_GB.UTF-8";

      nixpkgs.overlays = [ inputs.prismLauncher.overlays.default ];
      # List packages installed in system profile. To search by name, run:
      # $ nix-env -qaP | grep wget
      environment.systemPackages = with pkgs;
        [ 
          libiconv
          libiconv-darwin
          git
          git-lfs
          rename
          nil
          autojump
          go
          prismlauncher
          inputs.nix-search-cli.packages.${pkgs.system}.default
          gimp
          bundletool
          gnupg

          (inputs.mergiraf.packages.${pkgs.system}.default.overrideAttrs (old: { doCheck = false; doInstallCheck = false; }))
        ];

      system.activationScripts.extraActivation.text = ''
        ln -sf "${pkgs.jdk8}/zulu-8.jdk" "/Library/Java/JavaVirtualMachines/"
        ln -sf "${pkgs.jdk11}/zulu-11.jdk" "/Library/Java/JavaVirtualMachines/"
        ln -sf "${pkgs.jdk17}/zulu-17.jdk" "/Library/Java/JavaVirtualMachines/"
        ln -sf "${pkgs.jdk21}/zulu-21.jdk" "/Library/Java/JavaVirtualMachines/"
      '';

      programs.nix-index-database.comma.enable = true;


      homebrew = {
          enable = true;
          # onActivation.cleanup = "uninstall";

          taps = [ "leoafarias/fvm"  ];
          brews = [ 
            "fvm" 
            # "cocoapods" #!# /opt/homebrew/Cellar/cocoapods/1.15.2_1/libexec/bin/pod: /opt/homebrew/opt/ruby/bin/ruby: bad interpreter seems like it didnt find ruby where it thought it would be
            "gh" 
            # "ruby" 
            # "font-fira-code"
            "wireshark"
          ];
          casks = [
            "displaylink"
            "raycast"
            "visual-studio-code"
            "darktable"
          ];
      };

      nix.extraOptions = ''
        extra-platforms = x86_64-darwin aarch64-darwin
        sandbox = false
      '';


      # Auto upgrade nix package and the daemon service.
      nix.enable = true;
      # nix.package = pkgs.nix;


      # Necessary for using flakes on this system.
      nix.settings.experimental-features = "nix-command flakes";

      nix.settings.trusted-users = [ "blingmember" ];
      system.primaryUser = "blingmember";

      # Create /etc/zshrc that loads the nix-darwin environment.
      programs.zsh.enable = true;  # default shell on catalina
      # programs.fish.enable = true;

      # Set Git commit hash for darwin-version.
      system.configurationRevision = self.rev or self.dirtyRev or null;

      # Used for backwards compatibility, please read the changelog before changing.
      # $ darwin-rebuild changelog
      system.stateVersion = 4;

      system.defaults = {
        dock = {
          magnification = true;
          tilesize = 20;
          largesize = 50;
          show-process-indicators = true;
          persistent-apps = [ "/Applications/Firefox.app" "/Applications/Visual\ Studio\ Code.app" ];
        };
        NSGlobalDomain = {
          AppleInterfaceStyle = "Dark";
          "com.apple.trackpad.scaling" = 2.0;
        };
        finder = {
          AppleShowAllFiles = true;
          AppleShowAllExtensions = true;
          QuitMenuItem = true;
          FXEnableExtensionChangeWarning = false;
        };
      };

      # The platform the configuration will be used on.
      nixpkgs.hostPlatform = "aarch64-darwin";

      security.pam.services.sudo_local.touchIdAuth = true;

      users.users."blingmember".home = "/Users/blingmember";
    };
  in
  {
    # Build darwin flake using:
    # $ darwin-rebuild build --flake .#simple
    darwinConfigurations.${name} = nix-darwin.lib.darwinSystem {
      modules = [ 
        configuration
        #nix-shell -p gnupg -p ssh-to-age --run "ssh-to-age -private-key -i $HOME/.ssh/id_ed25519" > $HOME/Library/Application\ Support/sops/age/keys.txt
        inputs.sops-nix.darwinModules.sops
        {
          sops.defaultSopsFile = ./secrets/secrets2.yaml;
          sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
          # This is using an age key that is expected to already be in the filesystem
          sops.age.keyFile = "/Users/blingmember/Library/Application Support/sops/age/keys.txt";
          sops.age.generateKey = true;
          sops.secrets = {
            ".netrc" = {
              owner = "blingmember";
              mode = "0600";
              path = "/Users/blingmember/.netrc";
            };
          };
        }
        inputs.nix-index-database.darwinModules.nix-index
        home-manager.darwinModules.home-manager
          {
            # inherit nixpkgs;
            # `home-manager` config
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users."blingmember" = import ./home.nix;
          }
      ];
    };

    # sudo ln -s /Users/blingmember/Repos/nix-darwin-config/scripts/com.bling.wasyle.plist /Library/LaunchDaemons/com.bling.wasyle.plist
    # sudo launchctl load /Library/LaunchDaemons/com.bling.wasyle.plist
    
    # Expose the package set, including overlays, for convenience.
    darwinPackages = self.darwinConfigurations.${name}.pkgs;
  };
}
