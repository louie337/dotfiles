local servers = { "lua_ls", "ts_ls", "ruff", "gopls" }

local on_attach = function(client, buffer)
  if client:supports_method("textDocument/documentSymbol") then
    require("nvim-navic").attach(client, buffer)
  end
end

local function file_contains(path, pattern)
  if vim.fn.filereadable(path) == 0 then
    return false
  end

  return string.find(table.concat(vim.fn.readfile(path), "\n"), pattern) ~= nil
end

local function configure_lsp_defaults()
  vim.lsp.config("*", {
    capabilities = require("blink.cmp").get_lsp_capabilities(),
    on_attach = on_attach,
  })

  vim.lsp.config("ts_ls", {
    on_attach = on_attach,
  })

  vim.lsp.config("ruff", {
    init_options = {
      settings = {},
    },
  })

  vim.lsp.config("pyrefly", {
    cmd = { "uv", "tool", "run", "pyrefly", "lsp" },
    filetypes = { "python" },
    root_dir = function(bufnr, on_dir)
      local root = vim.fs.root(bufnr, { "pyrefly.toml", "pyproject.toml", "mypy.ini" })
      if root and (
        vim.fn.filereadable(root .. "/pyrefly.toml") == 1
        or vim.fn.filereadable(root .. "/mypy.ini") == 1
        or file_contains(root .. "/pyproject.toml", "pyrefly")
      ) then
        on_dir(root)
      end
    end,
  })
end

return {
  {
    -- NOTE: LSP Server Manager
    "williamboman/mason.nvim",
    config = true,
  },
  {
    "mason-org/mason-lspconfig.nvim",
    dependencies = { "saghen/blink.cmp" },
    config = function()
      configure_lsp_defaults()

      require("mason-lspconfig").setup({
        ensure_installed = servers,
        automatic_enable = true,
      })

      vim.lsp.enable("pyrefly")
    end,
  },
  {
    -- NOTE: LSP Configuration & Plugins
    "neovim/nvim-lspconfig",
    dependencies = { "saghen/blink.cmp", "mason-org/mason-lspconfig.nvim" },
    keys = {
      { "<leader>wa", vim.lsp.buf.add_workspace_folder,        desc = "[W]orkspace [A]dd Folder" },
      { "<leader>wr", vim.lsp.buf.remove_workspace_folder,     desc = "[W]orkspace [R]emove Folder" },
      { "<leader>rn", vim.lsp.buf.rename,                      desc = "[R]e[N]ame" },
      { "<leader>ca", vim.lsp.buf.code_action,                 desc = "[C]ode [A]ction" },
    },
  },
}
