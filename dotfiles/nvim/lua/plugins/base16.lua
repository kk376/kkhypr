return { 'RRethy/base16-nvim',
  config = function()
    local ok, matugen = pcall(require, 'matugen')
    if ok then matugen.setup() end
    local transparent_groups = { "Normal", "NormalNC", "SignColumn", "EndOfBuffer", "FoldColumn", "LineNr", "CursorLineNr" }
    for _, group in ipairs(transparent_groups) do
      vim.api.nvim_set_hl(0, group, { bg = "NONE", ctermbg = "NONE" })
    end
  end,
}
