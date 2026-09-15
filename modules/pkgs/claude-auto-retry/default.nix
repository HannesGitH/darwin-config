{
  lib,
  stdenv,
  makeWrapper,
  nodejs,
  tmux,
  # Upstream source checkout -- the `claude-auto-retry` flake input, declared
  # with `flake = false` because upstream ships no flake of its own.
  src,
}:

# claude-auto-retry: when `claude` hits a subscription rate limit or an API
# overload (529/5xx), a background monitor waits out the window and resumes
# the session instead of leaving it dead. The session lives in tmux, so it
# also survives a dropped SSH connection or a sleeping laptop.
#
# Upstream is plain Node with zero npm dependencies, so there is nothing to
# build -- `buildNpmPackage` would only add a pointless empty node_modules.
# Copy the checkout into the store and put `makeWrapper` shims in front of
# the entrypoints, each with tmux and the pinned node on PATH: every
# entrypoint shells out to a bare `tmux` (src/tmux.js) and a bare `node`
# (src/wrapper.sh), neither of which is on an ambient interactive PATH here.

let
  # tmux is a hard runtime requirement (the monitor drives the claude pane
  # with `tmux send-keys` / `capture-pane`), not an optional extra.
  runtimePath = lib.makeBinPath [
    tmux
    nodejs
  ];
in
stdenv.mkDerivation {
  pname = "claude-auto-retry";
  # Read from upstream's package.json so a flake-input bump can't leave a
  # stale version string behind.
  version = (builtins.fromJSON (builtins.readFile "${src}/package.json")).version;

  inherit src;

  nativeBuildInputs = [ makeWrapper ];
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/lib/claude-auto-retry" "$out/bin"
    cp -R . "$out/lib/claude-auto-retry/"
    # Store copies come out read-only; patchShebangs rewrites in place.
    chmod -R u+w "$out/lib/claude-auto-retry"
    patchShebangs "$out/lib/claude-auto-retry/bin"

    # `claude-auto-retry` itself: install-hook, reconcile, status, logs.
    makeWrapper ${lib.getExe nodejs} "$out/bin/claude-auto-retry" \
      --add-flags "$out/lib/claude-auto-retry/bin/cli.js" \
      --prefix PATH : "$out/bin:${runtimePath}"

    # The launcher, as its own entrypoint. Upstream's src/wrapper.sh calls
    # `node <launcher.js>` from the user's interactive shell, which on a
    # home-manager zsh has neither node nor tmux on PATH. The zsh function in
    # modules/claude-auto-retry.nix substitutes this shim in place of that
    # bare `node` call, so the launcher runs with both resolved by store path.
    makeWrapper ${lib.getExe nodejs} "$out/bin/claude-auto-retry-launch" \
      --add-flags "$out/lib/claude-auto-retry/src/launcher.js" \
      --prefix PATH : "$out/bin:${runtimePath}"

    # Optional tmux status-line segment (`claude-auto-retry-tmux-status`).
    makeWrapper "$out/lib/claude-auto-retry/bin/tmux-status.sh" "$out/bin/claude-auto-retry-tmux-status" \
      --prefix PATH : "${runtimePath}"

    runHook postInstall
  '';

  meta = {
    description = "Auto-retry Claude Code on subscription rate limits and API overload (529/5xx)";
    homepage = "https://github.com/cheapestinference/claude-auto-retry";
    license = lib.licenses.mit;
    mainProgram = "claude-auto-retry";
    platforms = lib.platforms.unix;
  };
}
