-- =========================
-- LEADER KEY
-- =========================
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- =========================
-- BASIC SETTINGS
-- =========================
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.clipboard = "unnamedplus"
vim.opt.termguicolors = true
vim.opt.laststatus = 2
vim.opt.showmode = false
vim.opt.ruler = true
vim.opt.statusline = "%f %h%m%r %=%l:%c"
vim.opt.background = "dark"
vim.opt.swapfile = false
-- Use zsh so Oh My Zsh / agnoster load inside :terminal / ToggleTerm
vim.opt.shell = "/usr/bin/zsh"

-- Neovide settings
if vim.g.neovide then
  vim.g.neovide_cursor_vfx_mode = "railgun"
  vim.g.neovide_cursor_animation_length = 0.13
  vim.g.neovide_cursor_trail_size = 0.8
  vim.g.neovide_cursor_vfx_particle_lifetime = 1.2
  vim.g.neovide_cursor_vfx_particle_speed = 10.0
  vim.o.guifont = "Hack Nerd Font:h14"
end

-- Prefer Treesitter colors over flat LSP semantic tokens
vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(args)
    local client = vim.lsp.get_client_by_id(args.data.client_id)
    if client and client.server_capabilities.semanticTokensProvider then
      client.server_capabilities.semanticTokensProvider = nil
    end
  end,
})

-- =========================
-- BOOTSTRAP lazy.nvim
-- =========================
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"

if not vim.loop.fs_stat(lazypath) then
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

-- ========================= 
-- KEYMAPS
-- =========================
-- jj as Escape
vim.keymap.set("i", "jj", "<Esc>", { desc = "Exit insert mode" })
vim.keymap.set("v", "jj", "<Esc>", { desc = "Exit visual mode" })
vim.keymap.set("t", "jj", "<C-\\><C-n>", { desc = "Exit terminal mode" })

-- qa: save all, kill terminal/TUI jobs, then quit Neovim
vim.keymap.set("n", "qa", function()
  pcall(vim.cmd, "silent! wa")
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].buftype == "terminal" then
      pcall(vim.api.nvim_buf_delete, buf, { force = true })
    end
  end
  vim.cmd("qa!")
end, { desc = "Save all and quit" })

-- `cc` inserts /* | */ with cursor inside (C/C++/Go) — global map, checks filetype
local block_comment_fts = {
  c = true,
  cpp = true,
  objc = true,
  objcpp = true,
  cuda = true,
  go = true,
}

local function wants_block_comment()
  if block_comment_fts[vim.bo.filetype] then
    return true
  end
  -- fallback if filetype isn't set yet
  local name = vim.api.nvim_buf_get_name(0)
  return name:match("%.go$")
    or name:match("%.c$")
    or name:match("%.h$")
    or name:match("%.cc$")
    or name:match("%.cpp$")
    or name:match("%.cxx$")
    or name:match("%.hpp$")
    or name:match("%.hxx$")
    or name:match("%.cu$")
    or false
end

local function insert_block_comment()
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  local r = row - 1
  vim.api.nvim_buf_set_text(0, r, col, r, col, { "/*  */" })
  local insert_col = col + 3
  vim.schedule(function()
    if not vim.api.nvim_buf_is_valid(0) then
      return
    end
    vim.api.nvim_win_set_cursor(0, { row, insert_col })
    if not vim.api.nvim_get_mode().mode:find("i") then
      vim.cmd("startinsert")
    end
  end)
end

vim.keymap.set("n", "cc", function()
  if wants_block_comment() then
    insert_block_comment()
  else
    -- default Vim: change whole line
    local keys = vim.api.nvim_replace_termcodes("cc", true, false, true)
    vim.api.nvim_feedkeys(keys, "n!", false)
  end
end, { desc = "Block comment /* */ (c/cpp/go) or change line" })

vim.keymap.set("i", "cc", function()
  if wants_block_comment() then
    insert_block_comment()
  else
    local row, col = unpack(vim.api.nvim_win_get_cursor(0))
    vim.api.nvim_buf_set_text(0, row - 1, col, row - 1, col, { "cc" })
    vim.api.nvim_win_set_cursor(0, { row, col + 2 })
  end
end, { desc = "Insert /* */ block comment in c/cpp/go" })

vim.keymap.set("n", "<leader>ff", "<cmd>Telescope find_files<CR>")
vim.keymap.set("n", "<leader>fg", "<cmd>Telescope live_grep<CR>")
vim.keymap.set("n", "<leader>fw", "<cmd>Telescope grep_string<CR>")
vim.keymap.set("n", "<leader>fb", "<cmd>Telescope buffers<CR>")
vim.keymap.set("n", "<leader>e", "<cmd>NvimTreeToggle<CR>")

-- Visual mode: hjkl (and i) stay for selecting; u = move up, e = move down
vim.keymap.set("x", "u", ":m '<-2<CR>gv=gv", { desc = "Move selection up", silent = true })
vim.keymap.set("x", "e", ":m '>+1<CR>gv=gv", { desc = "Move selection down", silent = true })
vim.keymap.set("n", "<A-j>", "<cmd>m .+1<CR>==", { desc = "Move line down" })
vim.keymap.set("n", "<A-k>", "<cmd>m .-2<CR>==", { desc = "Move line up" })

