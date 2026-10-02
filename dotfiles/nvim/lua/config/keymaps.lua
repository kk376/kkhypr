-- ==============================================================================
-- Neovim Core Ergonomic Keymaps
-- ==============================================================================

local map = vim.keymap.set

-- Visual line navigation for wrapped lines (VS Code and Zed ergonomics)
-- Moves visually across wrapped lines when uncounted; preserves physical line jumps with counts (e.g. 5j)
map({ "n", "v" }, "j", "v:count == 0 ? 'gj' : 'j'", { expr = true, silent = true, desc = "Down visual line" })
map({ "n", "v" }, "k", "v:count == 0 ? 'gk' : 'k'", { expr = true, silent = true, desc = "Up visual line" })
map({ "n", "v" }, "<Down>", "v:count == 0 ? 'gj' : 'j'", { expr = true, silent = true, desc = "Down visual line" })
map({ "n", "v" }, "<Up>", "v:count == 0 ? 'gk' : 'k'", { expr = true, silent = true, desc = "Up visual line" })
