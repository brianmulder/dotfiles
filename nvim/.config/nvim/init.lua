-- Modern Neovim config (requires a recent Neovim).
-- This is intentionally minimal and fast.

if vim.fn.has("nvim-0.11") == 0 then
  vim.api.nvim_echo({
    { "dotfiles nvim config requires Neovim >= 0.11 (current: ", "WarningMsg" },
    { vim.version().major .. "." .. vim.version().minor .. "." .. vim.version().patch, "WarningMsg" },
    { ")", "WarningMsg" },
  }, true, {})
  return
end

pcall(function()
  vim.loader.enable()
end)

vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

vim.g.mapleader = " "

vim.opt.termguicolors = true
vim.opt.number = true
vim.opt.mouse = "a"
vim.opt.clipboard = "unnamedplus"
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.signcolumn = "yes"
vim.opt.updatetime = 250

-- Indentation: keep it simple and predictable.
vim.opt.expandtab = true
vim.opt.shiftwidth = 2
vim.opt.tabstop = 2
vim.opt.softtabstop = 2
vim.opt.shiftround = true

-- Keep Neovim's swap/backup files out of project directories and off slow filesystems (WSL /mnt/*).
do
  local state = vim.fn.stdpath("state")
  local swap_dir = state .. "/swap"
  local backup_dir = state .. "/backup"
  vim.fn.mkdir(swap_dir, "p")
  vim.fn.mkdir(backup_dir, "p")
  vim.opt.directory = swap_dir .. "//"
  vim.opt.backupdir = backup_dir .. "//"
  vim.opt.backupskip:append({ "/mnt/*" })
end

