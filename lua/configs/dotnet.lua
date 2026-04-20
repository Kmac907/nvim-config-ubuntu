local M = {}

local paths = require "configs.paths"

local dotnet_filetypes = {
  cs = true,
  cshtml = true,
  razor = true,
  csproj = true,
  fsproj = true,
  sln = true,
  slnx = true,
  props = true,
}

local function ensure_dotnet_tools_on_path()
  local candidates = {
    vim.fn.expand "~/.dotnet/tools",
    vim.fn.expand "~/.dotnet/.dotnet/tools",
  }

  for _, directory in ipairs(candidates) do
    local shim = vim.fs.joinpath(directory, "dotnet-easydotnet")
    if vim.uv.fs_stat(shim) then
      vim.env.PATH = directory .. ":" .. vim.env.PATH
      return
    end
  end
end

local function csharpier_path()
  return paths.first(paths.mason_bin "csharpier", paths.executable "csharpier")
end

local function roslyn_cmd()
  local roslyn = paths.first(paths.mason_bin "roslyn", paths.executable "roslyn")
  if not roslyn then
    return nil
  end

  local rzls_root = paths.mason_path("rzls", "libexec")
  if not rzls_root then
    return { roslyn, "--stdio" }
  end

  return {
    roslyn,
    "--stdio",
    "--logLevel=Information",
    "--extensionLogDirectory=" .. vim.fs.dirname(vim.lsp.get_log_path()),
    "--razorSourceGenerator=" .. vim.fs.joinpath(rzls_root, "Microsoft.CodeAnalysis.Razor.Compiler.dll"),
    "--razorDesignTimePath=" .. vim.fs.joinpath(rzls_root, "Targets", "Microsoft.NET.Sdk.Razor.DesignTime.targets"),
    "--extension",
    vim.fs.joinpath(rzls_root, "RazorExtension", "Microsoft.VisualStudioCode.RazorExtension.dll"),
  }
end

local function rzls_path()
  return paths.first(paths.mason_bin "rzls", paths.executable "rzls")
end

local function lsp_capabilities()
  local nvchad_lsp = require "nvchad.configs.lspconfig"
  local capabilities = vim.deepcopy(nvchad_lsp.capabilities)
  local ok_cmp, cmp_nvim_lsp = pcall(require, "cmp_nvim_lsp")

  if ok_cmp then
    capabilities = cmp_nvim_lsp.default_capabilities(capabilities)
  end

  return capabilities
end

local function on_attach(client, bufnr)
  local nvchad_lsp = require "nvchad.configs.lspconfig"
  nvchad_lsp.on_attach(client, bufnr)
  vim.bo[bufnr].omnifunc = "v:lua.vim.lsp.omnifunc"
end

local function solution_candidates(directory)
  local matches = {}

  for _, pattern in ipairs { "*.sln", "*.slnx" } do
    for _, path in ipairs(vim.fn.globpath(directory, pattern, false, true)) do
      table.insert(matches, vim.fs.normalize(path))
    end
  end

  table.sort(matches)

  return matches
end

local function parent_directory(path)
  local parent = vim.fs.dirname(path)
  if parent == path then
    return nil
  end

  return parent
end

local function nearest_solution(path, selected_solution)
  if path == "" then
    return nil
  end

  if path:match("%.slnx?$") then
    return vim.fs.normalize(path)
  end

  local directory = vim.fs.dirname(vim.fs.normalize(path))

  while directory do
    local candidates = solution_candidates(directory)

    if #candidates == 1 then
      return candidates[1]
    end

    if #candidates > 1 then
      local normalized_selected = selected_solution and vim.fs.normalize(selected_solution) or nil
      if normalized_selected and vim.tbl_contains(candidates, normalized_selected) then
        return normalized_selected
      end

      return nil
    end

    directory = parent_directory(directory)
  end

  return nil
end

