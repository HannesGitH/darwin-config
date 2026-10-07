{ config, ... }:

let
  mcpSecretsFile = "${config.xdg.configHome}/claude/mcp-secrets.env";
in
{
  # The `be` repo's .mcp.json starts five MCP servers through their own
  # `op run`, so every Claude session raised one 1Password prompt per server.
  # Instead, claude-auto-retry wraps `claude` itself in a single `op run`
  # (inside the tmux pane, so nothing reaches the tmux server), and local-scope
  # overrides of those servers in ~/.claude.json read the inherited variables.
  # The overrides are not declarative: Claude Code rewrites ~/.claude.json.
  #
  # Names are CLAUDE_MCP_* rather than what each server expects, because every
  # process under claude inherits them -- a shell-wide STRIPE_SECRET_KEY or
  # Mongo URL would leak into the backend's own dev server and tests.
  # Only 1Password references live here, no secret values.
  xdg.configFile."claude/mcp-secrets.env".text = ''
    CLAUDE_MCP_CHARGEBEE_KEY="op://Cursor/Chargebee MCP/API_KEY"
    CLAUDE_MCP_STRIPE_KEY="op://Cursor/STRIPE MCP Read/API_KEY"
    CLAUDE_MCP_MONGODB_DEV_URL="op://Cursor/MongoDB Read DEV Cursor/CONNECTION_URL"
    CLAUDE_MCP_MONGODB_PROD_URL="op://Cursor/MongoDB Read PROD Cursor/CONNECTION_URL"
  '';

  # Split on whitespace by the launcher, so the path must not contain spaces.
  # --no-masking keeps claude on the real TTY instead of op's masking pipe.
  home.sessionVariables.CLAUDE_AUTO_RETRY_LAUNCH_WRAPPER =
    "op run --no-masking --account blingservicesgmbh.1password.eu --env-file ${mcpSecretsFile} --";

  # Backend-role Zed tweaks (TypeScript/JavaScript work). Imported into the
  # home-manager config of any host used for backend development -- currently
  # only `maccaroni` (see flake.nix), the system counterpart being
  # `specifics/backend/config.nix`.
  #
  # The shared Zed defaults live in `modules/zed.nix`; this layers the vtsls
  # (TypeScript/JS LSP) settings on top via `extraSettings`, which
  # `recursiveUpdate`s into Zed's `userSettings`.
  myModules.zed.extraSettings = {
    lsp = {
      vtsls = {
        settings = {
          typescript = {
            updateImportsOnFileMove = {
              enabled = "always";
            };
          };
          javascript = {
            updateImportsOnFileMove = {
              enabled = "always";
            };
          };
        };
        enable_lsp_tasks = true;
      };
    };
  };
}