-- WSL /mnt/*: prioritize fast saves over maximum durability.
-- DrvFs can make `:w` painfully slow when `fsync`/`writebackup` are enabled.
do
  local function is_windows_mnt(path)
    return type(path) == "string" and path:match("^/mnt/[a-zA-Z]/") ~= nil
  end

  local default_fsync = vim.o.fsync
  local default_writebackup = vim.o.writebackup

  vim.api.nvim_create_autocmd({ "BufEnter", "BufWinEnter", "BufFilePost" }, {
    callback = function(args)
      local path = vim.api.nvim_buf_get_name(args.buf)
      if is_windows_mnt(path) then
        vim.o.fsync = false
        vim.o.writebackup = false
      else
        vim.o.fsync = default_fsync
        vim.o.writebackup = default_writebackup
      end
    end,
    desc = "WSL /mnt/* fast saves: disable fsync/writebackup in active buffer",
  })
end

-- Spelling: keep prose checking built-in/lightweight; avoid external grammar LSPs.
do
  local spell_dir = vim.fn.stdpath("state") .. "/spell"
  vim.fn.mkdir(spell_dir, "p")
  vim.opt.spellfile = spell_dir .. "/en.utf-8.add"
end
vim.opt.spelllang = { "en_us" }
vim.opt.spelloptions:append("camel")
vim.keymap.set("n", "<leader>ss", "<cmd>setlocal spell!<cr>", { desc = "Toggle spellcheck" })

if vim.fn.executable("rg") == 1 then
  vim.opt.grepprg = "rg --vimgrep --smart-case"
  vim.opt.grepformat = "%f:%l:%c:%m"
end

vim.api.nvim_create_user_command("GrepF", function(opts)
  vim.cmd("silent grep! --fixed-strings -- " .. vim.fn.shellescape(opts.args))
  vim.cmd("copen")
end, { nargs = "+", desc = "Literal grep (rg -F) into quickfix" })

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.uv.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable",
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
  { "nvim-tree/nvim-web-devicons", lazy = true },
  {
    "catppuccin/nvim",
    name = "catppuccin",
    lazy = false,
    priority = 1000,
    config = function()
      local ok, catppuccin = pcall(require, "catppuccin")
      if not ok then
        return
      end
      catppuccin.setup({
        flavour = "mocha",
        integrations = {
          lualine = {},
          mason = true,
          nvimtree = true,
        },
      })
      pcall(vim.cmd.colorscheme, "catppuccin-mocha")
    end,
  },
  {
    "nvim-lualine/lualine.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons", "catppuccin" },
    event = "VeryLazy",
    config = function()
      local theme = "auto"
      do
        local ok, lualine_catppuccin = pcall(require, "catppuccin.utils.lualine")
        if ok then
          if type(lualine_catppuccin) == "function" then
            theme = lualine_catppuccin()
          elseif type(lualine_catppuccin) == "table" and type(lualine_catppuccin.get) == "function" then
            theme = lualine_catppuccin.get()
          end
        end
      end

      require("lualine").setup({
        options = {
          theme = theme,
          icons_enabled = true,
          section_separators = { left = "", right = "" },
          component_separators = { left = "", right = "" },
          globalstatus = true,
        },
        sections = {
          lualine_a = { "mode" },
          lualine_b = { "branch", "diff" },
          lualine_c = { { "filename", path = 1 } },
          lualine_x = { "diagnostics", "filetype" },
          lualine_y = { "progress" },
          lualine_z = { "location" },
        },
        inactive_sections = {
          lualine_a = {},
          lualine_b = {},
          lualine_c = { { "filename", path = 1 } },
          lualine_x = { "location" },
          lualine_y = {},
          lualine_z = {},
        },
      })
    end,
  },
  {
    "ibhagwan/fzf-lua",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    cmd = { "FzfLua" },
    keys = {
      { "<leader>ff", "<cmd>FzfLua files<cr>", desc = "Find files" },
      { "<leader>fg", "<cmd>FzfLua live_grep<cr>", desc = "Live grep" },
      {
        "<leader>fF",
        function()
          local ok, fzf = pcall(require, "fzf-lua")
          if not ok then
            return
          end
          fzf.live_grep({
            no_ignore = true,
            no_ignore_parent = true,
            hidden = true,
            follow = true,
            rg_opts = "--column --line-number --no-heading --color=always --smart-case --max-columns=4096 --hidden --follow --glob '!**/.git/*' --glob '!**/node_modules/*' --glob '!**/dist/*' --glob '!**/build/*' --glob '!**/.next/*' -e",
          })
        end,
        desc = "Live grep (all files)",
      },
      { "<leader>fb", "<cmd>FzfLua buffers<cr>", desc = "Buffers" },
    },
    config = function()
      local ok, fzf = pcall(require, "fzf-lua")
      if not ok then
        return
      end
      fzf.setup({})
    end,
  },
  {
    "nvim-tree/nvim-tree.lua",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    cmd = { "NvimTreeToggle", "NvimTreeOpen", "NvimTreeFindFile", "NvimTreeFocus" },
    keys = {
      { "<leader>e", "<cmd>NvimTreeToggle<cr>", desc = "Explorer" },
    },
    config = function()
      local ok, tree = pcall(require, "nvim-tree")
      if not ok then
        return
      end
      local function is_windows_mnt(path)
        return type(path) == "string" and path:match("^/mnt/[a-zA-Z]/") ~= nil
      end

      local cwd = (vim.uv or vim.loop).cwd()
      if cwd == nil or cwd == "" then
        cwd = vim.fn.getcwd()
      end

      local arg0 = vim.fn.argv(0)
      if type(arg0) == "string" and arg0 ~= "" then
        arg0 = vim.fn.fnamemodify(arg0, ":p")
      else
        arg0 = nil
      end

      local on_mnt = is_windows_mnt(cwd) or is_windows_mnt(arg0)
      tree.setup({
        -- Avoid blocking `:w` on slow filesystems (WSL /mnt/* can be brutal).
        auto_reload_on_write = false,
        filesystem_watchers = { enable = not on_mnt },
        git = { enable = not on_mnt },
        renderer = { highlight_git = not on_mnt, icons = { show = { git = not on_mnt } } },
        update_focused_file = { enable = not on_mnt },
        reload_on_bufenter = not on_mnt,
      })
      if vim.g.dotfiles_open_tree_on_start == true then
        vim.api.nvim_create_autocmd("VimEnter", {
          callback = function()
            if #vim.api.nvim_list_uis() == 0 then
              return
            end
            if vim.fn.exists(":NvimTreeOpen") ~= 2 then
              return
            end
            vim.cmd("silent! NvimTreeOpen")
            pcall(vim.cmd, "wincmd p")
          end,
          desc = "Open file tree on start",
        })
      end
    end,
  },
  {
    "williamboman/mason.nvim",
    cmd = { "Mason" },
    event = "VeryLazy",
    config = function()
      require("mason").setup({})
    end,
  },
  {
    "neovim/nvim-lspconfig",
    event = { "BufReadPre", "BufNewFile" },
    config = function()
      vim.api.nvim_create_autocmd("LspAttach", {
        callback = function(args)
          local bufnr = args.buf
          local map = function(lhs, rhs, desc)
            vim.keymap.set("n", lhs, rhs, { buffer = bufnr, desc = desc })
          end
          map("gd", vim.lsp.buf.definition, "Go to definition")
          map("gr", vim.lsp.buf.references, "References")
          map("K", vim.lsp.buf.hover, "Hover")
          map("<leader>rn", vim.lsp.buf.rename, "Rename")
          map("<leader>ca", vim.lsp.buf.code_action, "Code action")
        end,
      })

      vim.lsp.config("lua_ls", {
        settings = {
          Lua = {
            diagnostics = { globals = { "vim" } },
            workspace = { checkThirdParty = false },
          },
        },
      })

    end,
  },
  {
    "mason-org/mason-lspconfig.nvim",
    dependencies = { "williamboman/mason.nvim", "neovim/nvim-lspconfig" },
    event = { "BufReadPre", "BufNewFile" },
    config = function()
      require("mason-lspconfig").setup({
        ensure_installed = { "lua_ls" },
        automatic_enable = true,
      })
    end,
  },
}, {
  defaults = { lazy = true },
  performance = {
    rtp = {
      disabled_plugins = {
        "gzip",
        "matchit",
        "matchparen",
        "netrwPlugin",
        "tarPlugin",
        "tohtml",
        "tutor",
        "zipPlugin",
      },
    },
  },
})

-- Codex: keep it simple. This is just a convenience toggle for `:terminal codex`.
do
  local state = {
    bufnr = nil,
    winid = nil,
    job_id = nil,
  }

  local function is_valid_buf(bufnr)
    return bufnr ~= nil and vim.api.nvim_buf_is_valid(bufnr)
  end

  local function is_valid_win(winid)
    return winid ~= nil and vim.api.nvim_win_is_valid(winid)
  end

  local function is_job_running(job_id)
    if job_id == nil then
      return false
    end
    local ok, res = pcall(vim.fn.jobwait, { job_id }, 0)
    return ok and type(res) == "table" and res[1] == -1
  end

  local function ensure_buf()
    if is_valid_buf(state.bufnr) then
      return state.bufnr
    end

    local bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(bufnr, "term://codex")
    vim.bo[bufnr].bufhidden = "hide"
    vim.bo[bufnr].swapfile = false
    state.bufnr = bufnr
    return bufnr
  end

  local function open_float(bufnr)
    if is_valid_win(state.winid) and vim.api.nvim_win_get_buf(state.winid) == bufnr then
      vim.api.nvim_set_current_win(state.winid)
      return state.winid
    end

    local width = math.max(20, math.floor(vim.o.columns * 0.9))
    local height = math.max(5, math.floor(vim.o.lines * 0.8))
    local col = math.floor((vim.o.columns - width) / 2)
    local row = math.floor((vim.o.lines - height) / 2 - 1)
    if row < 0 then
      row = 0
    end

    local winid = vim.api.nvim_open_win(bufnr, true, {
      relative = "editor",
      style = "minimal",
      border = "rounded",
      width = width,
      height = height,
      col = col,
      row = row,
    })

    state.winid = winid
    return winid
  end

  local function ensure_job()
    if is_job_running(state.job_id) then
      return state.job_id
    end

    if vim.fn.executable("codex") ~= 1 then
      vim.notify("`codex` not on PATH", vim.log.levels.WARN)
      return nil
    end

    local bufnr = ensure_buf()
    open_float(bufnr)

    vim.api.nvim_buf_call(bufnr, function()
      state.job_id = vim.fn.termopen({ "codex" }, {
        on_exit = function()
          vim.schedule(function()
            state.job_id = nil
          end)
        end,
      })
    end)

    if not state.job_id or state.job_id <= 0 then
      vim.notify("failed to start `codex`", vim.log.levels.WARN)
      state.job_id = nil
      return nil
    end

    vim.cmd("startinsert")
    return state.job_id
  end

  local function close_window()
    if is_valid_win(state.winid) then
      pcall(vim.api.nvim_win_close, state.winid, true)
    end
    state.winid = nil
  end

  local function toggle()
    if is_valid_win(state.winid) then
      close_window()
      return
    end

    local bufnr = ensure_buf()
    open_float(bufnr)
    ensure_job()
  end

  local function stop()
    close_window()
    if is_job_running(state.job_id) then
      vim.fn.jobstop(state.job_id)
    end
    state.job_id = nil
  end

  vim.api.nvim_create_user_command("Codex", toggle, { desc = "Toggle `:terminal codex` (float)" })
  vim.keymap.set("n", "<leader>ac", toggle, { desc = "Codex terminal toggle" })

  vim.api.nvim_create_autocmd("VimLeavePre", {
    callback = stop,
    desc = "Stop Codex terminal on exit",
  })
end
