local M = {}

function M.setup()
  local paths = require "configs.paths"
  local rust_analyzer_cmd = paths.first(
    paths.mason_path("rust-analyzer", "rust-analyzer*"),
    paths.executable "rust-analyzer"
  )

  vim.g.rustaceanvim = {
    server = {
      cmd = rust_analyzer_cmd and { rust_analyzer_cmd } or nil,
      default_settings = {
        ["rust-analyzer"] = {
          cargo = {
            allFeatures = true,
          },
          checkOnSave = true,
          check = {
            command = "clippy",
          },
          procMacro = {
            enable = true,
          },
          inlayHints = {
            bindingModeHints = {
              enable = true,
            },
            closingBraceHints = {
              enable = true,
              minLines = 1,
            },
            closureReturnTypeHints = {
              enable = "with_block",
            },
            discriminantHints = {
              enable = "always",
            },
            lifetimeElisionHints = {
              enable = "skip_trivial",
              useParameterNames = true,
            },
            typeHints = {
              enable = true,
              hideClosureInitialization = false,
              hideNamedConstructor = false,
            },
          },
        },
      },
    },
  }
end

return M
