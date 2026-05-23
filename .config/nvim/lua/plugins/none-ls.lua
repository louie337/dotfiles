return {
	"nvimtools/none-ls.nvim",
	dependencies = {
		"nvimtools/none-ls-extras.nvim",
	},
	config = function()
		local null_ls = require("null-ls")

		null_ls.setup({
			sources = {
				-- NOTE: Lua settings
				null_ls.builtins.formatting.stylua,

				-- NOTE: Golang settings
				null_ls.builtins.formatting.gofmt,

				-- NOTE: Python settings
				-- Use mypy for type checking
				null_ls.builtins.diagnostics.mypy.with({
					command = "uv",
					args = { "run", "mypy", "--show-column-numbers", "$FILENAME" },
				}),

				-- NOTE: Prettier settings
				null_ls.builtins.formatting.prettier.with({
					only_local = "node_modules/.bin",
					extra_filetypes = { "mdx" },
				}),

				-- NOTE: Eslnit settings
				require("none-ls.diagnostics.eslint_d").with({
					condition = function(utils)
						return utils.root_has_file_matches("eslintrc")
					end,
					only_local = "node_modules/.bin",
				}),
				require("none-ls.code_actions.eslint_d").with({
					condition = function(utils)
						return utils.root_has_file_matches("eslintrc")
					end,
					only_local = "node_modules/.bin",
				}),

				-- NOTE: Cspell settings
				null_ls.builtins.diagnostics.codespell.with({
					diagnostics_postprocess = function(diagnostic)
						diagnostic.severity = vim.diagnostic.severity.HINT
					end,
				}),

				-- NOTE: hover show word's definition
				null_ls.builtins.hover.dictionary,
			},
		})
	end,
}
