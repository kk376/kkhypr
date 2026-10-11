-- ==============================================================================
-- Colorscheme Configuration (TokyoNight & Catppuccin with Transparent Background)
-- ==============================================================================

return {
  {
    "folke/tokyonight.nvim",
    opts = {
      transparent = true,
      styles = {
        sidebars = "transparent",
        floats = "transparent",
      },
    },
  },
  {
    "catppuccin/nvim",
    name = "catppuccin",
    opts = {
      flavour = "mocha",
      transparent_background = true,
      styles = {
        sidebars = "transparent",
        floats = "transparent",
      },
    },
  },
}