-- Autosave (format-on-save via conform still runs on write)
vim.api.nvim_create_autocmd({ "InsertLeave", "FocusLost", "BufLeave" }, {
  pattern = "*",
  callback = function(args)
    local buf = args.buf
    if not vim.api.nvim_buf_is_valid(buf) then
      return
    end
    if vim.bo[buf].buftype ~= "" or not vim.bo[buf].modifiable or vim.bo[buf].readonly then
      return
    end
    if vim.bo[buf].modified and vim.bo[buf].filetype ~= "" then
      vim.api.nvim_buf_call(buf, function()
        vim.cmd("silent! update")
      end)
    end
  end,
  desc = "Autosave on leave insert / focus lost",
})

-- Window splits and navigation
vim.keymap.set("n", "vs", "<cmd>vsplit<CR>", { desc = "Vertical split" })
vim.keymap.set("n", "tt", "<cmd>ToggleTerm direction=float<CR>", { desc = "Floating terminal" })
-- th / Alt+h: toggle bottom horizontal terminal (Alt+h also works inside the terminal)
vim.keymap.set("n", "th", "<cmd>ToggleTerm direction=horizontal<CR>", { desc = "Horizontal terminal" })
vim.keymap.set({ "n", "t" }, "<A-h>", "<cmd>ToggleTerm direction=horizontal<CR>", { desc = "Toggle horizontal terminal" })
vim.keymap.set("n", "<leader>sv", "<C-w>v", { desc = "Split vertical" })
vim.keymap.set("n", "<leader>sh", "<C-w>s", { desc = "Split horizontal" })
vim.keymap.set("n", "<leader>se", "<C-w>=", { desc = "Equalize splits" })
vim.keymap.set("n", "<leader>sx", "<cmd>close<CR>", { desc = "Close split" })
vim.keymap.set("n", "<C-h>", "<C-w>h")
vim.keymap.set("n", "<C-j>", "<C-w>j")
vim.keymap.set("n", "<C-k>", "<C-w>k")
vim.keymap.set("n", "<C-l>", "<C-w>l")

-- Ctrl+1 file tree, Ctrl+2 first editor, Ctrl+3 second editor
local function leave_insert_or_terminal()
  local mode = vim.api.nvim_get_mode().mode
  if mode == "t" or mode:find("i") then
    vim.cmd("stopinsert")
  end
end

local function focus_file_tree()
  leave_insert_or_terminal()
  local ok, api = pcall(require, "nvim-tree.api")
  if ok then
    api.tree.open()
    api.tree.focus()
  else
    vim.cmd("NvimTreeFocus")
  end
end

local function editor_windows()
  local wins = {}
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local cfg = vim.api.nvim_win_get_config(win)
    if cfg.relative == "" then
      local buf = vim.api.nvim_win_get_buf(win)
      local ft = vim.bo[buf].filetype
      local bt = vim.bo[buf].buftype
      -- Keep terminals out of Ctrl+1/2/3 — only real editor windows
      if
        ft ~= "NvimTree"
        and ft ~= "neo-tree"
        and ft ~= "notify"
        and ft ~= "noice"
        and ft ~= "toggleterm"
        and bt ~= "terminal"
      then
        table.insert(wins, win)
      end
    end
  end
  table.sort(wins, function(a, b)
    local pa = vim.api.nvim_win_get_position(a)
    local pb = vim.api.nvim_win_get_position(b)
    if pa[2] ~= pb[2] then
      return pa[2] < pb[2]
    end
    return pa[1] < pb[1]
  end)
  return wins
end

local function focus_editor(n)
  leave_insert_or_terminal()
  local wins = editor_windows()
  if wins[n] then
    vim.api.nvim_set_current_win(wins[n])
  end
end

local window_nav_modes = { "n", "i", "v", "t" }
vim.keymap.set(window_nav_modes, "<C-1>", focus_file_tree, { desc = "Focus file explorer" })
vim.keymap.set(window_nav_modes, "<C-2>", function()
  focus_editor(1)
end, { desc = "Focus first window" })
vim.keymap.set(window_nav_modes, "<C-3>", function()
  focus_editor(2)
end, { desc = "Focus second window" })
-- Toggle autocomplete
local autocomplete_enabled = false
vim.keymap.set("n", "<leader>tc", function()
  local cmp = require("cmp")
  autocomplete_enabled = not autocomplete_enabled
  if autocomplete_enabled then
    cmp.setup({
      completion = { autocomplete = { require("cmp.types").cmp.TriggerEvent.TextChanged } },
      mapping = cmp.mapping.preset.insert({
        ["<C-Space>"] = cmp.mapping.complete(),
        ["<CR>"]      = cmp.mapping.confirm({ select = true }),
        ["<Tab>"]     = cmp.mapping.select_next_item(),
        ["<S-Tab>"]   = cmp.mapping.select_prev_item(),
      }),
    })
    vim.cmd("Copilot enable")   -- enable copilot
    print("Autocomplete ON")
  else
    cmp.setup({
      completion = { autocomplete = false },
      mapping = cmp.mapping.preset.insert({
        ["<C-Space>"] = cmp.mapping.complete(),
        ["<CR>"]      = cmp.mapping.confirm({ select = true }),
        ["<Tab>"]     = function() end,
        ["<S-Tab>"]   = function() end,
      }),
    })
    vim.cmd("Copilot disable")  -- disable copilot too
    print("Autocomplete OFF")
  end
end)

-- Format entire file
vim.keymap.set({ "n", "v" }, "<leader>fm", function()
  require("conform").format({ async = true, lsp_format = "fallback" })
end, { desc = "Format file" })

