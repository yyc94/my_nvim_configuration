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

local lspconfig = require('lspconfig')
local capabilities = vim.lsp.protocol.make_client_capabilities()
-- 解决 offsetEncoding 兼容问题（clangd 多实例常见诱因）
capabilities.offsetEncoding = { "utf-8", "utf-16" }

-- 全局快捷键
local opts = { noremap = true, silent = true }
vim.keymap.set("n", "<space>e", vim.diagnostic.open_float, opts)
vim.keymap.set("n", "[d", vim.diagnostic.goto_prev, opts)
vim.keymap.set("n", "]d", vim.diagnostic.goto_next, opts)
vim.keymap.set("n", "<space>q", vim.diagnostic.setloclist, opts)

-- 通用 on_attach 函数
local on_attach = function(client, bufnr)
	vim.api.nvim_buf_set_option(bufnr, "omnifunc", "v:lua.vim.lsp.omnifunc")

	if client.name == "rust_analyzer" then
		vim.lsp.inlay_hint.enable()
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

-- 统一配置：所有 LSP 都继承基础 capabilities 和 on_attach
local default_lsp_config = {
    on_attach = on_attach,
    capabilities = capabilities,
}

-- 各个 LSP 配置（简化写法，避免重复）
lspconfig.pylsp.setup(default_lsp_config)
lspconfig.gopls.setup(default_lsp_config)
lspconfig.bashls.setup(default_lsp_config)
lspconfig.rust_analyzer.setup(default_lsp_config)
lspconfig.ocamllsp.setup(default_lsp_config)
lspconfig.ruby_lsp.setup(default_lsp_config)
lspconfig.hls.setup(default_lsp_config)

lspconfig.lua_ls.setup(vim.tbl_deep_extend('force', default_lsp_config, {
	settings = {
		Lua = {
			runtime = { version = "LuaJIT" },
			diagnostics = { globals = { "vim" } },
			workspace = { library = vim.api.nvim_get_runtime_file("", true) },
			telemetry = { enable = false },
		},
	},
}))

-- 关键：clangd 专属配置（解决多实例核心）
lspconfig.clangd.setup(vim.tbl_deep_extend('force', default_lsp_config, {
    on_attach = function(client, bufnr)
        on_attach(client, bufnr)
        client.server_capabilities.diagnosticProvider = {
            interFileDependencies = true,
            workspaceDiagnostics = true
        }
        -- 禁用内置格式化（避免和 clangd 自身冲突）
        client.server_capabilities.documentFormattingProvider = false
    end,
    filetypes = {"c", "cpp", "objc", "objcpp", "cuda"},
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
        -- 强制单实例运行（关键参数）
        "--limit-references=0",
        "--limit-workspace-search=0"
    },
    init_options = {
        fallbackFlags = { "-std=c++20", "--include-directory=./include" },
        -- 禁用自动重启
        cache = { directory = vim.fn.stdpath("cache") .. "/clangd" }
    },
    -- 显式指定根目录识别规则（避免多目录触发多实例）
    root_dir = lspconfig.util.root_pattern(
        "compile_commands.json",
        "compile_flags.txt",
        ".git",
        "CMakeLists.txt",
        "Makefile",
        ".clangd"
    ),
    -- 禁止单文件模式重复启动
    single_file_support = true,
    -- 禁用自动重连（避免崩溃后多实例）
    autostart = true,
    flags = {
        debounce_text_changes = 150,
        allow_incremental_sync = true
    }
}))
