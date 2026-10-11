-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua

-- Ensure transparent background across all colorschemes for compositor blur
vim.api.nvim_create_autocmd({ "ColorScheme", "VimEnter" }, {
  group = vim.api.nvim_create_augroup("TransparentBackground", { clear = true }),
  callback = function()
    local groups = {
      "Normal",
      "NormalNC",
      "NormalFloat",
      "FloatBorder",
      "FloatTitle",
      "SignColumn",
      "FoldColumn",
      "LineNr",
      "CursorLineNr",
      "EndOfBuffer",
      "MsgArea",
      "NeoTreeNormal",
      "NeoTreeNormalNC",
      "NeoTreeEndOfBuffer",
    }
    for _, group in ipairs(groups) do
      vim.api.nvim_set_hl(0, group, { bg = "none", ctermbg = "none" })
    end
  end,
})
