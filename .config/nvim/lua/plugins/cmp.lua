return {
	"saghen/blink.cmp",
	dependencies = {
		"folke/lazydev.nvim",
		"hrsh7th/nvim-cmp",
		"Kaiser-Yang/blink-cmp-avante",
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
			default = { "avante", "lsp", "path", "buffer", "snippets" },
			providers = {
				lsp = {
					score_offset = 10,
				},
				snippets = {
					score_offset = 0,
				},
				avante = {
					module = "blink-cmp-avante",
					name = "Avante",
				},
			},
		},
	},
}
