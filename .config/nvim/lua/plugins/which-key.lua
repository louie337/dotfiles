local modes = { "n", "v", "i", "s" }

return {
	"folke/which-key.nvim",
	event = "VeryLazy",
	opts = {
		spec = {
			{ "<leader>a", group = "+[A]vante", mode = modes, icon = "" },
			{ "<leader>b", group = "+[B]uffer", mode = modes },
			{ "<leader>C", group = "+[C]opilot Chat", mode = modes, icon = "" },
			{ "<leader>c", group = "+[C]ode/ [Copilot]", mode = modes, icon = "" },
			{ "<leader>d", group = "+[D]ocument/ [D]iffvew", mode = modes },
			{ "<leader>r", group = "+[R]ename ", mode = modes },
			{ "<leader>w", group = "+[W]orkspace", mode = modes },
			{ "<leader>x", group = "+Trouble [X]", mode = modes },
			{ "<leader>p", group = "+[P]rint", mode = modes },
			{ "<leader>s", group = "+[S]earch", mode = modes },
			{ "<leader>K", group = "+[C]ase Change", mode = modes },
			{ "<leader>g", group = "+[G]ptPrompt", mode = modes, icon = "" },
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
