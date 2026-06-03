# Shared edit-prediction model presets.
#
# Plain attrset (NOT a module), imported from both module trees without
# crossing the system <-> home-manager boundary:
#   - `modules/ai.nix`  (system)        pulls `ollamaModel` into the local
#                                        ollama instance.
#   - `modules/zed.nix` (home-manager)  feeds `ollamaModel` + `promptFormat`
#                                        into Zed's `edit_predictions`.
#
# Keep `myModules.ai.preset` and `myModules.zed.editPrediction.preset` set to
# the same key (both default to the same value, so usually nothing to do).
#
# Why ollama (not MLX): the nixpkgs `mlx` package is built WITHOUT the Metal
# GPU backend (`mx.metal.is_available() == False`), so all inference runs on
# CPU -- unusably slow even for a 1.5B model. Ollama bundles llama.cpp with
# Metal compiled in, so it actually uses the GPU.
#
# Why qwen (not Zeta 2.1): Zeta's bracketed FIM tokens (`<[fim-prefix]>`,
# `<|marker_1|>`) get shredded into sub-tokens by llama.cpp's GGUF converter,
# so the model can't FIM. Qwen2.5-Coder uses standard `<|fim_*|>` tokens that
# survive GGUF conversion, and ollama hosts official base models with working
# tokenizers.
#
# Each preset:
#   ollamaModel    Model tag to `ollama pull` and reference from Zed.
#   promptFormat   Zed `prompt_format` matching the model family.
#
# Performance (Apple Silicon, Metal, ~2000-token file context):
#   qwen-0.5b: near-instant       qwen-1.5b: ~fast      qwen-7b: usable
# Prefill cost scales with parameter count; smaller = faster.

{
  # Qwen2.5-Coder 1.5B base -- recommended default. Fast on Metal, solid
  # FIM quality, official ollama model so the tokenizer is correct.
  "qwen-1.5b" = {
    ollamaModel = "qwen2.5-coder:1.5b-base";
    promptFormat = "qwen";
  };

  # Qwen2.5-Coder 0.5B base -- fastest, predictions appear near-instantly
  # even on large files; lower quality than 1.5B.
  "qwen-0.5b" = {
    ollamaModel = "qwen2.5-coder:0.5b-base";
    promptFormat = "qwen";
  };

  # Qwen2.5-Coder 7B base -- the model Zed's own docs use as the ollama
  # example. Highest quality of the qwen options, still Metal-fast but a
  # heavier prefill than 1.5B.
  "qwen-7b" = {
    ollamaModel = "qwen2.5-coder:7b-base";
    promptFormat = "qwen";
  };

  # Zeta 2.1 via community GGUF. KEPT FOR REFERENCE ONLY -- the GGUF
  # conversion breaks Zeta's special FIM tokens, so this produces garbage
  # output. Do not use until a properly-converted GGUF exists.
  "zeta-2.1" = {
    ollamaModel = "hf.co/mradermacher/zeta-2.1-GGUF:Q4_K_M";
    promptFormat = "zeta2_1";
  };
}
