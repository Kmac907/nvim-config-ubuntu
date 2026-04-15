local M = {}
local python_venv_ready

local function stat(path)
  return path and vim.uv.fs_stat(path)
end

function M.mason_bin(name)
  local path = vim.fn.stdpath "data" .. "/mason/bin/" .. name
  if stat(path) then
    return path
  end
end

function M.executable(name)
  if vim.fn.executable(name) == 1 then
    return vim.fn.exepath(name)
  end

  local mason_bin = M.mason_bin(name)
  if mason_bin then
    return mason_bin
  end

  local local_npm = vim.fn.expand("~/.local/npm/bin/" .. name)
  if stat(local_npm) then
    return local_npm
  end

  local local_npm_modules = vim.fn.expand("~/.local/npm/node_modules/.bin/" .. name)
  if stat(local_npm_modules) then
    return local_npm_modules
  end
end

function M.mason_path(package, pattern)
  local root = vim.fn.stdpath "data" .. "/mason/packages/" .. package .. "/"
  local matches = vim.fn.glob(root .. pattern, true, true)

  for _, match in ipairs(matches) do
    if stat(match) then
      return match
    end
  end
end

function M.first(...)
  for _, value in ipairs { ... } do
    if value then
      return value
    end
  end
end

function M.python_venv_support()
  if python_venv_ready ~= nil then
    return python_venv_ready
  end

  if vim.fn.executable "python3" ~= 1 then
    python_venv_ready = false
    return python_venv_ready
  end

  vim.fn.system { "python3", "-c", "import ensurepip, venv" }
  python_venv_ready = vim.v.shell_error == 0

  return python_venv_ready
end

return M
