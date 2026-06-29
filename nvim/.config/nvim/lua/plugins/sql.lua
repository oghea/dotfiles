-- SQL IntelliSense for scratch buffers (`:set ft=sql`).
-- Real DB work lives in DataGrip; this is purely editor smarts:
-- keyword completion, hover, and diagnostics via the `sqls` language server.
return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        -- Mason installs `sqls` automatically. It gives keyword completion
        -- out of the box; schema-aware completion would need a DB connection
        -- (not configured here on purpose).
        sqls = {},
      },
    },
  },

  -- Syntax highlighting for SQL buffers.
  {
    "nvim-treesitter/nvim-treesitter",
    opts = { ensure_installed = { "sql" } },
  },
}
