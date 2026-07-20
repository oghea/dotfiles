return {
  {
    "snacks.nvim",
    opts = {
      explorer = {
        replace_netrw = true,
      },
      picker = {
        sources = {
          explorer = {
            auto_close = true,
            hidden = true,
            ignored = true,
            exclude = { "node_modules", "dist" },
            layout = {
              preset = "sidebar",
              preview = "main",
            },
            win = {
              list = {
                keys = {
                  ["<c-j>"] = false,
                  ["<c-k>"] = false,
                  ["<c-h>"] = false,
                  ["<c-l>"] = false,
                },
              },
            },
          },
        },
      },
    },
    keys = {
      {
        "<leader>e",
        function() Snacks.explorer.open() end,
        desc = "Toggle Explorer",
      },
    },
  },
  {
    "akinsho/bufferline.nvim",
    opts = {
      options = {
        always_show_bufferline = true,
      },
    },
  },
  {
    "christoomey/vim-tmux-navigator",
    cmd = {
      "TmuxNavigateLeft",
      "TmuxNavigateDown",
      "TmuxNavigateUp",
      "TmuxNavigateRight",
    },
    keys = {
      { "<C-h>", "<cmd>TmuxNavigateLeft<cr>", desc = "Navigate left (tmux/nvim)" },
      { "<C-j>", "<cmd>TmuxNavigateDown<cr>", desc = "Navigate down (tmux/nvim)" },
      { "<C-k>", "<cmd>TmuxNavigateUp<cr>", desc = "Navigate up (tmux/nvim)" },
      { "<C-l>", "<cmd>TmuxNavigateRight<cr>", desc = "Navigate right (tmux/nvim)" },
    },
  },
}