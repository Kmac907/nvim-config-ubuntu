local mason_lspconfig = require "mason-lspconfig"
local mason_tool_installer = require "mason-tool-installer"
local nvchad_lsp = require "nvchad.configs.lspconfig"
local util = require "lspconfig.util"
local mason_opts = require "configs.mason"
local paths = require "configs.paths"

require("mason").setup(mason_opts)

mason_lspconfig.setup {
  ensure_installed = paths.python_venv_support()
      and {
        "lua_ls",
        "gopls",
        "basedpyright",
      }
    or {
      "lua_ls",
      "gopls",
    },
  automatic_enable = false,
  automatic_installation = true,
}

mason_tool_installer.setup {
  ensure_installed = mason_opts.ensure_installed,
  auto_update = false,
  run_on_start = true,
  start_delay = 3000,
}

local capabilities = vim.deepcopy(nvchad_lsp.capabilities)
local ok_cmp, cmp_nvim_lsp = pcall(require, "cmp_nvim_lsp")
if ok_cmp then
  capabilities = cmp_nvim_lsp.default_capabilities(capabilities)
end

dofile(vim.g.base46_cache .. "lsp")
require("nvchad.lsp").diagnostic_config()

local on_attach = function(client, bufnr)
  nvchad_lsp.on_attach(client, bufnr)
  vim.bo[bufnr].omnifunc = "v:lua.vim.lsp.omnifunc"
end

local on_init = function(client, _)
  nvchad_lsp.on_init(client, _)
end

local lua_ls_cmd = paths.first(
  paths.mason_path("lua-language-server", "lua-language-server"),
  paths.executable "lua-language-server"
)

local gopls_cmd = paths.first(
  paths.mason_path("gopls", "gopls"),
  paths.executable "gopls"
)

local basedpyright_cmd = paths.first(
  paths.mason_path("basedpyright", "venv/bin/basedpyright-langserver"),
  paths.executable "basedpyright-langserver"
)

vim.api.nvim_create_autocmd("LspAttach", {
  group = vim.api.nvim_create_augroup("UserLspConfig", { clear = true }),
  callback = function(args)
    local client_id = args.data and args.data.client_id
    if not client_id then
      return
    end

    local client = vim.lsp.get_client_by_id(client_id)
    if client and client.server_capabilities.inlayHintProvider and vim.lsp.inlay_hint then
      vim.lsp.inlay_hint.enable(true, { bufnr = args.buf })
    end
  end,
})

local server_configs = {
  lua_ls = {
    cmd = lua_ls_cmd and { lua_ls_cmd } or nil,
    settings = {
      Lua = {
        completion = {
          callSnippet = "Replace",
        },
        diagnostics = {
          globals = { "vim" },
        },
        hint = {
          enable = true,
        },
      },
    },
  },
  gopls = {
    cmd = gopls_cmd and { gopls_cmd } or nil,
    root_dir = util.root_pattern("go.work", "go.mod", ".git"),
    settings = {
      gopls = {
        analyses = {
          nilness = true,
          unusedparams = true,
          unusedwrite = true,
          useany = true,
        },
        completeUnimported = true,
        gofumpt = true,
        hints = {
          assignVariableTypes = true,
          compositeLiteralFields = true,
          compositeLiteralTypes = true,
          constantValues = true,
          functionTypeParameters = true,
          parameterNames = true,
          rangeVariableTypes = true,
        },
        staticcheck = true,
      },
    },
  },
}

if basedpyright_cmd then
  server_configs.basedpyright = {
    cmd = { basedpyright_cmd, "--stdio" },
    root_dir = util.root_pattern("pyproject.toml", "setup.py", "setup.cfg", "requirements.txt", ".git"),
    settings = {
      basedpyright = {
        analysis = {
          autoImportCompletions = true,
          autoSearchPaths = true,
          diagnosticMode = "workspace",
          typeCheckingMode = "basic",
          useLibraryCodeForTypes = true,
        },
      },
    },
  }
end

local base_config = {
  capabilities = capabilities,
  on_attach = on_attach,
  on_init = on_init,
}

vim.lsp.config("*", base_config)
for server, config in pairs(server_configs) do
  vim.lsp.config(server, config)
  vim.lsp.enable(server)
end

-- read :h vim.lsp.config for changing options of lsp servers 