-- Git
vim.keymap.set("n", "<leader>gs", "<cmd>Git<CR>")
vim.keymap.set("n", "<leader>ga", "<cmd>Git add .<CR>")
vim.keymap.set("n", "<leader>gc", "<cmd>Git commit<CR>")
vim.keymap.set("n", "<leader>gd", "<cmd>DiffviewOpen<CR>")
vim.keymap.set("n", "<leader>gh", "<cmd>DiffviewFileHistory<CR>")
-- Persistent TUI floats: same key opens and closes (works in normal + terminal mode)
local tui_terminals = {}

local function toggle_tui(name, cmd, count)
  local Terminal = require("toggleterm.terminal").Terminal
  if not tui_terminals[name] then
    tui_terminals[name] = Terminal:new({
      cmd = cmd,
      count = count,
      direction = "float",
      float_opts = { border = "curved" },
      hidden = true,
      close_on_exit = true,
    })
  end
  tui_terminals[name]:toggle()
end

vim.keymap.set({ "n", "t" }, "<leader>lg", function()
  toggle_tui("lazygit", "lazygit", 10)
end, { desc = "Toggle LazyGit" })

vim.keymap.set({ "n", "t" }, "<leader>d", function()
  toggle_tui("lazydocker", "lazydocker", 11)
end, { desc = "Toggle LazyDocker" })

vim.keymap.set({ "n", "t" }, "<leader>k", function()
  toggle_tui("k9s", "k9s", 12)
end, { desc = "Toggle k9s" })

-- Harpoon
vim.keymap.set("n", "<leader>ha", function()
  require("harpoon"):list():add()
end)
vim.keymap.set("n", "<leader>hh", function()
  local harpoon = require("harpoon")
  harpoon.ui:toggle_quick_menu(harpoon:list())
end)
vim.keymap.set("n", "<leader>1", function()
  require("harpoon"):list():select(1)
end)
vim.keymap.set("n", "<leader>2", function()
  require("harpoon"):list():select(2)
end)
vim.keymap.set("n", "<leader>3", function()
  require("harpoon"):list():select(3)
end)
vim.keymap.set("n", "<leader>4", function()
  require("harpoon"):list():select(4)
end)

-- Kulala API testing
vim.keymap.set("n", "<leader>rr", "<cmd>lua require('kulala').run()<CR>")
vim.keymap.set("n", "<leader>rn", "<cmd>lua require('kulala').jump_next()<CR>")
vim.keymap.set("n", "<leader>rp", "<cmd>lua require('kulala').jump_prev()<CR>")
vim.keymap.set("n", "<leader>ri", "<cmd>lua require('kulala').inspect()<CR>")
-- Remote SSH 
vim.keymap.set("n", "<leader>rc", "<cmd>RemoteSSHFSConnect<CR>")
vim.keymap.set("n", "<leader>rd", "<cmd>RemoteSSHFSDisconnect<CR>")

-- Terminal splits
vim.keymap.set({ "n", "t" }, "<leader>th", "<cmd>ToggleTerm direction=horizontal<CR>", { desc = "Horizontal terminal" })
vim.keymap.set({ "n", "t" }, "<leader>tv", "<cmd>ToggleTerm direction=vertical<CR>", { desc = "Vertical terminal" })
vim.keymap.set({ "n", "t" }, "<leader>tf", "<cmd>ToggleTerm direction=float<CR>", { desc = "Floating terminal" })
vim.keymap.set("t", "<Esc>", "<C-\\><C-n>")

-- Hop
vim.keymap.set("n", "s", function() require("hop").hint_words() end)
vim.keymap.set("n", "S", function() require("hop").hint_lines() end)

--Git Tree
vim.keymap.set("n", "<leader>gl", "<cmd>Flog<CR>")

-- Markdown Preview
vim.keymap.set("n", "<leader>mo", "<cmd>PeekOpen<CR>")
vim.keymap.set("n", "<leader>mc", "<cmd>PeekClose<CR>")
vim.keymap.set("n", "<leader>mr", "<cmd>RenderMarkdown toggle<CR>", { desc = "Toggle in-editor markdown render" })
vim.keymap.set("n", "<leader>me", "<cmd>RenderMarkdown enable<CR>", { desc = "Enable markdown render" })
vim.keymap.set("n", "<leader>md", "<cmd>RenderMarkdown disable<CR>", { desc = "Disable markdown render" })

-- Overseer
vim.keymap.set("n", "<leader>or", "<cmd>OverseerRun<CR>")

-- Copilot Chat
vim.keymap.set("n", "<leader>cc", "<cmd>CopilotChat<CR>")
vim.keymap.set("n", "<leader>ce", "<cmd>CopilotChatExplain<CR>")
vim.keymap.set("n", "<leader>cf", "<cmd>CopilotChatFix<CR>")
vim.keymap.set("n", "<leader>ct", "<cmd>CopilotChatTests<CR>")
vim.keymap.set("n", "<leader>cr", "<cmd>CopilotChatReview<CR>")
vim.keymap.set("v", "<leader>cc", "<cmd>CopilotChat<CR>")

-- Trouble (error/diagnostics panel)
vim.keymap.set("n", "ee", "<cmd>Trouble diagnostics toggle filter.buf=0 focus=true<CR>", { desc = "Toggle error panel (current file)" })
vim.keymap.set("n", "<leader>xx", "<cmd>Trouble diagnostics toggle<CR>")
vim.keymap.set("n", "<leader>xw", "<cmd>Trouble workspace_diagnostics<CR>")

-- Database
vim.keymap.set("n", "<leader>db", "<cmd>DBUIToggle<CR>")

