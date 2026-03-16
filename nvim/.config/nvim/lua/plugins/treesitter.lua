return {
  {
    "nvim-treesitter/nvim-treesitter",
    opts = function(_, opts)
      vim.list_extend(opts.ensure_installed or {}, {
        "tsx",
        "typescript",
        "javascript",
        "html",
        "css",
        "json",
        "json5",
        "jsonc",
        "dockerfile",
        "yaml",
        "bash",
        "markdown",
        "markdown_inline",
      })
    end,
  },
}