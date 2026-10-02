-- ==============================================================================
-- Treesitter Syntax Highlighting Configuration
-- ==============================================================================
-- nvim-treesitter main branch (post v0.10.0) only provides parser installation.
-- Highlighting and indentation are handled by Neovim's built-in treesitter
-- support (vim.treesitter.start), which is enabled by default since Neovim 0.11.

return {
  {
    "nvim-treesitter/nvim-treesitter",
    branch = "main",
    build = ":TSUpdate",
    event = { "BufReadPost", "BufNewFile" },
    cmd = { "TSUpdate", "TSInstall" },
    config = function()
      require("nvim-treesitter").setup({})

      -- Ensure parsers are installed for commonly used languages
      local wanted = {
        "bash",
        "c",
        "css",
        "diff",
        "html",
        "hyprlang",
        "javascript",
        "json",
        "lua",
        "luadoc",
        "markdown",
        "markdown_inline",
        "python",
        "query",
        "regex",
        "rust",
        "toml",
        "tsx",
        "typescript",
        "vim",
        "vimdoc",
        "yaml",
      }

      -- Install any missing parsers asynchronously on first load
      local installed = require("nvim-treesitter.config").get_installed("parsers")
      local missing = vim.tbl_filter(function(lang)
        return not vim.list_contains(installed, lang)
      end, wanted)

      if #missing > 0 then
        vim.cmd("TSInstall " .. table.concat(missing, " "))
      end
    end,
  },
}
