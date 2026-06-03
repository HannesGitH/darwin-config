{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

# Home-manager module that wires up Zed with the project's preferred defaults
# (Ayu theme, VSCode bindings, ligatures) and exposes a small set of bool
# toggles for language extensions and MCP context servers. Imported from
# global/home.nix; configure via `myModules.zed.*` in any home-manager
# context (see global/home.nix for the canonical call site).
#
# https://wiki.nixos.org/wiki/Zed

let
  inherit (lib)
    mkOption
    mkEnableOption
    mkIf
    types
    optionals
    literalExpression
    ;

  # Shared edit-prediction model presets, also consumed by modules/ai.nix
  # (the MLX server backend). See modules/ai-presets.nix.
  presets = import ./ai-presets.nix;
in
{
  options.myModules.zed = {
    enable = mkEnableOption "Zed editor with darwin-config defaults";

    editPrediction = {
      preset = mkOption {
        type = types.enum (builtins.attrNames presets);
        default = "qwen-1.5b";
        description = ''
          Which model preset Zed's edit-prediction should target. This
          selects both the `prompt_format` and the local model path that
          Zed sends to the MLX server.

          Must match `myModules.ai.preset` (the backend that actually
          serves the model). Both default to the same value, so normally
          there's nothing to do -- change them together if you switch.
        '';
      };
    };

    channel = mkOption {
      type = types.enum [
        "unstable"
        "nightly"
      ];
      default = "unstable";
      description = ''
        Which Zed package to install:

        - `stable`: the `zed-editor` package from the `nixpkgsunstable` flake
          input (i.e. whatever Zed release nixpkgs has shipped). This is the
          better-tested option since the package goes through nixpkgs CI.
        - `unstable`: the package built directly from the `zed` flake input
          (`zed-industries/zed`, pinned by tag in `flake.nix`). Use this to
          ride closer to upstream releases or to pin a specific Zed version
          independently of nixpkgs.
      '';
    };

    extensions = {
      flutter = mkOption {
        type = types.bool;
        default = true;
        description = "Install the Dart extension (covers Flutter projects).";
      };
      rust = mkOption {
        type = types.bool;
        default = true;
        description = "Install the Rust extension.";
      };
      nix = mkOption {
        type = types.bool;
        default = true;
        description = "Install the Nix extension.";
      };
      comment = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Install the Comments Highlighter extension
          (https://github.com/thedadams/zed-comment), which colorizes
          TODO/NOTE/FIXME-style comment tags via tree-sitter injections.
        '';
      };
    };

    extraExtensions = mkOption {
      type = types.listOf types.str;
      default = [ ];
      example = literalExpression ''[ "elixir" "vue" "catppuccin" ]'';
      description = ''
        Additional Zed extension registry IDs to install on top of the
        ones covered by the `myModules.zed.extensions.*` toggles.

        The value is a list of extension IDs as they appear on
        https://zed.dev/extensions (or in each extension's
        `extension.toml`). Use this for per-user extensions that don't
        warrant a dedicated module option -- one-off language packs,
        alternative themes, niche tooling, etc.
      '';
    };

    theme = {
      dark = mkOption {
        type = types.str;
        default = "Palenight Theme";
        description = "Theme name used in dark mode.";
      };
      light = mkOption {
        type = types.str;
        default = "Ayu Light";
        description = "Theme name used in light mode (provided by the Ayu extension).";
      };
    };

    fontFamily = mkOption {
      type = types.str;
      default = "FiraCode Nerd Font";
      description = ''
        Editor + terminal font. Should be a ligature-aware font; the matching
        package is added to home.packages automatically when this is left at
        the default.
      '';
    };

    extraSettings = mkOption {
      type = types.attrs;
      default = { };
      example = literalExpression ''
        {
          base_keymap = "VSCode";
          buffer_font_size = 16;
          ssh_connections = [ { host = "example.com"; username = "user"; } ];
        }
      '';
      description = ''
        Per-user overrides merged into Zed's `userSettings` on top of the
        shared module defaults. Uses `lib.recursiveUpdate`, so individual
        nested keys can be tweaked without clobbering sibling defaults
        (lists, however, are replaced wholesale, not concatenated).

        Set this from per-user files (e.g. `specifics/<user>/home.nix`) to
        tailor Zed without forking the module -- the shared defaults stay
        in `modules/zed.nix`, anything personal lives next to the user's
        other home-manager config.
      '';
    };

    mcp = {
      # Each entry below maps to one entry in Zed's `context_servers` setting.
      # Zed only speaks stdio MCP natively, so HTTP-only providers are
      # bridged through `npx -y mcp-remote <url>` (the de-facto local proxy).

      linear.enable = mkEnableOption "Linear MCP (https://mcp.linear.app/mcp via mcp-remote)";

      dart = {
        enable = mkEnableOption "Dart/Flutter MCP (`dart mcp-server`)";
        command = mkOption {
          type = types.str;
          default = "dart";
          example = literalExpression ''"\${config.home.homeDirectory}/fvm/default/bin/dart"'';
          description = ''
            Path (or PATH-resolvable name) of the dart binary that exposes
            `mcp-server`. macOS GUI apps inherit launchd's PATH, not zsh's,
            so when using fvm point this at the absolute path
            (e.g. `$HOME/fvm/default/bin/dart`). The fvm `default` symlink
            is created with `fvm global <version>` and must exist for this
            path to resolve -- otherwise Zed sees the bridge process exit
            immediately and reports a context-server timeout.
          '';
        };
      };

      figma = {
        enable = mkEnableOption "Figma MCP (hosted remote, OAuth via mcp-remote)";
        useDesktop = mkOption {
          type = types.bool;
          default = false;
          description = ''
            Point at Figma's local desktop-app MCP server
            (`http://127.0.0.1:3845/mcp`) instead of the hosted remote one.
            Requires the Figma desktop app running with "Enable MCP server"
            turned on under Preferences and a Dev/Full seat on a paid plan.
            Leave `false` to use Figma's hosted endpoint, which works
            without any local setup (OAuth flow on first connect, same as
            Linear).
          '';
        };
        url = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = ''
            Override the Figma MCP endpoint. When `null` (the default),
            the URL is derived from {option}`useDesktop` -- hosted at
            `https://mcp.figma.com/mcp`, or local at
            `http://127.0.0.1:3845/mcp`.
          '';
        };
      };
    };
  };

  config =
    let
      cfg = config.myModules.zed;

      # Resolve the active edit-prediction preset (ollama model + format).
      epPreset = presets.${cfg.editPrediction.preset};

      # Pin the bridge binary to the nixpkgs nodejs so this works on hosts
      # that don't have a system-wide npx (e.g. fresh `maccaroni` setups).
      npx = lib.getExe' pkgs.nodejs "npx";

      mkRemoteServer = url: {
        command = npx;
        args = [
          "-y"
          "mcp-remote"
          url
        ];
        env = { };
      };

      figmaUrl =
        if cfg.mcp.figma.url != null then
          cfg.mcp.figma.url
        else if cfg.mcp.figma.useDesktop then
          "http://127.0.0.1:3845/mcp"
        else
          "https://mcp.figma.com/mcp";

      contextServers =
        lib.optionalAttrs cfg.mcp.linear.enable {
          linear = mkRemoteServer "https://mcp.linear.app/mcp";
        }
        // lib.optionalAttrs cfg.mcp.dart.enable {
          dart = {
            command = cfg.mcp.dart.command;
            # `--experimental-mcp-server` is a no-op on Dart 3.9+, kept for
            # forward compatibility with older SDKs. `--force-roots-fallback`
            # works around clients (Cursor, Zed) with partial Roots support.
            args = [
              "mcp-server"
              "--experimental-mcp-server"
              "--force-roots-fallback"
            ];
            env = { };
          };
        }
        // lib.optionalAttrs cfg.mcp.figma.enable {
          figma = mkRemoteServer figmaUrl;
        };
    in
    mkIf cfg.enable {
      programs.zed-editor = {
        package =
          if cfg.channel == "nightly" then
            # The upstream zed flake exposes the editor as `packages.<system>.default`.
            #
            # Workaround for aarch64-darwin: the final Zed binary has grown
            # past ~150MB of code, and at that size Apple's `ld64` can't
            # satisfy ARM64's ±128MB `b`/`bl` direct-branch range for some
            # cross-crate calls (e.g. `gpui_macos::window` calling into
            # `cocoa_foundation`). The link step dies with:
            #
            #     ld: b(l) ARM64 branch out of range (-159277244 max is +/-128MB)
            #
            # `zed.cachix.org` doesn't currently publish aarch64-darwin
            # builds of the nightly tip either, so we can't sidestep the
            # link by pulling a substitute. Two patches together get us
            # under the limit:
            #
            #   1. Drop the per-package `[profile.release.package.zed]`
            #      override (which bumps `codegen-units` back to 16 for
            #      faster upstream iteration). With cg=16 the top crate
            #      emits ~16 duplicated copies of all monomorphized
            #      generics; falling back to the workspace default of
            #      cg=1 shrinks the binary slightly (~1MB) and makes the
            #      output layout denser.
            #
            #   2. Force the final link through LLVM's `lld` (`ld64.lld`)
            #      instead of Apple's `ld64`. `lld` automatically emits
            #      long-range branch "veneers" / trampolines for out-of-
            #      range `bl` instructions, which is the well-trodden fix
            #      for this error. Apple's current `ld64` (both the new
            #      `ld-prime` codepath and the legacy `-ld_classic` mode)
            #      regressed this on aarch64-darwin in recent cctools
            #      versions and fails the link instead of inserting a
            #      thunk. We tried `-Wl,-ld_classic` first -- the flag
            #      is honored but the underlying linker behavior is
            #      identical, so it didn't help.
            #
            #      The flag is added by extending the existing `[build]`
            #      rustflags list in `.cargo/config.toml` (rather than a
            #      new `[target.aarch64-apple-darwin]` block), because
            #      cargo _replaces_, not merges, rustflags when a more
            #      specific target section matches -- and the existing
            #      list contains `--cfg tokio_unstable`, which the rest
            #      of the workspace relies on at compile time. `lld` is
            #      put on `$PATH` via `nativeBuildInputs` so that clang's
            #      `-fuse-ld=lld` driver flag can find `ld64.lld`.
            #
            # Both patches run in the outer `buildPackage`, so
            # `cargoArtifacts` (the dep build) stays cached -- only the
            # `zed`/`cli` recompile and final link redo. (NB: editing
            # `.cargo/config.toml` does invalidate cargo's own
            # fingerprint cache inside the sandbox, so the final-crate
            # compile re-runs end to end; that's intrinsic, not
            # something this hack causes.)
            #
            # Revisit once upstream fixes this (e.g. by switching darwin
            # to `lto = "fat"`, dropping the cg=16 override, or shipping
            # cached binaries we can actually consume).
            (inputs.zed.packages.${pkgs.system}.default.overrideAttrs (old: {
              nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ pkgs.lld ];
              postPatch = (old.postPatch or "") + ''
                substituteInPlace Cargo.toml \
                  --replace-fail \
                    'zed = { codegen-units = 16 }' \
                    '# zed = { codegen-units = 16 } # patched out by darwin-config (modules/zed.nix) -- see comment there'

                substituteInPlace .cargo/config.toml \
                  --replace-fail \
                    'rustflags = ["-C", "symbol-mangling-version=v0", "--cfg", "tokio_unstable"]' \
                    'rustflags = ["-C", "symbol-mangling-version=v0", "--cfg", "tokio_unstable", "-C", "link-arg=-fuse-ld=lld"]'
              '';
            }))
          else
            inputs.nixpkgsunstable.legacyPackages.${pkgs.system}.zed-editor;
        enable = true;
        extensions = lib.unique (
          [
            "ayu"
            "toml"
          ]
          ++ optionals cfg.extensions.flutter [ "dart" ]
          ++ optionals cfg.extensions.nix [ "nix" ]
          # The Rust extension only adds toolchain helpers; rust-analyzer
          # itself is bundled with Zed, so this stays optional.
          ++ optionals cfg.extensions.rust [ "rust" ]
          # `comment` is the registry id for thedadams/zed-comment.
          ++ optionals cfg.extensions.comment [ "comment" ]
          # Per-user escape hatch for extensions without a dedicated
          # toggle. `lib.unique` above keeps things tidy if a user
          # accidentally lists one that's already enabled by a toggle.
          ++ cfg.extraExtensions
        );

        # Shared defaults are defined inline below; per-user tweaks come in
        # via `cfg.extraSettings` (see e.g. `specifics/hannes/home.nix`).
        # `lib.recursiveUpdate` deep-merges with right-side precedence, so
        # individual leaf keys (or whole nested attrsets) can be overridden
        # without restating the rest of the defaults.
        userSettings = lib.recursiveUpdate {
          theme = {
            mode = "system";
            inherit (cfg.theme) dark light;
          };

          # Per-theme tweaks. Only the keys listed here override the base
          # theme; everything else is inherited.
          theme_overrides = {
            "Palenight Theme" = {
              "editor.background" = "#191D2b";
              "scrollbar.track.background" = "#191D2b";
              "scrollbar.track.border" = "#191D2b";
              "tab.active_background" = "#191D2b";
              "toolbar.background" = "#191D2b";
              "title_bar.background" = "#191D2b";
              background = "#191D2b";
              # "elevated_surface.background" = "#191D2e";
              # "surface.background" = "#191D2b";
              "editor.gutter.background" = "#191D2b";
              "error.background" = "#4d2b2b";
              "warning.background" = "#4a4327";
              "panel.background" = "#292D3e";
              syntax = {
                type = {
                  color = "#dcd288ff";
                  font_style = null;
                  font_weight = null;
                };
              };
              accents = [
                "#5b0"
                "#0ab"
              ];
            };
          };

          # `base_keymap` is intentionally not set here -- it's a personal
          # preference, so users opt into VSCode/Atom/JetBrains bindings via
          # `myModules.zed.extraSettings.base_keymap`.
          vim_mode = false;

          # ---- Edit prediction (a.k.a. inline AI completions) ------------------
          # Served by the local ollama instance set up in `modules/ai.nix`
          # (enabled from `global/config.nix` via `myModules.ai.enable`).
          # On machines using both modules, edit predictions Just Work™ with
          # no zed.dev sign-in -- Metal-accelerated, fully local.
          #
          # The model + prompt_format come from the selected
          # `myModules.zed.editPrediction.preset`, which must match the
          # backend's `myModules.ai.preset` (both default to `qwen-1.5b`).
          #
          # To opt out, override via `extraSettings.edit_predictions.provider`
          # (e.g. `"zed"` for the hosted service, `"copilot"`, or `"none"`).
          edit_predictions = {
            provider = "ollama";
            ollama = {
              api_url = "http://localhost:11434";
              model = epPreset.ollamaModel;
              prompt_format = epPreset.promptFormat;
              max_output_tokens = 512;
            };
          };

          ui_font_size = 15;
          buffer_font_size = 14;
          buffer_font_family = cfg.fontFamily;
          buffer_font_features = {
            calt = true;
            liga = true;
          };
          terminal.font_family = cfg.fontFamily;

          # Empty proxy explicitly disables Zed's auto-detected proxy. Keep
          # this set so corporate macOS proxy settings don't bleed into Zed.
          proxy = "";

          # ---- Editor behavior -------------------------------------------------
          # `semantic_tokens = off` keeps Tree-sitter highlighting authoritative
          # so the `comment` extension (and others that rely on injections) win
          # over LSP-provided semantic tokens.
          semantic_tokens = "off";
          lsp_document_colors = "inlay";
          colorize_brackets = true;
          indent_guides = {
            background_coloring = "disabled";
            coloring = "indent_aware";
          };

          # ---- App behavior ----------------------------------------------------
          cli_default_open_behavior = "new_window";

          # ---- Layout / panels -------------------------------------------------
          bottom_dock_layout = "contained";

          collaboration_panel = {
            dock = "left";
          };

          git_panel = {
            tree_view = true;
            dock = "left";
          };

          outline_panel = {
            default_width = 340.0;
            dock = "left";
          };

          project_panel = {
            hide_hidden = false;
            hide_root = true;
            git_status = true;
            git_status_indicator = false;
            diagnostic_badges = true;
            bold_folder_labels = true;
            default_width = 340.0;
            dock = "left";
          };

          tabs = {
            git_status = true;
            file_icons = true;
          };

          tab_bar = {
            show = true;
          };

          title_bar = {
            show_branch_status_icon = true;
          };

          # ---- Agent (Zed AI) --------------------------------------------------
          agent = {
            max_content_width = 1000.0;
            default_width = 540.0;
            dock = "right";
            favorite_models = [
              {
                provider = "anthropic";
                model = "claude-opus-4-7-latest";
                enable_thinking = true;
                effort = "high";
              }
            ];
            default_model = {
              provider = "anthropic";
              model = "claude-opus-4-7-latest";
              enable_thinking = true;
              effort = "high";
            };
            model_parameters = [ ];

            # Allowlist a few read-only tools and well-anchored shell
            # commands so the agent can run them without prompting.
            tool_permissions = {
              tools = {
                fetch = {
                  default = "allow";
                };
                "mcp:dart:add_roots" = {
                  default = "allow";
                };
                "mcp:linear:get_diff" = {
                  default = "allow";
                };
                "mcp:linear:get_diff_threads" = {
                  default = "allow";
                };
                "mcp:linear:get_issue" = {
                  default = "allow";
                };
                "mcp:linear:list_comments" = {
                  default = "allow";
                };
                "mcp:linear:search_documentation" = {
                  default = "allow";
                };
                edit_file = {
                  always_allow = [
                    { pattern = "^app/\\.zed/"; }
                  ];
                };
                terminal = {
                  always_allow = [
                    { pattern = "^ls\\b"; }
                    { pattern = "^sort\\b"; }
                    { pattern = "^tail\\b"; }
                    { pattern = "^grep\\b"; }
                    { pattern = "^head\\b"; }
                    { pattern = "^find\\s+/nix/store(\\s|$)"; }
                    { pattern = "^xargs\\s+grep(\\s|$)"; }
                    { pattern = "^git\\s+log(\\s|$)"; }
                    { pattern = "^git\\s+show(\\s|$)"; }
                  ];
                };
              };
            };
          };

          context_servers = contextServers;
        } cfg.extraSettings;
      };

      home.packages = lib.optional (cfg.fontFamily == "FiraCode Nerd Font") pkgs.nerd-fonts.fira-code;
    };
}
