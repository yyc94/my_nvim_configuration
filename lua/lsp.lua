-- 1. Mason 配置（不变）
require('mason').setup({
    ui = {
        icons = {
            package_installed = "✓",
            package_pending = "➜",
            package_uninstalled = "✗"
        }
    }
})

require('mason-lspconfig').setup({
    ensure_installed = { 'clangd', 'pylsp', 'lua_ls', 'rust_analyzer' },
})

-- 2. 诊断配置（不变）
vim.diagnostic.config({
  virtual_text = {
    enabled = true,
    prefix = '●',
    severity_limit = 'Error'
  },
  signs = true,
  underline = true,
  update_in_insert = false,
  severity_sort = true,
  float = {
    focusable = false,
    style = 'minimal',
    border = 'rounded',
    source = 'always',
  },
})

-- 3. 基础配置（不变）
local capabilities = vim.lsp.protocol.make_client_capabilities()
capabilities.offsetEncoding = { "utf-8", "utf-16" }  -- clangd 兼容

-- 全局快捷键（不变）
local opts = { noremap = true, silent = true }
vim.keymap.set("n", "<space>e", vim.diagnostic.open_float, opts)
vim.keymap.set("n", "[d", vim.diagnostic.goto_prev, opts)
vim.keymap.set("n", "]d", vim.diagnostic.goto_next, opts)
vim.keymap.set("n", "<space>q", vim.diagnostic.setloclist, opts)

-- 通用 on_attach 函数（不变）
local on_attach = function(client, bufnr)
	vim.api.nvim_buf_set_option(bufnr, "omnifunc", "v:lua.vim.lsp.omnifunc")

	if client.name == "rust_analyzer" then
		vim.lsp.inlay_hint.enable(bufnr, true)  -- 修正：新版需要传 bufnr
	end

	local bufopts = { noremap = true, silent = true, buffer = bufnr }
	vim.keymap.set("n", "gi", vim.lsp.buf.implementation, bufopts)
	vim.keymap.set("n", "<space>wa", vim.lsp.buf.add_workspace_folder, bufopts)
	vim.keymap.set("n", "<space>wr", vim.lsp.buf.remove_workspace_folder, bufopts)
	vim.keymap.set("n", "<space>wl", function()
		print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
	end, bufopts)
	vim.keymap.set("n", "<space>D", vim.lsp.buf.type_definition, bufopts)
	vim.keymap.set("n", "<space>rn", vim.lsp.buf.rename, bufopts)
	vim.keymap.set("n", "<space>ca", vim.lsp.buf.code_action, bufopts)
	vim.keymap.set("n", "gr", vim.lsp.buf.references, bufopts)
	vim.keymap.set("n", "<space>f", function()
		vim.lsp.buf.format({
			async = true,
			filter = function(client)
				return client.name == "null-ls" or client.name == "hls"
			end,
		})
	end, bufopts)
end

-- 4. 核心修改：定义 LSP 配置模板（替代 lspconfig.xxx.setup）
local util = require('lspconfig.util')  -- 仅保留 util 工具函数，不用 lspconfig 框架

-- 通用 LSP 启动函数（封装重复逻辑）
local start_lsp = function(lsp_name, filetypes, custom_config)
  -- 合并默认配置和自定义配置
  local config = vim.tbl_deep_extend('force', {
    name = lsp_name,
    capabilities = capabilities,
    on_attach = on_attach,
    root_dir = util.root_pattern('.git'),  -- 默认根目录规则
  }, custom_config or {})

  -- 注册 FileType 自动命令，按需启动 LSP
  vim.api.nvim_create_autocmd('FileType', {
    pattern = filetypes,
    callback = function()
      -- 自动识别根目录（关键：替代 lspconfig 的自动根目录检测）
      local root_dir = config.root_dir(vim.api.nvim_buf_get_name(0)) or vim.fn.getcwd()
      config.root_dir = root_dir

      -- 启动 LSP（官方推荐的新方式，无警告）
      vim.lsp.start(config)
    end,
    desc = string.format("Start %s LSP", lsp_name),
  })
end

-- 5. 逐个配置 LSP（彻底抛弃 lspconfig.xxx.setup）
-- 5.1 基础 LSP（pylsp/gopls/bashls/rust_analyzer/ocamllsp/ruby_lsp/hls）
start_lsp('pylsp', {'python'})
start_lsp('gopls', {'go', 'gomod', 'gowork', 'gotmpl'})
start_lsp('bashls', {'sh', 'bash'})
start_lsp('rust_analyzer', {'rust'}, {
  settings = {
    ['rust-analyzer'] = {
      cargo = { allFeatures = true },
      checkOnSave = {
        command = 'clippy',
      },
    },
  },
})
start_lsp('ocamllsp', {'ocaml', 'ocaml.interface', 'ocamllex'})
start_lsp('ruby_lsp', {'ruby'})
start_lsp('hls', {'haskell', 'lhaskell'})

-- 5.2 lua_ls 自定义配置
start_lsp('lua_ls', {'lua'}, {
  cmd = {'lua-language-server'},
  settings = {
    Lua = {
      runtime = { version = "LuaJIT" },
      diagnostics = { globals = { "vim" } },
      workspace = { library = vim.api.nvim_get_runtime_file("", true) },
      telemetry = { enable = false },
    },
  },
  root_dir = util.root_pattern('.git', 'lua', '.luarc.json'),
})

-- 5.3 clangd 专属配置（保留你所有自定义逻辑）
start_lsp('clangd', {'c', 'cpp', 'objc', 'objcpp', 'cuda'}, {
  cmd = {
    "clangd",
    "--background-index",
    "--clang-tidy=false",
    "--header-insertion=iwyu",
    "--completion-style=detailed",
    "--function-arg-placeholders",
    "--all-scopes-completion",
    "--pch-storage=memory",
    "--pretty",
    "--limit-references=0",
    "--limit-workspace-search=0"
  },
  on_attach = function(client, bufnr)
    on_attach(client, bufnr)
    client.server_capabilities.diagnosticProvider = {
      interFileDependencies = true,
      workspaceDiagnostics = true
    }
    client.server_capabilities.documentFormattingProvider = false
  end,
  init_options = {
    fallbackFlags = { "-std=c++20", "--include-directory=./include" },
    cache = { directory = vim.fn.stdpath("cache") .. "/clangd" }
  },
  root_dir = util.root_pattern(
    "compile_commands.json",
    "compile_flags.txt",
    ".git",
    "CMakeLists.txt",
    "Makefile",
    ".clangd"
  ),
  single_file_support = true,
  flags = {
    debounce_text_changes = 150,
    allow_incremental_sync = true
  }
})
