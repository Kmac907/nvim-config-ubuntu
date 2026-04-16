local dap = require "dap"
local dapui = require "dapui"
local paths = require "configs.paths"

require("mason-nvim-dap").setup {
  automatic_installation = true,
  ensure_installed = paths.python_venv_support() and {
    "delve",
    "coreclr",
    "python",
    "codelldb",
  } or {
    "delve",
    "coreclr",
    "codelldb",
  },
}

dapui.setup()
require("nvim-dap-virtual-text").setup()

dap.listeners.after.event_initialized["dapui_config"] = function()
  dapui.open()
end

dap.listeners.before.event_terminated["dapui_config"] = function()
  dapui.close()
end

dap.listeners.before.event_exited["dapui_config"] = function()
  dapui.close()
end

vim.fn.sign_define("DapBreakpoint", { text = "●", texthl = "DiagnosticError", linehl = "", numhl = "" })
vim.fn.sign_define("DapStopped", { text = "▶", texthl = "DiagnosticWarn", linehl = "", numhl = "" })

local dlv_path = paths.first(paths.mason_path("delve", "dlv"), paths.executable "dlv")

require("dap-go").setup {
  delve = {
    path = dlv_path,
  },
}

local debugpy_python = paths.mason_path("debugpy", "venv/bin/python")

if debugpy_python and vim.uv.fs_stat(debugpy_python) then
  require("dap-python").setup(debugpy_python)
end

local codelldb_path =
  paths.first(paths.mason_path("codelldb", "extension/adapter/codelldb"), paths.executable "codelldb")

if codelldb_path and vim.uv.fs_stat(codelldb_path) then
  dap.adapters.codelldb = {
    type = "server",
    port = "${port}",
    executable = {
      command = codelldb_path,
      args = { "--port", "${port}" },
    },
  }

  dap.configurations.rust = {
    {
      name = "Launch file",
      type = "codelldb",
      request = "launch",
      program = function()
        return vim.fn.input("Path to executable: ", vim.fn.getcwd() .. "/target/debug/", "file")
      end,
      cwd = "${workspaceFolder}",
      stopOnEntry = false,
    },
  }
end

local netcoredbg_path = paths.first(paths.mason_path("netcoredbg", "netcoredbg"), paths.executable "netcoredbg")

if netcoredbg_path and vim.uv.fs_stat(netcoredbg_path) then
  local function get_dotnet_dll()
    return coroutine.create(function(dap_run_co)
      local items = vim.fn.globpath(vim.fn.getcwd(), "**/bin/Debug/**/*.dll", false, true)

      vim.ui.select(items, {
        prompt = "Select DLL",
        format_item = function(path)
          return vim.fn.fnamemodify(path, ":.")
        end,
      }, function(choice)
        coroutine.resume(dap_run_co, choice)
      end)
    end)
  end

  dap.adapters.coreclr = {
    type = "executable",
    command = netcoredbg_path,
    args = { "--interpreter=vscode" },
  }

  dap.configurations.cs = {
    {
      type = "coreclr",
      name = ".NET Launch",
      request = "launch",
      cwd = "${workspaceFolder}",
      program = get_dotnet_dll,
    },
  }
end
