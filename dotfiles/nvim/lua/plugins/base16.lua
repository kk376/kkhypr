return {
  "RRethy/base16-nvim",
  lazy = false,
  priority = 900,
  config = function()
    local function apply_transparency()
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

    -- Hook base16-colorscheme setup to guarantee transparency is preserved
    -- whenever colors are applied (including real-time SIGUSR1 wallpaper updates)
    local ok_base16, base16 = pcall(require, "base16-colorscheme")
    if ok_base16 and base16.setup then
      local orig_setup = base16.setup
      base16.setup = function(...)
        orig_setup(...)
        apply_transparency()
      end
    end

    local function reload_theme()
      package.loaded["matugen"] = nil
      local ok, matugen = pcall(require, "matugen")
      if ok and matugen.setup then
        matugen.setup()
      end
      apply_transparency()
    end

    -- Initial load on Neovim startup
    reload_theme()

    -- Re-enforce transparency whenever colorscheme changes
    vim.api.nvim_create_autocmd({ "ColorScheme", "VimEnter" }, {
      pattern = "*",
      callback = apply_transparency,
    })

    -- Handle SIGUSR1 broadcasts from Noctalia theme hooks
    if _G.__noctalia_sigusr1 then
      _G.__noctalia_sigusr1:stop()
      _G.__noctalia_sigusr1:close()
    end
    local sig = vim.uv.new_signal()
    _G.__noctalia_sigusr1 = sig
    sig:start("sigusr1", vim.schedule_wrap(function()
      reload_theme()
    end))

    -- Watch matugen.lua for real-time filesystem updates when Noctalia writes new palettes
    local matugen_path = vim.fn.stdpath("config") .. "/lua/matugen.lua"
    if _G.__noctalia_fs_watcher then
      _G.__noctalia_fs_watcher:stop()
      _G.__noctalia_fs_watcher:close()
    end
    local watcher = vim.uv.new_fs_event()
    _G.__noctalia_fs_watcher = watcher
    if watcher and vim.uv.fs_stat(matugen_path) then
      watcher:start(matugen_path, {}, vim.schedule_wrap(function(err, fname, events)
        if not err then
          reload_theme()
        end
      end))
    end
  end,
}