-- REST
vim.keymap.set("n", "<leader>rr", "<cmd>lua require('kulala').run()<CR>")

-- Spectre
vim.keymap.set("n", "<leader>S", "<cmd>lua require('spectre').open()<CR>")

-- Bufferline
vim.keymap.set("n", "<Tab>", "<cmd>BufferLineCycleNext<CR>")
vim.keymap.set("n", "<S-Tab>", "<cmd>BufferLineCyclePrev<CR>")

-- LSPSaga
vim.keymap.set("n", "<leader>ca", "<cmd>Lspsaga code_action<CR>")
vim.keymap.set("n", "K", "<cmd>Lspsaga hover_doc<CR>")
vim.keymap.set("n", "gd", "<cmd>Lspsaga goto_definition<CR>")
vim.keymap.set("n", "gr", "<cmd>Lspsaga finder<CR>")

-- Peek definition without leaving current file (VS Code Alt+F12 equivalent)
vim.keymap.set("n", "gp", "<cmd>Lspsaga peek_definition<CR>")

-- Peek type/struct definition in popup window
vim.keymap.set("n", "gt", "<cmd>Lspsaga peek_type_definition<CR>")

-- Go to implementation (built-in LSP)
vim.keymap.set("n", "gi", vim.lsp.buf.implementation)

-- Inc Rename
vim.keymap.set("n", "<leader>rn", ":IncRename ")

-- Neotest
vim.keymap.set("n", "<leader>tr", "<cmd>lua require('neotest').run.run()<CR>")
vim.keymap.set("n", "<leader>ts", "<cmd>lua require('neotest').summary.toggle()<CR>")

-- Undo
vim.keymap.set("n", "<C-z>", "u")
vim.keymap.set("i", "<C-z>", "<Esc>ui")

-- Search
vim.keymap.set("n", "<C-f>", "/")

