return {
  {
    "nvim-telescope/telescope.nvim",
    branch = "0.1.x",
  },
  {
    "lukas-reineke/indent-blankline.nvim",
    event = "User FilePost",
    opts = {
      indent = { char = "│", highlight = "IblChar" },
      scope = {
        enabled = true,
        char = "│",
        highlight = "IblScopeChar",
        show_start = true,
        show_end = true,
        exclude = {
          -- `ibl` scope follows Treesitter lexical scope, not visual indent blocks.
          -- That makes the highlighted guide misleading in Python and noisy in Lua.
          language = { "python", "lua" },
        },
      },
      exclude = {
        filetypes = {
          "help",
          "lazy",
          "mason",
          "NvimTree",
          "Trouble",
          "alpha",
          "dashboard",
          "notify",
          "toggleterm",
        },
        buftypes = { "terminal", "nofile" },
      },
    },
    config = function(_, opts)
      local function apply_ibl_colors()
        vim.api.nvim_set_hl(0, "IblChar", { fg = "#d79921" })
        vim.api.nvim_set_hl(0, "IblScopeChar", { fg = "#fe8019" })

        for i = 1, 7 do
          vim.api.nvim_set_hl(0, "@ibl.scope.underline." .. i, {
            sp = "#fe8019",
            underline = true,
          })
        end
      end

      dofile(vim.g.base46_cache .. "blankline")

      apply_ibl_colors()

      local hooks = require "ibl.hooks"
      hooks.register(hooks.type.WHITESPACE, hooks.builtin.hide_first_space_indent_level)
      require("ibl").setup(opts)

      vim.api.nvim_create_autocmd("ColorScheme", {
        group = vim.api.nvim_create_augroup("UserIblColors", { clear = true }),
        callback = apply_ibl_colors,
      })

      dofile(vim.g.base46_cache .. "blankline")
      apply_ibl_colors()
    end,
  },
  {
    "stevearc/conform.nvim",
    opts = require "configs.conform",
  },
  {
    "neovim/nvim-lspconfig",
    event = "User FilePost",
    config = function()
      require "configs.lspconfig"
    end,
  },
  {
    "seblyng/roslyn.nvim",
    ft = { "cs", "razor", "cshtml" },
    dependencies = {
      "neovim/nvim-lspconfig",
      "williamboman/mason.nvim",
      "tris203/rzls.nvim",
    },
    init = function()
      vim.filetype.add {
        extension = {
          razor = "razor",
          cshtml = "razor",
        },
      }
    end,
    config = function()
      require("configs.dotnet").setup_roslyn()
    end,
  },
  {
    "GustavEikaas/easy-dotnet.nvim",
    cmd = { "Dotnet" },
    ft = { "cs", "csproj", "fsproj", "sln", "slnx", "razor", "cshtml", "props" },
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-telescope/telescope.nvim",
      "mfussenegger/nvim-dap",
    },
    config = function()
      require("configs.dotnet").setup_easy_dotnet()
    end,
  },
  {
    "williamboman/mason.nvim",
    cmd = { "Mason", "MasonInstall", "MasonUpdate" },
    opts = require "configs.mason",
  },
  {
    "williamboman/mason-lspconfig.nvim",
    lazy = false,
    dependencies = { "williamboman/mason.nvim" },
    config = function() end,
  },
  {
    "WhoIsSethDaniel/mason-tool-installer.nvim",
    lazy = false,
    dependencies = { "williamboman/mason.nvim" },
    config = function() end,
  },
  {
    "nvim-treesitter/nvim-treesitter",
    branch = "master",
    build = ":TSUpdate",
    opts = require "configs.treesitter",
  },
  {
    "nvim-treesitter/nvim-treesitter-textobjects",
    event = "VeryLazy",
    dependencies = { "nvim-treesitter/nvim-treesitter" },
  },
  {
    "mfussenegger/nvim-lint",
    event = { "BufReadPre", "BufNewFile" },
    config = function()
      require "configs.lint"
    end,
  },
  {
    "folke/trouble.nvim",
    cmd = "Trouble",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    opts = {},
  },
  {
    "folke/todo-comments.nvim",
    event = "BufReadPost",
    dependencies = { "nvim-lua/plenary.nvim" },
    opts = {},
  },
  {
    "folke/lazydev.nvim",
    ft = "lua",
    opts = {
      library = {
        { path = "${3rd}/luv/library", words = { "vim%.uv" } },
      },
    },
  },
  {
    "hrsh7th/nvim-cmp",
    dependencies = { "GustavEikaas/easy-dotnet.nvim" },
    opts = function(_, opts)
      return require("configs.dotnet").extend_cmp(opts)
    end,
  },
  {
    "ray-x/guihua.lua",
    lazy = true,
  },
  {
    "ray-x/go.nvim",
    ft = { "go", "gomod", "gowork", "gotmpl" },
    dependencies = {
      "ray-x/guihua.lua",
      "neovim/nvim-lspconfig",
      "nvim-treesitter/nvim-treesitter",
    },
    opts = require "configs.go",
    config = function(_, opts)
      require("go").setup(opts)
    end,
  },
  {
    "mrcjkb/rustaceanvim",
    version = "^5",
    ft = { "rust" },
    init = function()
      require("configs.rust").setup()
    end,
  },
  {
    "saecki/crates.nvim",
    event = { "BufRead Cargo.toml" },
    dependencies = { "nvim-lua/plenary.nvim" },
    opts = {},
  },
  {
    "linux-cultist/venv-selector.nvim",
    branch = "v1",
    cmd = { "VenvSelect", "VenvSelectCached" },
    enabled = function()
      return vim.fn.executable "fd" == 1 or vim.fn.executable "fdfind" == 1
    end,
    dependencies = {
      "neovim/nvim-lspconfig",
      "nvim-telescope/telescope.nvim",
      "mfussenegger/nvim-dap-python",
    },
    opts = require "configs.python",
  },
  {
    "mfussenegger/nvim-dap",
    lazy = false,
    dependencies = {
      "rcarriga/nvim-dap-ui",
      "jay-babu/mason-nvim-dap.nvim",
      "theHamsta/nvim-dap-virtual-text",
      "leoluz/nvim-dap-go",
      "mfussenegger/nvim-dap-python",
    },
    config = function()
      require "configs.dap"
    end,
  },
  {
    "rcarriga/nvim-dap-ui",
    dependencies = { "nvim-neotest/nvim-nio" },
    opts = {},
  },
  {
    "jay-babu/mason-nvim-dap.nvim",
    dependencies = { "williamboman/mason.nvim" },
    config = function() end,
  },
  {
    "theHamsta/nvim-dap-virtual-text",
    opts = {},
  },
  {
    "leoluz/nvim-dap-go",
    ft = "go",
    dependencies = { "mfussenegger/nvim-dap" },
    config = function() end,
  },
  {
    "mfussenegger/nvim-dap-python",
    ft = "python",
    dependencies = { "mfussenegger/nvim-dap" },
    config = function() end,
  },
  {
    "nvim-neotest/neotest",
    cmd = { "Neotest", "NeotestRun", "NeotestSummary" },
    dependencies = {
      "nvim-neotest/nvim-nio",
      "nvim-lua/plenary.nvim",
      "antoinemadec/FixCursorHold.nvim",
      "fredrikaverpil/neotest-golang",
      "nvim-neotest/neotest-python",
      "rouge8/neotest-rust",
    },
    config = function()
      require "configs.test"
    end,
  },
}
