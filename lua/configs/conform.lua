local paths = require "configs.paths"

local options = {
  formatters_by_ft = {
    lua = { "stylua" },
    go = { "goimports", "gofmt" },
    rust = { "rustfmt" },
    python = { "ruff_format" },
    css = { "prettier" },
    scss = { "prettier" },
    less = { "prettier" },
    html = { "prettier" },
    markdown = { "prettier" },
  },

  format_on_save = {
    timeout_ms = 1000,
    lsp_fallback = true,
  },

  formatters = {
    goimports = {
      command = paths.first(paths.mason_path("goimports", "goimports"), paths.executable "goimports"),
    },
    stylua = {
      command = paths.first(paths.mason_path("stylua", "stylua"), paths.executable "stylua"),
    },
    prettier = {
      command = paths.first(paths.mason_bin "prettier", paths.executable "prettier"),
    },
  },
}

return options