-- =========================
-- PLUGINS
-- =========================
require("lazy").setup({
  rocks = { enabled = false },

  -- Treesitter (main branch required for Neovim 0.12+)
  {
    "nvim-treesitter/nvim-treesitter",
    lazy = false,
    branch = "main",
    build = ":TSUpdate",
    config = function()
      local parsers = {
        "c",
        "cpp",
        "go",
        "gomod",
        "gosum",
        "gowork",
        "lua",
        "vim",
        "vimdoc",
        "query",
        "python",
        "javascript",
        "typescript",
        "tsx",
        "json",
        "yaml",
        "toml",
        "markdown",
        "markdown_inline",
        "bash",
        "html",
        "css",
        "dockerfile",
        "sql",
      }

      require("nvim-treesitter").setup({})
      -- async install; no-op if already present
      pcall(function()
        require("nvim-treesitter").install(parsers)
      end)

      -- Highlight + indent via Neovim built-ins (main-branch API)
      vim.api.nvim_create_autocmd("FileType", {
        group = vim.api.nvim_create_augroup("TreesitterStart", { clear = true }),
        callback = function(ev)
          local ok_lang, lang = pcall(vim.treesitter.language.get_lang, vim.bo[ev.buf].filetype)
          if not ok_lang or not lang then
            return
          end
          local ok_parser = pcall(vim.treesitter.get_parser, ev.buf, lang)
          if not ok_parser then
            return
          end
          pcall(vim.treesitter.start, ev.buf)
          pcall(function()
            vim.bo[ev.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
          end)
        end,
      })
    end,
  },

  -- Telescope
  {
    "nvim-telescope/telescope.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
      version = false,  -- add this line

    config = function()
      require("telescope").setup({
        defaults = {
          layout_strategy = "horizontal",
          layout_config = {
            preview_width = 0.55,
            width = 0.87,
            height = 0.80,
          },
          file_ignore_patterns = {
            "node_modules", ".git", "dist", "build"
          },
        },
      })
    end,
  },

-- Git Graph (commit history tree)
{
  "rbong/vim-flog",
  dependencies = { "tpope/vim-fugitive" },
  cmd = { "Flog", "Flogsplit" },
},

-- Remote SSH editing (connect to GCP VM directly)
{
  "nosduco/remote-sshfs.nvim",
  dependencies = { "nvim-telescope/telescope.nvim" },
  config = function()
    require("remote-sshfs").setup()
    require("telescope").load_extension("remote-sshfs")
  end,
},

  -- Git
  { "tpope/vim-fugitive" },

  -- Diffview
  {
    "sindrets/diffview.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    config = function()
      require("diffview").setup()
    end,
  },

  -- Lazygit
  {
    "kdheepak/lazygit.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
  },

   {
     "nvim-tree/nvim-web-devicons",
        config = function()
            require("nvim-web-devicons").setup({
                default = true,
                -- warmer icon colors (less default blue)
                override_by_filename = {
                  [".gitignore"] = { icon = "", color = "#fc9867", name = "Gitignore" },
                },
                override_by_extension = {
                  ["cpp"] = { icon = "", color = "#fc9867", name = "Cpp" },
                  ["cc"] = { icon = "", color = "#fc9867", name = "Cpp" },
                  ["cxx"] = { icon = "", color = "#fc9867", name = "Cpp" },
                  ["h"] = { icon = "", color = "#a9dc76", name = "H" },
                  ["hpp"] = { icon = "", color = "#a9dc76", name = "Hpp" },
                  ["c"] = { icon = "", color = "#ffd866", name = "C" },
                  ["go"] = { icon = "", color = "#78dce8", name = "Go" },
                },
            })
        end,
    },

  -- File tree
  {
    "nvim-tree/nvim-tree.lua",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      require("nvim-tree").setup({
        view = {
          width = 35,
          side = "left",
        },
        renderer = {
          group_empty = true,
          icons = {
            show = {
              file = true,
              folder = true,
              git = true,
            },
          },
        },
        filters = { dotfiles = false },
        git = { enable = true },
      })
    end,
  },

  -- LSP core
  { "neovim/nvim-lspconfig" },

  -- Mason
  {
    "williamboman/mason.nvim",
    config = true,
  },

  {
    "williamboman/mason-lspconfig.nvim",
    config = function()
      require("mason-lspconfig").setup({
        ensure_installed = { "gopls", "ts_ls", "pyright", "yamlls", "dockerls", "bashls", "jsonls", "eslint" },
        automatic_installation = true,
      })
    end,
  },

  -- LSPSaga
  {
    "nvimdev/lspsaga.nvim",
    config = function()
      require("lspsaga").setup({
        ui = { border = "rounded" },
        lightbulb = { enable = false },
      })
    end,
  },

  -- LSP Signature
  {
    "ray-x/lsp_signature.nvim",
    config = function()
      require("lsp_signature").setup({
        bind = true,
        handler_opts = { border = "rounded" },
      })
    end,
  },

  -- Inc Rename
  {
    "smjonas/inc-rename.nvim",
    config = function()
      require("inc_rename").setup()
    end,
  },

  -- Lualine
  {
    "nvim-lualine/lualine.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      require("lualine").setup({
        options = {
          theme = "monokai-pro",
          component_separators = "|",
          section_separators = { left = "", right = "" },
        },
      })
    end,
  },

  -- Bufferline
  {
    "akinsho/bufferline.nvim",
    version = "*",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      require("bufferline").setup({
        options = {
          mode = "buffers",
          separator_style = "slant",
          show_buffer_close_icons = true,
          show_close_icon = true,
          color_icons = true,
        },
      })
    end,
  },
     
  -- Ansible syntax support
{
  "pearofducks/ansible-vim",
  ft = { "yaml", "ansible" },
},

-- Nginx config syntax
{
  "chr4/nginx.vim",
  ft = "nginx",
},

-- Dockerfile syntax
{
  "ekalinin/Dockerfile.vim",
  ft = "dockerfile",
},

-- GitHub Actions syntax
{
  "yasuhiroki/github-actions-yaml.vim",
  ft = "yaml",
},

-- Jenkinsfile syntax
{
  "martinda/Jenkinsfile-vim-syntax",
  ft = "Jenkinsfile",
},





  -- Monokai Classic: warm C++ vibe (pink/green/orange/yellow, not blue)
{
  "loctvl842/monokai-pro.nvim",
  lazy = false,
  priority = 1000,
  config = function()
    local bg = "#1e1e1e" -- VS Code / classic C++ IDE dark
    -- Bright Monokai lime — clearly distinct from code, still on-theme
    local comment = "#b8f26e"
    local folder = "#ffd866" -- yellow folders (not blue)
    local folder_open = "#a9dc76" -- green open folders

    local function apply_cpp_vibe()
      local set = vim.api.nvim_set_hl
      set(0, "Normal", { fg = "#fcfcfa", bg = bg })
      set(0, "NormalNC", { fg = "#fcfcfa", bg = bg })
      set(0, "NormalFloat", { fg = "#fcfcfa", bg = "#272822" })
      set(0, "SignColumn", { bg = bg })
      set(0, "EndOfBuffer", { fg = bg, bg = bg })
      set(0, "LineNr", { fg = "#727072", bg = bg })
      set(0, "CursorLine", { bg = "#2a2a2a" })
      set(0, "CursorLineNr", { fg = "#fc9867", bold = true })
      set(0, "Visual", { bg = "#3e3d32" })
      -- Comments: bright + slightly bold so they never wash out
      local comment_hl = { fg = comment, italic = false, bold = true }
      set(0, "Comment", comment_hl)
      set(0, "@comment", comment_hl)
      set(0, "@comment.documentation", comment_hl)
      set(0, "@comment.line", comment_hl)
      set(0, "@comment.block", comment_hl)
      set(0, "@lsp.type.comment", comment_hl)
      set(0, "SpecialComment", comment_hl)
      -- File tree: kill the blue, use yellow/green/orange
      set(0, "NvimTreeNormal", { fg = "#fcfcfa", bg = bg })
      set(0, "NvimTreeNormalNC", { fg = "#fcfcfa", bg = bg })
      set(0, "NvimTreeEndOfBuffer", { fg = bg, bg = bg })
      set(0, "NvimTreeFolderIcon", { fg = folder })
      set(0, "NvimTreeFolderName", { fg = folder })
      set(0, "NvimTreeOpenedFolderName", { fg = folder_open })
      set(0, "NvimTreeEmptyFolderName", { fg = "#727072" })
      set(0, "NvimTreeRootFolder", { fg = "#ff6188", bold = true })
      set(0, "NvimTreeIndentMarker", { fg = "#3e3d32" })
      set(0, "NvimTreeFileName", { fg = "#fcfcfa" })
      set(0, "NvimTreeExecFile", { fg = "#a9dc76" })
      set(0, "Directory", { fg = folder })
      -- Devicons-ish folder/file overrides that often stay blue
      set(0, "NvimTreeWinSeparator", { fg = bg, bg = bg })
    end

    require("monokai-pro").setup({
      filter = "classic",
      styles = {
        comment = { italic = false },
        keyword = { italic = false },
        type = { italic = false },
        storageclass = { italic = false },
        structure = { italic = false },
        parameter = { italic = false },
        annotation = { italic = false },
        tag_attribute = { italic = false },
      },
      override_palette = function()
        return {
          background = bg,
          dark2 = "#141414",
          dark1 = "#1a1a1a",
          text = "#fcfcfa",
          accent1 = "#ff6188", -- keywords / pink
          accent2 = "#fc9867", -- orange (types/params)
          accent3 = "#ffd866", -- yellow (strings)
          accent4 = "#a9dc76", -- green (functions)
          accent5 = "#78dce8", -- cyan ( sparingly )
          accent6 = "#ab9df2", -- purple
          dimmed1 = "#c1c0c0",
          dimmed2 = "#939293",
          dimmed3 = "#727072",
          dimmed4 = "#5b595c",
          dimmed5 = "#403e41",
        }
      end,
      override = function()
        return {
          Normal = { bg = bg },
          NormalNC = { bg = bg },
          Comment = { fg = comment, italic = false, bold = true },
          ["@comment"] = { fg = comment, italic = false, bold = true },
          ["@comment.line"] = { fg = comment, italic = false, bold = true },
          ["@comment.block"] = { fg = comment, italic = false, bold = true },
          ["@comment.documentation"] = { fg = comment, italic = false, bold = true },
          ["@lsp.type.comment"] = { fg = comment, italic = false, bold = true },
          SpecialComment = { fg = comment, italic = false, bold = true },
          NvimTreeFolderIcon = { fg = folder },
          NvimTreeFolderName = { fg = folder },
          NvimTreeOpenedFolderName = { fg = folder_open },
          Directory = { fg = folder },
        }
      end,
    })

    vim.api.nvim_create_autocmd("ColorScheme", {
      pattern = "monokai-pro*",
      callback = function()
        apply_cpp_vibe()
        -- monokai-pro applies nvim-tree highlights lazily; re-stamp after
        vim.schedule(apply_cpp_vibe)
      end,
      desc = "C++ Monokai vibe + non-blue folders",
    })

    vim.api.nvim_create_autocmd("FileType", {
      pattern = "NvimTree",
      callback = apply_cpp_vibe,
      desc = "Keep non-blue folder colors in nvim-tree",
    })

    vim.cmd.colorscheme("monokai-pro")
    apply_cpp_vibe()
    vim.schedule(apply_cpp_vibe)
  end,
},



  -- Noice (beautiful UI)
  {
    "folke/noice.nvim",
    dependencies = {
      "MunifTanjim/nui.nvim",
      "rcarriga/nvim-notify",
    },
    config = function()
      require("noice").setup({
        lsp = {
          override = {
            ["vim.lsp.util.convert_input_to_markdown_lines"] = true,
            ["vim.lsp.util.stylize_markdown"] = true,
            ["cmp.entry.get_documentation"] = true,
          },
        },
      })
    end,
  },

  -- Notify
  {
    "rcarriga/nvim-notify",
    config = function()
      require("notify").setup({
        background_colour = "#1e1e1e",
        timeout = 3000,
        render = "compact",
      })
      vim.notify = require("notify")
    end,
  },

  -- Which Key
  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    config = function()
      require("which-key").setup()
    end,
  },

  -- Trouble
  {
    "folke/trouble.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      require("trouble").setup({
        focus = true, -- jump into the panel when it opens
      })
    end,
  },

  -- Harpoon
  {
    "ThePrimeagen/harpoon",
    branch = "harpoon2",
    dependencies = { "nvim-lua/plenary.nvim" },
    config = function()
      require("harpoon"):setup()
    end,
  },

  -- Spectre
  {
    "nvim-pack/nvim-spectre",
    dependencies = { "nvim-lua/plenary.nvim" },
    config = function()
      require("spectre").setup()
    end,
  },

  -- Conform (format on save)
  {
    "stevearc/conform.nvim",
    lazy = false,
    config = function()
      require("conform").setup({
        formatters_by_ft = {
          c = { "clang-format" },
          cpp = { "clang-format" },
          go = { "gofmt", "goimports" },
          lua = { "stylua" },
          python = { "black" },
          javascript = { "prettier" },
          javascriptreact = { "prettier" },
          typescript = { "prettier" },
          typescriptreact = { "prettier" },
          json = { "prettier" },
          jsonc = { "prettier" },
          yaml = { "prettier" },
          markdown = { "prettier" },
          html = { "prettier" },
          css = { "prettier" },
          scss = { "prettier" },
          sh = { "shfmt" },
        },
        default_format_opts = {
          lsp_format = "fallback",
        },
        format_on_save = {
          timeout_ms = 2000,
          lsp_format = "fallback",
        },
        notify_on_error = true,
      })
    end,
  },

  -- Autopairs
  {
    "windwp/nvim-autopairs",
    event = "InsertEnter",
    config = function()
      require("nvim-autopairs").setup()
    end,
  },

  -- Comments
  {
    "numToStr/Comment.nvim",
    config = function()
      require("Comment").setup()
    end,
  },

