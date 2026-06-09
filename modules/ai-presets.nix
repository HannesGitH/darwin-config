# Shared edit-prediction model presets.
#
# Plain attrset (NOT a module), imported from both module trees without
# crossing the system <-> home-manager boundary:
#   - `modules/ai.nix`  (system)        serves `model` via `mlx_lm.server`.
#   - `modules/zed.nix` (home-manager)  feeds `model` + `promptFormat` into
#                                        Zed's `edit_predictions`.
#
# Keep `myModules.ai.preset` and `myModules.zed.editPrediction.preset` set to
# the same key (both default to the same value, so usually nothing to do).
#
# Why MLX (not ollama): MLX loads HuggingFace safetensors with the original
# tokenizer, so Zeta's special FIM tokens (`<|editable_region_start|>` etc.)
# survive intact -- it was llama.cpp's GGUF conversion that shredded them and
# previously forced us onto qwen-via-ollama. Metal GPU support comes from
# Apple's official PyPI wheels, repackaged in `modules/pkgs/mlx` (the nixpkgs
# `mlx` is CPU-only because the Metal shader compiler is closed-source).
#
# Each preset:
#   model          HuggingFace repo (MLX format) that `mlx_lm.server`
#                  downloads on first start and serves. Also the model id
#                  Zed sends in its completion requests.
#   promptFormat   Zed `prompt_format` matching the model family.
#
# Performance (Apple Silicon, Metal, ~2000-token file context):
#   qwen-0.5b: near-instant   qwen-1.5b: fast   zeta-2.1 / qwen-7b: usable
# Prefill cost scales with parameter count; smaller = faster.

{
  # Zeta 2.1 (8B, 4-bit MLX quant of zed-industries/zeta-2.1) -- recommended
  # default. Zed's own purpose-built edit-prediction model: unlike plain FIM
  # models it predicts multi-location *edits*, not just insertions at the
  # cursor. ~4.5 GB download, heavier prefill than the qwen options.
  "zeta-2.1" = {
    model = "NexVeridian/zeta-2.1-4bit";
    promptFormat = "zeta2_1";
  };

  # Qwen2.5-Coder 1.5B base (4-bit MLX) -- fast fallback with solid FIM
  # quality for machines where the 8B Zeta prefill feels sluggish.
  "qwen-1.5b" = {
    model = "mlx-community/Qwen2.5-Coder-1.5B-4bit";
    promptFormat = "qwen";
  };

  # Qwen2.5-Coder 0.5B base (4-bit MLX) -- fastest, predictions appear
  # near-instantly even on large files; lower quality than 1.5B.
  "qwen-0.5b" = {
    model = "mlx-community/Qwen2.5-Coder-0.5B-4bit";
    promptFormat = "qwen";
  };

  # Qwen2.5-Coder 7B base (4-bit MLX) -- highest-quality plain-FIM option,
  # comparable footprint to zeta-2.1 (prefer Zeta unless qwen's FIM style
  # works better for you).
  "qwen-7b" = {
    model = "mlx-community/Qwen2.5-Coder-7B-4bit";
    promptFormat = "qwen";
  };
}
