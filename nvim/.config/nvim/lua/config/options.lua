-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here
vim.opt.relativenumber = false
vim.opt.winbar = "%=%{fnamemodify(getcwd(), ':t')}"

vim.api.nvim_create_autocmd("BufWinEnter", {
  callback = function()
    local cfg = vim.api.nvim_win_get_config(0)
    if cfg.relative ~= "" then return end
    vim.wo.winbar = "%=%{fnamemodify(getcwd(), ':t')}"
  end,
})