-- Indent lines
{
  "lukas-reineke/indent-blankline.nvim",
  main = "ibl",
  config = function()
    require("ibl").setup({
      exclude = {
        filetypes = {
          "dashboard",
          "alpha",
          "help",
          "lazy",
          "mason",
          "notify",
          "toggleterm",
          "trouble",
        },
      },
    })
  end,
},  

  -- Smooth scrolling
  {
    "karb94/neoscroll.nvim",
    config = function()
      require("neoscroll").setup()
    end,
  },
-- In-editor Markdown rendering
{
  "MeanderingProgrammer/render-markdown.nvim",
  ft = { "markdown", "quarto" },
  dependencies = {
    "nvim-treesitter/nvim-treesitter",
    "nvim-tree/nvim-web-devicons",
  },
  opts = {
    enabled = true,
    render_modes = { "n", "c" },
    file_types = { "markdown", "quarto" },
    anti_conceal = { enabled = true },
    heading = {
      enabled = true,
      sign = false,
      icons = { "󰲡 ", "󰲣 ", "󰲥 ", "󰲧 ", "󰲩 ", "󰲫 " },
    },
    code = {
      enabled = true,
      sign = false,
      style = "normal",
      border = "none",
    },
    bullet = { enabled = true },
    checkbox = { enabled = true },
    pipe_table = { enabled = true, style = "normal" },
  },
},

