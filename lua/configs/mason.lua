local paths = require "configs.paths"
local M = {}

M.ui = {
  border = "rounded",
}

M.ensure_installed = {
  "lua-language-server",
  "stylua",
  "gopls",
  "goimports",
  "golangci-lint",
  "delve",
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
