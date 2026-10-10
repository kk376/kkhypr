-- ==============================================================================
-- Neovim Core Ergonomic Options
-- ==============================================================================

local opt = vim.opt

-- Colors & Appearance
opt.termguicolors = true -- 24-bit RGB colors in terminal (required for Catppuccin)
opt.cursorline = true    -- Highlight current screen line
opt.cursorlineopt = "number" -- Highlight line number only to avoid redrawing full terminal rows
opt.signcolumn = "yes"   -- Always show sign column to prevent layout jumps

-- Line Numbers
opt.number = true        -- Print line number
opt.relativenumber = true -- Relative line numbers for efficient motions

-- Indentation & Tabs
opt.expandtab = true     -- Use spaces instead of tabs
opt.shiftwidth = 2       -- Number of spaces for indent
opt.tabstop = 2          -- Number of spaces tabs count for
opt.smartindent = true   -- Smart autoindenting for new lines

-- Search Behavior
opt.ignorecase = true    -- Ignore case in search patterns
opt.smartcase = true     -- Override ignorecase if search pattern contains uppercase
opt.hlsearch = true      -- Highlight search matches
opt.incsearch = true     -- Incremental search

-- System Integration
opt.mouse = "a"          -- Enable mouse support in all modes
opt.clipboard = "unnamedplus" -- Sync with system clipboard
opt.updatetime = 250     -- Faster completion and diagnostic updates (default 4000ms)
opt.timeoutlen = 300     -- Time in milliseconds to wait for a mapped sequence

-- Performance & Smooth Scrolling
opt.smoothscroll = true  -- Smooth viewport scrolling for wrapped lines
opt.scrolloff = 4        -- Minimum screen lines to keep above and below cursor
opt.sidescrolloff = 8    -- Minimum screen columns to keep to the left and right
opt.synmaxcol = 300      -- Limit syntax highlighting to first 300 columns to avoid regex lag
vim.g.matchparen_timeout = 5 -- Cap paren matching scan time to 5ms to prevent cursor motion stalls
vim.g.matchparen_insert_timeout = 5

-- Splits & Windows
opt.splitright = true    -- Put new vertical splits to the right of current
opt.splitbelow = true    -- Put new horizontal splits below current

-- Word Wrap (Soft wrap matching VS Code and Zed ergonomics)
opt.wrap = true          -- Enable soft line wrapping
opt.linebreak = true     -- Break lines at word boundaries rather than mid-word
opt.breakindent = true   -- Maintain line indentation on wrapped lines

-- Enforce transparent background so Neovim inherits Ghostty opacity and blur
local function set_transparent_background()
  local transparent_groups = {
    "Normal",
    "NormalNC",
    "NormalFloat",
    "FloatBorder",
    "SignColumn",
    "EndOfBuffer",
    "FoldColumn",
    "LineNr",
    "CursorLineNr",
    "StatusLine",
    "StatusLineNC",
    "WinSeparator",
  }
  for _, group in ipairs(transparent_groups) do
    vim.api.nvim_set_hl(0, group, { bg = "NONE", ctermbg = "NONE" })
  end
end

vim.api.nvim_create_autocmd({ "ColorScheme", "VimEnter" }, {
  pattern = "*",
  callback = set_transparent_background,
})
