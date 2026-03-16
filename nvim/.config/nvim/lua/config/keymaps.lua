-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

-- Delete buffer
vim.keymap.set("n", "<leader>bd", function()
  Snacks.bufdelete()
end, { desc = "Delete Buffer" })

-- Close all buffers and reset to dashboard
vim.keymap.set("n", "<leader>bD", function()
  vim.cmd("only")
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].buflisted then
      vim.api.nvim_buf_delete(buf, { force = true })
    end
  end
  Snacks.dashboard()
  vim.wo.winbar = "%=%{fnamemodify(getcwd(), ':t')}"
end, { desc = "Close all & Dashboard" })

-- Floating terminal toggle (override LazyVim default)
local float_term = function()
  Snacks.terminal.toggle(nil, {
    win = {
      style = "float",
      width = 0.8,
      height = 0.8,
      border = "rounded",
    },
  })
end
vim.keymap.set({ "n", "t" }, "<C-/>", float_term, { desc = "Toggle Terminal" })
vim.keymap.set({ "n", "t" }, "<C-_>", float_term, { desc = "Toggle Terminal" })