function M.sync_easy_dotnet_solution(bufnr)
  local ok, current_solution = pcall(require, "easy-dotnet.current_solution")
  if not ok then
    return false
  end

  bufnr = bufnr or vim.api.nvim_get_current_buf()

  if not dotnet_filetypes[vim.bo[bufnr].filetype] then
    return false
  end

  local path = vim.api.nvim_buf_get_name(bufnr)
  if path == "" then
    return false
  end

  local selected_solution = current_solution.try_get_selected_solution()
  local solution = nearest_solution(path, selected_solution)
  if not solution or solution == selected_solution then
    return false
  end

  local ok_set = pcall(current_solution.set_solution, solution)
  return ok_set
end

local function active_dotnet_root(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local path = vim.api.nvim_buf_get_name(bufnr)
  if path == "" then
    return nil
  end

  local selected_solution = nil
  local ok, current_solution = pcall(require, "easy-dotnet.current_solution")
  if ok then
    selected_solution = current_solution.try_get_selected_solution()
  end

  local solution = nearest_solution(path, selected_solution)
  if solution then
    return vim.fs.dirname(solution)
  end

  return vim.fs.dirname(vim.fs.normalize(path))
end

local function setup_rzls()
  local ok_rzls, rzls = pcall(require, "rzls")
  if not ok_rzls then
    return
  end

  vim.api.nvim_create_autocmd({ "BufReadPre", "BufNewFile" }, {
    group = vim.api.nvim_create_augroup("UserRazorVirtualBuffers", { clear = true }),
    pattern = { "*__virtual.cs", "*__virtual.html" },
    callback = function(args)
      vim.bo[args.buf].swapfile = false
      vim.bo[args.buf].undofile = false
      vim.bo[args.buf].bufhidden = "wipe"
    end,
  })

  local cwd = vim.fn.getcwd()
  local root = active_dotnet_root()
  if root and root ~= "" then
    vim.fn.chdir(root)
  end

  rzls.setup {
    capabilities = lsp_capabilities(),
    on_attach = on_attach,
    path = rzls_path(),
  }

  if root and root ~= "" then
    vim.fn.chdir(cwd)
  end
end

local function easy_dotnet_lsp_settings()
  return {
    ["csharp|background_analysis"] = {
      dotnet_analyzer_diagnostics_scope = "fullSolution",
      dotnet_compiler_diagnostics_scope = "fullSolution",
    },
    ["csharp|code_lens"] = {
      dotnet_enable_references_code_lens = true,
      dotnet_enable_tests_code_lens = true,
    },
    ["csharp|completion"] = {
      dotnet_provide_regex_completions = true,
      dotnet_show_completion_items_from_unimported_namespaces = true,
      dotnet_show_name_completion_suggestions = true,
    },
    ["csharp|formatting"] = {
      dotnet_organize_imports_on_format = true,
    },
    ["csharp|inlay_hints"] = {
      csharp_enable_inlay_hints_for_implicit_object_creation = true,
      csharp_enable_inlay_hints_for_implicit_variable_types = true,
      csharp_enable_inlay_hints_for_lambda_parameter_types = true,
      csharp_enable_inlay_hints_for_types = true,
      dotnet_enable_inlay_hints_for_indexer_parameters = true,
      dotnet_enable_inlay_hints_for_literal_parameters = true,
      dotnet_enable_inlay_hints_for_object_creation_parameters = true,
      dotnet_enable_inlay_hints_for_other_parameters = true,
      dotnet_enable_inlay_hints_for_parameters = true,
      dotnet_suppress_inlay_hints_for_parameters_that_differ_only_by_suffix = true,
      dotnet_suppress_inlay_hints_for_parameters_that_match_argument_name = true,
      dotnet_suppress_inlay_hints_for_parameters_that_match_method_intent = true,
    },
    ["csharp|symbol_search"] = {
      dotnet_search_reference_assemblies = true,
    },
  }
end

local function bridge_easy_dotnet_to_rzls()
  local ok_constants, constants = pcall(require, "easy-dotnet.constants")
  if ok_constants then
    constants.lsp_client_name = "roslyn"
  end

  local ok_razor, razor = pcall(require, "rzls.razor")
  if ok_razor then
    razor.lsp_names[razor.language_kinds.csharp] = "roslyn"
  end
end

local function mark_roslyn_initialized()
  local config = vim.lsp.config.roslyn
  if not config or not config.handlers then
    return
  end

  local original = config.handlers["workspace/projectInitializationComplete"]
  if not original or config.handlers._user_roslyn_ready_wrapped then
    return
  end

  config.handlers._user_roslyn_ready_wrapped = true
  config.handlers["workspace/projectInitializationComplete"] = function(err, result, ctx, handler_config)
    _G.roslyn_initialized = true
    vim.api.nvim_exec_autocmds("User", { pattern = "RoslynInitialized" })
    return original(err, result, ctx, handler_config)
  end
end

local function nearest_project(path)
  if path == "" then
    return nil
  end

  local directory = vim.fs.dirname(vim.fs.normalize(path))
  local matches = vim.fs.find(function(name)
    return name:match("%.csproj$") or name:match("%.fsproj$")
  end, {
    path = directory,
    upward = true,
    limit = 1,
  })

  return matches[1]
end

local function diagnostic_include_warnings(severity_filter)
  if not severity_filter then
    severity_filter = require("easy-dotnet.options").options.diagnostics.default_severity
  end

  return severity_filter ~= "error"
end

local function diagnostic_filter()
  return function(filename)
    return (filename:match "%.cs$" or filename:match "%.fs$") and not filename:match "/obj/" and not filename:match "/bin/"
  end
end

local function selected_diagnostic_target(bufnr)
  local ok, current_solution = pcall(require, "easy-dotnet.current_solution")
  if ok then
    local selected = current_solution.try_get_selected_solution()
    if selected then
      return selected
    end
  end

  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local path = vim.api.nvim_buf_get_name(bufnr)

  local solution = nearest_solution(path)
  if solution then
    return solution
  end

  return nearest_project(path)
end

local function override_easy_dotnet_diagnostics()
  local ok_actions, actions = pcall(require, "easy-dotnet.actions.diagnostics")
  if not ok_actions then
    return
  end

  local original = actions.get_workspace_diagnostics

  actions.get_workspace_diagnostics = function(severity_filter)
    local target = selected_diagnostic_target()
    if not target then
      return original(severity_filter)
    end

    local rpc = require "easy-dotnet.rpc.rpc"
    local diagnostics = require "easy-dotnet.diagnostics"

    rpc.global_rpc_client:initialize(function()
      rpc.global_rpc_client.roslyn:get_workspace_diagnostics(
        target,
        diagnostic_include_warnings(severity_filter),
        function(response)
          diagnostics.populate_diagnostics(response, diagnostic_filter())
        end
      )
    end)
  end
end

local function default_task_from_prompt(prompt)
  if type(prompt) ~= "string" then
    return nil
  end

  local lower = prompt:lower()

  if lower:match "pick project to build" then
    return "build"
  end

  if lower:match "pick project to run" then
    return "run"
  end

  if lower:match "pick project to test" then
    return "test"
  end

  if lower:match "pick test project" then
    return "test"
  end

  if lower:match "pick project to watch" then
    return "watch"
  end

  if lower:match "pick project to view" then
    return "view"
  end

  return nil
end

local function persisted_default_project_name(solution, task_type)
  local ok_default, default_manager = pcall(require, "easy-dotnet.default-manager")
  if not ok_default or not solution or not task_type then
    return nil
  end

  local cache_file = default_manager.try_get_cache_file(solution)
  if not cache_file or vim.fn.filereadable(cache_file) ~= 1 then
    return nil
  end

  local ok_read, lines = pcall(vim.fn.readfile, cache_file)
  if not ok_read then
    return nil
  end

  local ok_decode, decoded = pcall(vim.fn.json_decode, table.concat(lines, "\n"))
  if not ok_decode or type(decoded) ~= "table" then
    return nil
  end

  local key = string.format("default_%s_project", task_type)
  local persisted = decoded[key]

  if type(persisted) == "string" then
    return persisted ~= "Solution" and persisted or nil
  end

  if type(persisted) == "table" and persisted.type == "project" then
    return persisted.project
  end

  return nil
end

local function default_picker_choice(items, prompt)
  local task_type = default_task_from_prompt(prompt)
  if not task_type then
    return nil
  end

  local ok_solution, current_solution = pcall(require, "easy-dotnet.current_solution")
  if not ok_solution then
    return nil
  end

  local project_name = persisted_default_project_name(current_solution.try_get_selected_solution(), task_type)
  if not project_name then
    return nil
  end

  for _, item in ipairs(items or {}) do
    if type(item) == "table" and type(item.display) == "string" then
      if item.display == project_name or item.display:match("^" .. vim.pesc(project_name) .. "%s*%(") then
        return item
      end
    end
  end

  return nil
end

local function override_easy_dotnet_picker_defaults()
  local ok_picker, picker = pcall(require, "easy-dotnet.picker")
  if not ok_picker or picker._user_default_wrapped then
    return
  end

  picker._user_default_wrapped = true

  local original_picker = picker.picker
  local original_preview_picker = picker.preview_picker

  picker.picker = function(_, items, on_choice, prompt, ...)
    local choice = default_picker_choice(items, prompt)
    if choice then
      on_choice(choice)
      return
    end

    return original_picker(_, items, on_choice, prompt, ...)
  end

  picker.preview_picker = function(_, items, on_choice, prompt, ...)
    local choice = default_picker_choice(items, prompt)
    if choice then
      on_choice(choice)
      return
    end

    return original_preview_picker(_, items, on_choice, prompt, ...)
  end
end

local function terminal_output_line(bufnr)
  if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
    return nil
  end

  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  for index = #lines, 1, -1 do
    local line = lines[index]
    if line ~= "" and not line:match "^%[Process exited %d+%]$" then
      return index
    end
  end

  return nil
end

local function focus_terminal_output(winid, bufnr)
  if not winid or not vim.api.nvim_win_is_valid(winid) then
    return
  end

  local line = terminal_output_line(bufnr)
  if not line then
    return
  end

  vim.api.nvim_win_set_cursor(winid, { line, 0 })
  vim.api.nvim_win_call(winid, function()
    vim.cmd "normal! zt"
  end)
end

local function override_easy_dotnet_terminal()
  local ok_terminal, terminal = pcall(require, "easy-dotnet.terminal")
  if not ok_terminal or terminal._user_output_wrapped then
    return
  end

  terminal._user_output_wrapped = true

  local original_show = terminal.show
  terminal.show = function()
    local had_window = terminal.state.win and vim.api.nvim_win_is_valid(terminal.state.win)
    original_show()

    if terminal.state.buf and vim.api.nvim_buf_is_valid(terminal.state.buf) then
      vim.b[terminal.state.buf].easy_dotnet_terminal = true
    end

    if terminal.state.win and vim.api.nvim_win_is_valid(terminal.state.win) and not had_window then
      vim.api.nvim_win_set_height(terminal.state.win, math.max(10, vim.api.nvim_win_get_height(terminal.state.win)))
    end

    if terminal.state.last_status == "finished" then
      focus_terminal_output(terminal.state.win, terminal.state.buf)
    end
  end

  vim.api.nvim_create_autocmd("TermClose", {
    group = vim.api.nvim_create_augroup("UserEasyDotnetTerminal", { clear = true }),
    callback = function(args)
      local state = terminal.state
      if args.buf ~= state.buf then
        return
      end

      vim.schedule(function()
        focus_terminal_output(state.win, state.buf)
      end)
    end,
  })
end

local function override_easy_dotnet_secrets()
  local ok_secrets, secrets = pcall(require, "easy-dotnet.secrets")
  if not ok_secrets or secrets._user_recursive_wrapped then
    return
  end

  secrets._user_recursive_wrapped = true

  local original = secrets.edit_secrets_picker
  secrets.edit_secrets_picker = function(get_secret_path)
    local function ensure_secret_path(secret_id)
      local path = get_secret_path(secret_id)
      local parent = path and vim.fs.dirname(path) or nil
      if parent and parent ~= "" then
        vim.fn.mkdir(parent, "p")
      end
      return path
    end

    return original(ensure_secret_path)
  end
end

local function override_easy_dotnet_root_dir()
  local ok_client, dotnet_client = pcall(require, "easy-dotnet.rpc.dotnet-client")
  if not ok_client or dotnet_client._user_root_wrapped then
    return
  end

  dotnet_client._user_root_wrapped = true

  function dotnet_client:_initialize(cb, opts)
    opts = opts or {}

    coroutine.wrap(function()
      local current_solution = require "easy-dotnet.current_solution"
      local use_visual_studio = require("easy-dotnet.options").options.server.use_visual_studio == true
      local debugger_path = require("easy-dotnet.options").options.debugger.bin_path
      local ext_terminal = require("easy-dotnet.options").options.external_terminal
      local apply_value_converters = require("easy-dotnet.options").options.debugger.apply_value_converters
      local debugger_options = {
        applyValueConverters = apply_value_converters,
        binaryPath = debugger_path,
      }

      current_solution.get_or_pick_solution(function(sln_file)
        local root_dir = active_dotnet_root() or (sln_file and vim.fs.dirname(sln_file)) or vim.fs.normalize(vim.fn.getcwd())

        dotnet_client.create_rpc_call({
          client = self._client,
          job = {
            name = "Initializing...",
            on_success_text = "Client initialized",
            on_error_text = "Failed to initialize server",
          },
          cb = cb,
          on_crash = opts.on_crash,
          method = "initialize",
          params = {
            request = {
              clientInfo = {
                name = "EasyDotnet",
                version = "3.0.0",
                pid = vim.fn.getpid(),
              },
              projectInfo = {
                rootDir = vim.fs.normalize(root_dir),
                solutionFile = sln_file,
              },
              options = {
                useVisualStudio = use_visual_studio,
                debuggerOptions = debugger_options,
                externalTerminal = ext_terminal,
              },
            },
          },
        })()
      end)
    end)()
  end
end

function M.setup_roslyn()
  local config = {
    cmd = roslyn_cmd(),
    capabilities = lsp_capabilities(),
    on_attach = on_attach,
    settings = {
      ["csharp|background_analysis"] = {
        dotnet_analyzer_diagnostics_scope = "fullSolution",
        dotnet_compiler_diagnostics_scope = "fullSolution",
      },
      ["csharp|code_lens"] = {
        dotnet_enable_references_code_lens = true,
        dotnet_enable_tests_code_lens = true,
      },
      ["csharp|completion"] = {
        dotnet_provide_regex_completions = true,
        dotnet_show_completion_items_from_unimported_namespaces = true,
        dotnet_show_name_completion_suggestions = true,
      },
      ["csharp|formatting"] = {
        dotnet_organize_imports_on_format = true,
      },
      ["csharp|inlay_hints"] = {
        csharp_enable_inlay_hints_for_implicit_object_creation = true,
        csharp_enable_inlay_hints_for_implicit_variable_types = true,
        csharp_enable_inlay_hints_for_lambda_parameter_types = true,
        csharp_enable_inlay_hints_for_types = true,
        dotnet_enable_inlay_hints_for_indexer_parameters = true,
        dotnet_enable_inlay_hints_for_literal_parameters = true,
        dotnet_enable_inlay_hints_for_object_creation_parameters = true,
        dotnet_enable_inlay_hints_for_other_parameters = true,
        dotnet_enable_inlay_hints_for_parameters = true,
        dotnet_suppress_inlay_hints_for_parameters_that_differ_only_by_suffix = true,
        dotnet_suppress_inlay_hints_for_parameters_that_match_argument_name = true,
        dotnet_suppress_inlay_hints_for_parameters_that_match_method_intent = true,
      },
      ["csharp|symbol_search"] = {
        dotnet_search_reference_assemblies = true,
      },
    },
  }

  local ok_rzls, roslyn_handlers = pcall(require, "rzls.roslyn_handlers")
  if ok_rzls then
    config.handlers = roslyn_handlers
  end

  vim.lsp.config("roslyn", config)
  setup_rzls()

  require("roslyn").setup {
    broad_search = true,
    filewatching = "auto",
    lock_target = false,
    silent = false,
  }
end

function M.setup_easy_dotnet()
  ensure_dotnet_tools_on_path()
  bridge_easy_dotnet_to_rzls()

  require("easy-dotnet").setup {
    picker = "telescope",
    managed_terminal = {
      auto_hide = false,
      auto_hide_delay = 0,
    },
    lsp = {
      enabled = true,
      preload_roslyn = true,
      roslynator_enabled = true,
      easy_dotnet_analyzer_enabled = true,
      config = {
        settings = easy_dotnet_lsp_settings(),
      },
    },
    debugger = {
      auto_register_dap = false,
      bin_path = paths.first(paths.mason_path("netcoredbg", "netcoredbg"), paths.executable "netcoredbg"),
    },
    diagnostics = {
      default_severity = "warning",
      setqflist = false,
    },
    new = {
      project = {
        prefix = "sln",
      },
    },
  }

  override_easy_dotnet_root_dir()
  override_easy_dotnet_picker_defaults()
  override_easy_dotnet_diagnostics()
  override_easy_dotnet_terminal()
  override_easy_dotnet_secrets()
  mark_roslyn_initialized()
  setup_rzls()

  local group = vim.api.nvim_create_augroup("UserEasyDotnetSolution", { clear = true })

  vim.api.nvim_create_autocmd({ "BufEnter", "BufWinEnter", "DirChanged", "VimEnter" }, {
    group = group,
    callback = function(args)
      M.sync_easy_dotnet_solution(args.buf or 0)
    end,
  })

  M.sync_easy_dotnet_solution()
end

function M.extend_cmp(opts)
  local cmp = require "cmp"
  local source_name = "easy-dotnet"

  cmp.register_source(source_name, require("easy-dotnet").package_completion_source)

  for _, source in ipairs(opts.sources or {}) do
    if source.name == source_name then
      return opts
    end
  end

  table.insert(opts.sources, 2, { name = source_name })

  return opts
end

function M.format_buffer(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  if vim.bo[bufnr].filetype ~= "cs" then
    require("conform").format {
      async = false,
      lsp_fallback = true,
      buf = bufnr,
    }
    return true
  end

  local filename = vim.api.nvim_buf_get_name(bufnr)
  local csharpier = csharpier_path()

  if filename == "" or not csharpier then
    vim.notify("C# formatting requires a saved file and csharpier", vim.log.levels.WARN)
    return false
  end

  local text = table.concat(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), "\n")
  if vim.bo[bufnr].endofline then
    text = text .. "\n"
  end

  local result = vim
    .system({
      csharpier,
      "format",
      "--write-stdout",
      "--stdin-path",
      filename,
    }, {
      stdin = text,
      text = true,
    })
    :wait()

  if result.code ~= 0 then
    local message = result.stderr ~= "" and result.stderr or result.stdout
    vim.notify(message ~= "" and message or "csharpier failed", vim.log.levels.ERROR)
    return false
  end

  local formatted_lines = vim.split(result.stdout, "\n", { plain = true })
  if formatted_lines[#formatted_lines] == "" then
    table.remove(formatted_lines)
  end

  local view = vim.fn.winsaveview()
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, formatted_lines)
  vim.fn.winrestview(view)

  return true
end

return M
