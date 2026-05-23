return {
	"saghen/blink.cmp",
	dependencies = {
		"saghen/blink.lib",
		"folke/lazydev.nvim",
		-- "rafamadriz/friendly-snippets",
	},
	opts = {
		keymap = {
			preset = "default",
			["<C-space>"] = {},
			["<C-n>"] = { "show", "select_next" },
		},

		completion = {
			keyword = { range = "full" },
			accept = { auto_brackets = { enabled = false } },
			menu = {
				auto_show = true,
				draw = {
					columns = {
						{ "label", "label_description", gap = 4 },
						{ "kind_icon", "kind" },
					},
				},
			},
			documentation = { auto_show = true },
			ghost_text = { enabled = true },
		},

		fuzzy = { implementation = "lua" },

		sources = {
			default = { "lsp", "path", "buffer", "snippets" },
			providers = {
				lsp = {
					score_offset = 10,
				},
				snippets = {
					score_offset = 0,
				},
			},
		},
	},
}
