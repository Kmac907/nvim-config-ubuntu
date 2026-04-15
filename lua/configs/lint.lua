local lint = require "lint"
local paths = require "configs.paths"

local golangci_lint = paths.first(
  paths.mason_path("golangci-lint", "**/golangci-lint"),
  paths.executable "golangci-lint"
)

local ruff = paths.executable "ruff"

lint.linters_by_ft = {
  go = golangci_lint and { "golangcilint" } or {},
  python = ruff and { "ruff" } or {},
}

if golangci_lint then
  lint.linters.golangcilint.cmd = golangci_lint
end

if ruff then
  lint.linters.ruff.cmd = ruff
end

local lint_augroup = vim.api.nvim_create_augroup("UserLinting", { clear = true })

vim.api.nvim_create_autocmd({ "BufWritePost", "InsertLeave" }, {
  group = lint_augroup,
  callback = function()
    lint.try_lint()
  end,
})