-- Markdown Preview in browser (Peek) — manual only, avoids fighting render-markdown
{
  "toppair/peek.nvim",
  cmd = { "PeekOpen", "PeekClose" },
  build = "deno task --quiet build:fast",
  config = function()
    require("peek").setup({
      auto_load = false,
      close_on_bdelete = true,
      syntax = true,
      theme = "dark",
      update_on_change = true,
      app = "browser",
      filetype = { "markdown" },
    })
    vim.api.nvim_create_user_command("PeekOpen", require("peek").open, {})
    vim.api.nvim_create_user_command("PeekClose", require("peek").close, {})
  end,
},
  -- YAML companion
  {
    "someone-stole-my-name/yaml-companion.nvim",
    dependencies = {
      "neovim/nvim-lspconfig",
      "nvim-lua/plenary.nvim",
      "nvim-telescope/telescope.nvim",
    },
    config = function()
      require("telescope").load_extension("yaml_schema")
    end,
  },

  -- REST client (no luarocks needed)
{
  "mistweaverco/kulala.nvim",
  ft = "http",
  config = function()
    require("kulala").setup()
  end,
},

  -- Devcontainer
  {
    "esensar/nvim-dev-container",
    config = function()
      require("devcontainer").setup({})
    end,
  },

  -- Terraform
  {
    "hashivim/vim-terraform",
    ft = { "terraform", "tf" },
    config = function()
      vim.g.terraform_fmt_on_save = 1
      vim.g.terraform_align = 1
    end,
  },

  -- Helm
  {
    "towolf/vim-helm",
    ft = { "helm", "yaml" },
  },

  -- Database
  {
    "tpope/vim-dadbod",
    dependencies = {
      "kristijanhusak/vim-dadbod-ui",
      "kristijanhusak/vim-dadbod-completion",
    },
    config = function()
      vim.g.db_ui_use_nerd_fonts = 1
    end,
  },

  -- Neotest
  {
    "nvim-neotest/neotest",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-neotest/nvim-nio", 
      "nvim-neotest/neotest-go",
    },
    config = function()
      require("neotest").setup({
        adapters = {
          require("neotest-go"),
        },
      })
    end,
  },

  -- CMP
  { "hrsh7th/nvim-cmp" },
  { "hrsh7th/cmp-nvim-lsp" },
  { "hrsh7th/cmp-buffer" },
  { "hrsh7th/cmp-path" },

  -- Snippets
  { "L3MON4D3/LuaSnip" },
  { "saadparwaiz1/cmp_luasnip" },

  -- Hop
  {
    "smoka7/hop.nvim",
    version = "*",
    config = function()
      require("hop").setup()
    end,
  },

  -- Copilot
  { "github/copilot.vim", lazy = false },

  -- Copilot Chat
  {
    "CopilotC-Nvim/CopilotChat.nvim",
    branch = "main",
    dependencies = {
      { "github/copilot.vim" },
      { "nvim-lua/plenary.nvim" },
    },
    build = "make tiktoken",
    config = function()
      require("CopilotChat").setup({
        window = {
          layout = "vertical",
          width = 0.35,
        },
      })
    end,
  },

  -- Gitsigns
  {
    "lewis6991/gitsigns.nvim",
    config = function()
      require("gitsigns").setup({
        current_line_blame = true,
      })
    end,
  },

  -- ToggleTerm
  {
    "akinsho/toggleterm.nvim",
    version = "*",
    config = function()
      require("toggleterm").setup({
        direction = "horizontal",
        open_mapping = [[<C-\>]],
        shell = vim.o.shell, -- zsh → agnoster from ~/.zshrc
        start_in_insert = true,
        persist_mode = false, -- always land in insert / focused when opened
        shade_terminals = true,
        insert_mappings = true,
        terminal_mappings = true,
      })
    end,
  },

  -- Overseer
  {
    "stevearc/overseer.nvim",
    config = function()
      require("overseer").setup()
    end,
  },

