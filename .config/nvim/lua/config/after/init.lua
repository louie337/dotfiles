local on_attach = function(client, buffer)
	if client:supports_method("textDocument/documentSymbol") then
		require("nvim-navic").attach(client, buffer)
	end
end

vim.lsp.config("*", {
	on_attach = on_attach,
})
-- NOTE: Due to unknown reason ts_ls will use default config even applied "*" ones, so need to add this to override it
vim.lsp.config("ts_ls", {
	on_attach = on_attach,
})

vim.lsp.config('ruff', {
  init_options = {
    settings = {
      -- Ruff language server settings go here
    }
  }
})

vim.lsp.enable('ruff')


-- NOTE: Avante suggested settings
vim.opt.laststatus = 3
