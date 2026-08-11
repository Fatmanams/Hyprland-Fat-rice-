-- =============================================================================
-- init.lua — Neovim config for the linux-rice.
--
-- Single-file, minimal-by-design, no plugin manager. Pulls colors from
-- pywal16's cache (~/.cache/wal/colors.json) so that tree-sitter
-- highlighting + statusline match the rest of the rice (waybar, swaync,
-- rofi, eww, ghostty all get their palette from the same source).
--
-- This is intentionally NOT a full IDE setup — that's what Zed is for.
-- Use nvim for:
--   * quick edits from inside hydractl, scripts, terminal-only sessions
--   * sudoedit-style edits where you want syntax-aware highlighting
--   * git commit messages (~/.config/git/config sets editor=nvim if you
--     want that; we leave git's editor alone and let $EDITOR=zed --wait win)
--
-- If you want this to be more than a nice editor with pywal colors,
-- drop your plugin manager of choice in here. Lazy / packer / mini.deps
-- all work fine downstream of this file.
-- =============================================================================

-- ---- leader = space, vim-style -----------------------------------------------
vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

-- ---- Quality of life ---------------------------------------------------------
vim.opt.number = true          -- show line numbers
vim.opt.relativenumber = true  -- relative for easier j/k jumps
vim.opt.signcolumn = "yes"     -- always show sign column (no scrolloff jitter)
vim.opt.cursorline = true
vim.opt.expandtab = true
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.softtabstop = 4
vim.opt.smartindent = true
vim.opt.autoindent = true
vim.opt.termguicolors = true
vim.opt.splitright = true
vim.opt.splitbelow = true
vim.opt.scrolloff = 4
vim.opt.sidescrolloff = 8
vim.opt.showmode = false       -- mode shown in statusline below
vim.opt.completeopt = { "menu", "menuone", "noselect" }
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.inccommand = "split"
vim.opt.updatetime = 250
vim.opt.timeoutlen = 400
vim.opt.clipboard = "unnamedplus"  -- wayland clipboard via wl-clipboard
vim.opt.undofile = true
vim.opt.swapfile = false
vim.opt.backup = false

-- ---- Filetype detection + tree-sitter-ish formatting ------------------------
vim.filetype.add({
  extension = {
    rs = "rust",
    py = "python",
    c = "c",
    h = "c",
    cpp = "cpp",
    cc = "cpp",
    cxx = "cpp",
    hpp = "cpp",
    hh = "cpp",
    lua = "lua",
    java = "java",
    json = "json",
    toml = "toml",
    yaml = "yaml",
    yml = "yaml",
    md = "markdown",
  },
})

-- ---- Try pywal16 colors first; fall back to built-in scheme ----------------
-- pywal writes ~/.cache/wal/colors.vim on every run when invoked with the
-- right flag (`wal -i <image>`), and also colors.json (machine-readable).
-- The .vim file is a runtime/colors/matrx-style colorscheme; if missing,
-- we drop back to a Catppuccin-Mocha-like set baked here.

local wal_vim_path = vim.fn.expand("~/.cache/wal/colors.vim")
local wal_enabled = false

if vim.fn.filereadable(wal_vim_path) == 1 then
  -- pywal16's colors.vim defines a `pywal` colorscheme that uses the
  -- cached palette. Sourceing it makes `colorscheme pywal` available.
  vim.cmd("source " .. wal_vim_path)
  wal_enabled = true
end

-- Baked fallback palette (Catppuccin Mocha approximation) used as the
-- terminal-color and highlight basis when wal hasn't run yet, so that
-- cold-first-boot render still looks coherent.
local mocha = {
  bg        = "#1e1e2e",
  bg_alt    = "#181825",
  fg        = "#cdd6f4",
  red       = "#f38ba8",
  green     = "#a6e3a1",
  yellow    = "#f9e2af",
  blue      = "#89b4fa",
  magenta   = "#f5c2e7",
  cyan      = "#94e2d5",
  comment   = "#6c7086",
  selection = "#585b70",
  border    = "#313244",
}

if wal_enabled then
  vim.cmd("colorscheme pywal")
else
  -- Minimal manual highlight setup since there's no plugin manager.
  vim.cmd("highlight clear")
  vim.cmd("syntax on")

  -- General highlights
  local hl = vim.api.nvim_set_hl
  hl(0, "Normal",       { bg = mocha.bg, fg = mocha.fg })
  hl(0, "NormalNC",     { bg = mocha.bg, fg = mocha.fg })
  hl(0, "Comment",      { fg = mocha.comment, italic = true })
  hl(0, "Constant",     { fg = mocha.yellow })
  hl(0, "String",       { fg = mocha.green })
  hl(0, "Identifier",   { fg = mocha.blue })
  hl(0, "Function",     { fg = mocha.blue, bold = true })
  hl(0, "Statement",    { fg = mocha.magenta })
  hl(0, "Operator",     { fg = mocha.fg })
  hl(0, "PreProc",      { fg = mocha.blue })
  hl(0, "Type",         { fg = mocha.cyan })
  hl(0, "Special",      { fg = mocha.red })
  hl(0, "Error",        { fg = mocha.red, bg = mocha.bg, bold = true })
  hl(0, "Todo",         { fg = mocha.yellow, bg = mocha.bg, bold = true })
  hl(0, "MatchParen",   { bg = mocha.selection })
  hl(0, "LineNr",       { fg = mocha.comment })
  hl(0, "CursorLine",   { bg = mocha.bg_alt })
  hl(0, "CursorLineNr", { fg = mocha.yellow, bold = true })
  hl(0, "Visual",       { bg = mocha.selection })
  hl(0, "Search",       { bg = mocha.blue, fg = mocha.bg })
  hl(0, "IncSearch",    { bg = mocha.yellow, fg = mocha.bg })
  hl(0, "Pmenu",        { bg = mocha.bg_alt, fg = mocha.fg })
  hl(0, "PmenuSel",     { bg = mocha.blue, fg = mocha.bg })
  hl(0, "VertSplit",    { fg = mocha.border })
  hl(0, "SignColumn",   { bg = mocha.bg })
  hl(0, "StatusLine",   { bg = mocha.bg_alt, fg = mocha.fg, bold = true })
  hl(0, "StatusLineNC", { bg = mocha.bg_alt, fg = mocha.comment })
  hl(0, "TabLine",      { bg = mocha.bg_alt, fg = mocha.comment })
  hl(0, "TabLineSel",   { bg = mocha.bg_alt, fg = mocha.fg, bold = true })
  hl(0, "TabLineFill",  { bg = mocha.bg_alt })
end

-- ---- Statusline (no plugin) ------------------------------------------------
local function statusline()
  local mode_map = {
    n   = " NORMAL ",
    i   = " INSERT ",
    v   = " VISUAL ",
    V   = " V-LINE ",
    ["\22"] = " V-BLOCK ",
    c   = " CMD ",
    R   = " REPLACE ",
    s   = " SELECT ",
    S   = " S-LINE ",
    t   = " TERM ",
  }
  local m = mode_map[vim.fn.mode()] or " " .. vim.fn.mode() .. " "
  local file = "%f"
  local mod  = "%m"
  local line = "  %l/%L:%c"
  return m .. " " .. file .. mod .. line .. "%=" .. (wal_enabled and " [pywal] " or " [mocha] ") .. "%y "
end

vim.opt.statusline = "%!v:lua.statusline()"
_G.statusline = statusline

-- ---- Keymaps (sensible defaults + a couple of nicities) -------------------
local map = function(lhs, rhs, desc)
  vim.keymap.set("n", lhs, rhs, { desc = desc, silent = true })
end
map("<leader>w", ":write<CR>",       "write")
map("<leader>q", ":quit<CR>",        "quit")
map("<leader>x", ":x<CR>",            "write+quit")
map("<leader>e", ":Lexplore<CR>",    "file explorer (built-in netrw)")
map("<leader>/", ":nohlsearch<CR>",  "clear search")
map("<leader>t", ":terminal<CR>",    "open terminal split")
map("<Esc>",     "<C-\\><C-n>",      "exit terminal mode")  -- also in t-mode

-- Window nav like Hyprland (mod + h/j/k/l)
map("<C-h>", "<C-w>h", "window left")
map("<C-j>", "<C-w>j", "window down")
map("<C-k>", "<C-w>k", "window up")
map("<C-l>", "<C-w>l", "window right")

-- Auto-reload on external file change (used by wal + zed + ghostty cross-edits)
vim.opt.autoread = true
vim.api.nvim_create_autocmd({ "FocusGained", "BufEnter" }, {
  pattern = "*",
  command = "checktime",
})
