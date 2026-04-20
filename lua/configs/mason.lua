local paths = require "configs.paths"
local M = {}

M.ui = {
  border = "rounded",
}

M.registries = {
  "github:mason-org/mason-registry",
  "github:Crashdummyy/mason-registry",
}

M.ensure_installed = {
  "lua-language-server",
  "stylua",
  "gopls",
  "goimports",
  "golangci-lint",
  "html-lsp",
  "delve",
  "rzls",
  "csharpier",
  "netcoredbg",
  "rust-analyzer",
  "codelldb",
}

if paths.python_venv_support() then
  vim.list_extend(M.ensure_installed, {
    "basedpyright",
    "ruff",
    "debugpy",
  })
end

return M