--Dashboard
{
  "nvimdev/dashboard-nvim",
  event = "VimEnter",
  dependencies = { "nvim-tree/nvim-web-devicons" },
  config = function()
    local function footer()
      local total_plugins = require("lazy").stats().count
      local loaded_plugins = require("lazy").stats().loaded
      local datetime = os.date(" %Y-%m-%d   %H:%M")
      local version = vim.version()
      local nvim_version = "v" .. version.major .. "." .. version.minor .. "." .. version.patch
      return {
        "",
        " Go • Kubernetes • DevOps • Cloud Native",
        datetime,
        "󰒲 " .. loaded_plugins .. "/" .. total_plugins .. " plugins   Neovim " .. nvim_version,
      }
    end

    require("dashboard").setup({
      theme = "doom",
      config = {
        header = {
          "",
          "",
          "  ██████╗  ██████╗     ██████╗ ███████╗██╗   ██╗██╗  ██╗ ",
          "  ██╔════╝ ██╔═══██╗   ██╔══██╗██╔════╝██║   ██║╚██╗██╔╝ ",
          "  ██║  ███╗██║   ██║   ██║  ██║█████╗  ██║   ██║ ╚███╔╝  ",
          "  ██║   ██║██║   ██║   ██║  ██║██╔══╝  ╚██╗ ██╔╝ ██╔██╗  ",
          "  ╚██████╔╝╚██████╔╝   ██████╔╝███████╗ ╚████╔╝ ██╔╝ ██╗ ",
          "   ╚═════╝  ╚═════╝    ╚═════╝ ╚══════╝  ╚═══╝  ╚═╝  ╚═╝ ",
          "",
          "          Backend  •  DevOps  •  Cloud Native          ",
          "             Go  |  Docker  |  Kubernetes              ",
          "  ──────────────────────────────────────────────────── ",
          "",
        },
        center = {
          {
            icon = "  ",
            icon_hl = "DiagnosticOk",
            desc = "Find File                ",
            desc_hl = "String",
            key = "f",
            key_hl = "Number",
            action = "Telescope find_files",
          },
          {
            icon = "  ",
            icon_hl = "DiagnosticOk",
            desc = "Recent Files             ",
            desc_hl = "String",
            key = "r",
            key_hl = "Number",
            action = "Telescope oldfiles",
          }, 
          {
            icon = "  ",
            icon_hl = "DiagnosticOk",
            desc = "Find Word                ",
            desc_hl = "String",
            key = "s",
            key_hl = "Number",
            action = "Telescope live_grep",
          },
          {
            icon = "  ",
            icon_hl = "DiagnosticWarn",
            desc = "── Project ─────────────",
            desc_hl = "Comment",
            key = "1",
            action = "",
          },
          {
            icon = "  ",
            icon_hl = "DiagnosticOk",
            desc = "File Explorer            ",
            desc_hl = "String",
            key = "e",
            key_hl = "Number",
            action = "NvimTreeToggle",
          },

          {
            icon = "  ",
            icon_hl = "DiagnosticOk",
            desc = "Git Status               ",
            desc_hl = "String",
            key = "g",
            key_hl = "Number",
            action = "LazyGit",
          },
          {
            icon = "  ",
            icon_hl = "DiagnosticWarn",
            desc = "── System ──────────────",
            desc_hl = "Comment",
            key = "2",
            action = "",
          },
          {
            icon = "  ",
            icon_hl = "DiagnosticOk",
            desc = "Edit Config              ",
            desc_hl = "String",
            key = "c",
            key_hl = "Number",
            action = "edit ~/.config/nvim/init.lua",
          },
          {
            icon = "󰒲  ",
            icon_hl = "DiagnosticOk",
            desc = "Lazy Plugin Manager      ",
            desc_hl = "String",
            key = "l",
            key_hl = "Number",
            action = "Lazy",
          },
          {
            icon = "󰩈  ",
            icon_hl = "DiagnosticError",
            desc = "Quit                     ",
            desc_hl = "String",
            key = "q",
            key_hl = "DiagnosticError",
            action = "qa",
          },
        },
        footer = footer,
      },
    })
  end,
}, 

})
  

-- =========================
-- LSP SETUP
-- =========================
local capabilities = require("cmp_nvim_lsp").default_capabilities()

-- Go
vim.lsp.config("gopls", { capabilities = capabilities })
vim.lsp.enable("gopls")

-- TypeScript
vim.lsp.config("ts_ls", { capabilities = capabilities })
vim.lsp.enable("ts_ls")

-- Python
vim.lsp.config("pyright", { capabilities = capabilities })
vim.lsp.enable("pyright")

-- YAML (K8s, Docker compose, GitHub Actions)
vim.lsp.config("yamlls", { capabilities = capabilities })
vim.lsp.enable("yamlls")


-- Docker Language Server  
 vim.lsp.config("dockerls", {
  capabilities = capabilities,
  cmd = { "docker-language-server", "start", "--stdio" },
 })
 vim.lsp.enable("dockerls")

-- Bash
vim.lsp.config("bashls", { capabilities = capabilities })
vim.lsp.enable("bashls")

-- JSON
vim.lsp.config("jsonls", { capabilities = capabilities })
vim.lsp.enable("jsonls")

-- ESLint
vim.lsp.config("eslint", { capabilities = capabilities })
vim.lsp.enable("eslint")

-- =========================
-- CMP SETUP
-- =========================
local cmp = require("cmp")

cmp.setup({
  completion = {
    autocomplete = false,  -- OFF by default
  },

  snippet = {
    expand = function(args)
      require("luasnip").lsp_expand(args.body)
    end,
  },
  mapping = cmp.mapping.preset.insert({
    ["<C-Space>"] = cmp.mapping.complete(),
    ["<CR>"]      = cmp.mapping.confirm({ select = true }),
    ["<Tab>"]     = cmp.mapping.select_next_item(),
    ["<S-Tab>"]   = cmp.mapping.select_prev_item(),
  }),
  sources = {
    { name = "nvim_lsp" },
    { name = "buffer" },
    { name = "path" },
    { name = "luasnip" },
  },
})
