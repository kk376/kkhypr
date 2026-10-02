-- ==============================================================================
-- Colorscheme Configuration (Noctalia Theme with Transparent Background)
-- ==============================================================================

return {
  {
    "catppuccin/nvim",
    name = "catppuccin",
    lazy = false,
    priority = 1000,
    opts = {
      flavour = "mocha",
      transparent_background = true,
      color_overrides = {
        mocha = {
          base = "#070722",
          mantle = "#070722",
          crust = "#050518",
          surface0 = "#11112d",
          surface1 = "#18183c",
          surface2 = "#21215f",
          text = "#f3edf7",
          subtext1 = "#e6e1e5",
          subtext0 = "#a9aefe",
          overlay2 = "#938f99",
          overlay1 = "#79747e",
          overlay0 = "#6c7086",
          lavender = "#a9aefe",
          blue = "#a9aefe",
          sapphire = "#9bfece",
          teal = "#9bfece",
          green = "#9bfece",
          yellow = "#fff59b",
          peach = "#fff59b",
          maroon = "#fd4663",
          red = "#fd4663",
          mauve = "#a9aefe",
          pink = "#fd4663",
          flamingo = "#fd4663",
          rosewater = "#f3edf7",
        },
      },
      custom_highlights = function(colors)
        return {
          Normal = { bg = "NONE", fg = colors.text },
          NormalFloat = { bg = "NONE", fg = colors.text },
          FloatBorder = { bg = "NONE", fg = colors.lavender },
          CursorLine = { bg = "#11112d" },
          CursorLineNr = { fg = colors.yellow, bold = true },
          LineNr = { fg = colors.overlay0 },
          Search = { bg = colors.yellow, fg = colors.base },
          IncSearch = { bg = colors.lavender, fg = colors.base },
          Visual = { bg = colors.surface2 },
          Function = { fg = colors.lavender, bold = true },
          Keyword = { fg = colors.red, italic = true },
          Statement = { fg = colors.red },
          String = { fg = colors.green },
          Constant = { fg = colors.yellow },
          Number = { fg = colors.yellow },
          Boolean = { fg = colors.yellow },
          Type = { fg = colors.yellow },
          Comment = { fg = colors.overlay0, italic = true },
          Identifier = { fg = colors.text },
          Operator = { fg = colors.text },
        }
      end,
      styles = {
        comments = { "italic" },
        conditionals = { "italic" },
        keywords = { "italic" },
      },
    },
    config = function(_, opts)
      require("catppuccin").setup(opts)
      vim.cmd.colorscheme("catppuccin-mocha")
    end,
  },
}
