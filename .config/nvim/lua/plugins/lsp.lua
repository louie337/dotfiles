local telescope = require("telescope.builtin")

return {
  {
    -- NOTE: LSP Server Manager
    "williamboman/mason.nvim",
    config = true,
  },
  {
    "mason-org/mason-lspconfig.nvim",
    config = true,
  },
  {
    -- NOTE: LSP Configuration & Plugins
    "neovim/nvim-lspconfig",
    dependencies = { "saghen/blink.cmp", "mason-org/mason-lspconfig.nvim" },
    keys = {
      { "gd",         telescope.lsp_definitions,               desc = "[G]o to [D]efinitions" },
      { "gr",         telescope.lsp_references,                desc = "[G]o to [R]eferences" },
      { "gI",         telescope.lsp_implementations,           desc = "[G]o to [I]mplementation" },
      { "gD",         telescope.lsp_type_definitions,          desc = "[G]o to Type [D]efinition" },
      { "gx",         telescope.diagnostics,                   desc = "Go to [D]iagnostics" },
      { "<leader>ds", telescope.lsp_document_symbols,          desc = "[D]ocument [S]ymbols" },
      { "<leader>ws", telescope.lsp_workspace_symbols,         desc = "[W]orkspace [S]ymbols" },
      { "<leader>wS", telescope.lsp_dynamic_workspace_symbols, desc = "[W]orkspace Dynamic [S]ymbols" },
      { "<leader>wa", vim.lsp.buf.add_workspace_folder,        desc = "[W]orkspace [A]dd Folder" },
      { "<leader>wr", vim.lsp.buf.remove_workspace_folder,     desc = "[W]orkspace [R]emove Folder" },
      { "<leader>rn", vim.lsp.buf.rename,                      desc = "[R]e[N]ame" },
      { "<leader>ca", vim.lsp.buf.code_action,                 desc = "[C]ode [A]ction" },
    },
  },
}
