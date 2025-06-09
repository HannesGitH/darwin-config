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
  let 
    secretsModules = [
      # nix-shell -p gnupg -p ssh-to-age --run "ssh-to-age -private-key -i $HOME/.ssh/id_ed25519" > $HOME/Library/Application\ Support/sops/age/keys.txt
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
    ];
    globalModules = [
      {
        # Set Git commit hash for darwin-version.
        system.configurationRevision = self.rev or self.dirtyRev or null;
      }
      inputs.nix-index-database.darwinModules.nix-index
      home-manager.darwinModules.home-manager
      {
        # inherit nixpkgs;
        # `home-manager` config
        home-manager.useGlobalPkgs = true;
        home-manager.useUserPackages = true;
        home-manager.sharedModules = [
          ./global/home.nix
        ];
      }
      ./global/config.nix
    ] ++ secretsModules;
  in
  {
    darwinConfigurations = {
      # HANNES config
      "maccaroni" = nix-darwin.lib.darwinSystem {
        modules = globalModules ++ [
          {
            home-manager.users."blingmember" = import ./specifics/hannes/home.nix;
          }
        ];
      };
      # general config
      "blingi" = nix-darwin.lib.darwinSystem {
        modules = globalModules;
      };
    };

    # sudo ln -s /Users/blingmember/Repos/nix-darwin-config/scripts/com.bling.wasyle.plist /Library/LaunchDaemons/com.bling.wasyle.plist
    # sudo launchctl load /Library/LaunchDaemons/com.bling.wasyle.plist
  };
}
