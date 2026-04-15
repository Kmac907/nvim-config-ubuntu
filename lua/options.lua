require "nvchad.options"

-- add yours here!

-- local o = vim.o
-- o.cursorlineopt ='both' -- to enable cursorline!

local codelens = vim.lsp and vim.lsp.codelens

if codelens and type(codelens.enable) ~= "function" then
  -- `go.nvim` expects the newer `vim.lsp.codelens.enable()` API.
  -- Neovim 0.11 still exposes `refresh()`/`clear()` only.
  codelens.enable = function(enable, opts)
    local bufnr = opts and opts.bufnr or nil

    if enable == false then
      return codelens.clear(nil, bufnr)
    end

    return codelens.refresh { bufnr = bufnr }
  end
end
