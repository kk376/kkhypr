-- ==============================================================================
-- Colorscheme Configuration (Catppuccin Mocha with Transparent Background)
-- ==============================================================================

return {
  {
    "catppuccin/nvim",
    name = "catppuccin",
    lazy = false,    -- Load immediately during startup so colorscheme is present
    priority = 1000, -- Highest priority to ensure it loads before other UI plugins
    opts = {
      flavour = "mocha",
      transparent_background = true,
      styles = {
        comments = { "italic" },
        conditionals = { "italic" },
        loops = {},
        functions = {},
        keywords = { "italic" },
        strings = {},
        variables = {},
        numbers = {},
        booleans = {},
        properties = {},
        types = {},
        operators = {},
      },
    },
    config = function(_, opts)
      require("catppuccin").setup(opts)
      vim.cmd.colorscheme("catppuccin")
    end,
  },
}
