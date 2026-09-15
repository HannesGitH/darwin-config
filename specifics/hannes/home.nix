{ ... }:

{
  # Hannes-specific Zed overrides. Shared Zed defaults live in
  # `modules/zed.nix`; anything personal (keymap muscle memory, SSH
  # remotes, etc.) is layered on here via `extraSettings`, which
  # `recursiveUpdate`s into Zed's `userSettings`.
  myModules.zed = {
    # Was `nightly` (ride upstream Zed directly via the `zed` flake
    # input, instead of waiting for nixpkgs to ship a release).
    # Parked on `unstable` because upstream master does not build:
    # `zed-editor-deps` dies in `cxx-build 1.0.187`, which calls
    # `scratch::path("cxxbridge")` against a `scratch` that has no such
    # function (E0425). Reproduced on both 2026-09-02 (`c3cf80c`) and
    # 2026-09-14 (`250b658`), so it is not a one-rev blip. Since
    # `modules/git.nix` resolves the mergetool with `lib.getExe` on this
    # package, a broken Zed takes `hm_gitconfig` -- and therefore the
    # whole system closure -- down with it.
    #
    # Put this back to `nightly` once upstream builds again; the last
    # good rev was `76b1096` (Zed 1.19.0), which is what ran here
    # before. `blingi` still says `nightly` in flake.nix and will hit
    # the same wall.
    channel = "unstable";
    extraSettings = {
      base_keymap = "VSCode";
    };
  };

  programs.git = {
    settings = {
      user.name = "Hannes";
      user.email = "github@h-h.win";
      commit.gpgsign = true;
      user.signingkey = "792D2673D758C914A2293714355878B8CF2515D1";
    };
  };

  # Declarative GPG public-key + ownertrust management. The public key
  # itself is not secret so it lives unencrypted in the repo; the
  # matching private key is dropped in by sops-nix and imported by the
  # postActivation hook in specifics/hannes/config.nix.
  #
  # `mutableKeys = false` and `mutableTrust = false` make home-manager
  # overwrite pubring.kbx / trustdb.gpg on activation, so any ad-hoc
  # `gpg --import`s you do outside of this config will not survive a
  # rebuild -- intentional, keeps the keyring reproducible.
  programs.gpg = {
    enable = true;
    mutableKeys = false;
    mutableTrust = false;
    publicKeys = [
      {
        source = ../../secrets/hannes/gpg.pub.asc;
        trust = "ultimate";
      }
    ];
  };
}
