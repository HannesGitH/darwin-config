{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

# System-level AI inference backend for Zed's edit-prediction feature.
#
# Runs a local `ollama` instance (Metal-accelerated llama.cpp under the hood)
# as a launchd agent, and auto-pulls the model selected by `myModules.ai.preset`
# on login. The Zed-side wiring lives in `modules/zed.nix`, which points its
# `edit_predictions` ollama provider at this instance.
#
# Why ollama and not MLX: the nixpkgs `mlx` package is built without the Metal
# GPU backend, so MLX inference runs entirely on CPU -- far too slow for
# interactive per-keystroke edit prediction even with a 1.5B model. Ollama
# bundles llama.cpp with Metal compiled in and actually uses the GPU.
#
# Model choice (and why not Zeta 2.1) is documented in modules/ai-presets.nix.

let
  cfg = config.myModules.ai;

  # Shared model presets (see modules/ai-presets.nix). Selected via
  # `myModules.ai.preset`; the exact tag can be overridden with `ollamaModel`.
  presets = import ./ai-presets.nix;
  selected = presets.${cfg.preset};

  # Use ollama from `nixpkgsunstable`: the 25.11 derivation's patch phase
  # tries to `rm` a test file that no longer exists in current ollama
  # releases, so that build fails. Unstable tracks ollama closely and has
  # Metal support compiled in for darwin.
  ollama = inputs.nixpkgsunstable.legacyPackages.${pkgs.system}.ollama;

  userHome = config.users.users.${config.system.primaryUser}.home;
in
{
  options.myModules.ai = {
    enable = lib.mkEnableOption ''
      Local AI inference via ollama (Metal-accelerated).

      Runs `ollama serve` as a launchd agent on `myModules.ai.host`, and
      auto-pulls the model selected by `preset` on login. Consumed by
      Zed's edit-prediction (see modules/zed.nix).
    '';

    preset = lib.mkOption {
      type = lib.types.enum (builtins.attrNames presets);
      default = "qwen-1.5b";
      description = ''
        Which model preset to serve (see modules/ai-presets.nix):

        - `qwen-1.5b` *(default)*: Qwen2.5-Coder 1.5B base. Fast on Metal,
          good FIM quality, correct tokenizer.
        - `qwen-0.5b`: fastest, near-instant; lower quality.
        - `qwen-7b`: highest quality qwen option, heavier prefill.
        - `zeta-2.1`: reference only -- broken FIM tokens in GGUF, garbage
          output. Don't use.

        Keep in sync with `myModules.zed.editPrediction.preset` (both
        default to the same value). `ollamaModel` defaults from this.
      '';
    };

    ollamaModel = lib.mkOption {
      type = lib.types.str;
      default = selected.ollamaModel;
      defaultText = lib.literalExpression "presets.\${cfg.preset}.ollamaModel";
      example = "qwen2.5-coder:7b-base";
      description = ''
        Ollama model tag to pull and serve. Defaults to the selected
        `preset`'s model. Official registry tags (e.g.
        `qwen2.5-coder:1.5b-base`) or `hf.co/<user>/<repo>:<quant>` both work.
      '';
    };

    host = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1:11434";
      description = ''
        `OLLAMA_HOST` bind address for the local ollama server. Default is
        loopback-only.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ ollama ];

    # Keep ollama running in the background so Zed's edit predictions are
    # always available. Ollama manages model loading, Metal acceleration,
    # KV caching, and keep-alive internally.
    launchd.user.agents.ollama = {
      serviceConfig = {
        Label = "dev.ollama.ollama";
        ProgramArguments = [
          "${ollama}/bin/ollama"
          "serve"
        ];
        EnvironmentVariables = {
          HOME = userHome;
          OLLAMA_HOST = cfg.host;
          # Keep the edit-prediction model resident so there's no reload
          # latency between coding sessions.
          OLLAMA_KEEP_ALIVE = "24h";
        };
        RunAtLoad = true;
        KeepAlive = true;
        StandardOutPath = "/tmp/ollama.log";
        StandardErrorPath = "/tmp/ollama.err";
      };
    };

    # One-shot: pull the configured model on login if not already present.
    # RunAtLoad fires once per login; the grep short-circuits immediately
    # when the model is already cached, so ongoing overhead is negligible.
    launchd.user.agents.ollama-pull = {
      serviceConfig = {
        Label = "dev.ollama.pull";
        ProgramArguments = [
          "/bin/sh"
          "-c"
          ''
            until ${ollama}/bin/ollama list >/dev/null 2>&1; do sleep 2; done
            ${ollama}/bin/ollama list | grep -qF '${cfg.ollamaModel}' \
              || ${ollama}/bin/ollama pull '${cfg.ollamaModel}'
          ''
        ];
        EnvironmentVariables = {
          HOME = userHome;
          OLLAMA_HOST = cfg.host;
        };
        RunAtLoad = true;
        KeepAlive = false;
        StandardOutPath = "/tmp/ollama-pull.log";
        StandardErrorPath = "/tmp/ollama-pull.err";
      };
    };
  };
}
