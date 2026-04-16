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

  require("easy-dotnet").setup {
    picker = "telescope",
    lsp = {
      enabled = false,
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
