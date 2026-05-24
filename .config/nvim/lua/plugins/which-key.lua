local modes = { "n", "v", "i", "s" }

return {
	"folke/which-key.nvim",
	event = "VeryLazy",
	opts = {
		spec = {
			{ "<leader>b", group = "+[B]uffer", mode = modes },
			{ "<leader>c", group = "+[C]ode", mode = modes },
			{ "<leader>d", group = "+[D]ocument/ [D]iffview", mode = modes },
			{ "<leader>g", group = "+[G]itsigns", mode = modes },
			{ "<leader>r", group = "+[R]ename ", mode = modes },
			{ "<leader>w", group = "+[W]orkspace", mode = modes },
			{ "<leader>x", group = "+Trouble [X]", mode = modes },
			{ "<leader>p", group = "+[P]rint", mode = modes },
			{ "<leader>s", group = "+[S]earch", mode = modes },
			{ "<leader>S", group = "+[S]nacks", mode = modes },
			{ "<leader>K", group = "+[C]ase Change", mode = modes },
		},
	},
	keys = {
		{
			"<leader>?",
			function()
				require("which-key").show({ global = false })
			end,
			desc = "Buffer Local Keymaps (which-key)",
		},
	},
}
