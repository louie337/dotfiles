local dashboard = require("plugins.snacks.dashboard")
local explorer = require("plugins.snacks.explorer")
local explorer_hidden = false

local function current_explorer()
	return Snacks.picker.get({ source = "explorer" })[1]
end

local function explorer_opts(opts)
	local current = current_explorer()
	if current then
		explorer_hidden = current.opts.hidden
	end
	opts = vim.tbl_extend("force", { hidden = explorer_hidden }, opts or {})
	local on_close = opts.on_close
	opts.on_close = function(picker)
		explorer_hidden = picker.opts.hidden
		if on_close then
			on_close(picker)
		end
	end
	return opts
end

local function reveal_explorer()
	if current_explorer() then
		Snacks.explorer.reveal()
	else
		Snacks.explorer(explorer_opts({
			on_show = function()
				Snacks.explorer.reveal()
			end,
		}))
	end
end

return {
	"folke/snacks.nvim",
	-- enabled=false,
	dependencies = {},
	priority = 1000,
	lazy = false,
	---@type snacks.Config
	opts = {
		bigfile = { enabled = true },
		image = { enabled = false },
		dashboard = dashboard,
		explorer = { enabled = true },
		indent = { enabled = true },
		input = { enabled = false },
		picker = {
			enabled = true,
			sources = {
				explorer = explorer,
			},
		},
		notifier = { enabled = false },
		quickfile = { enabled = true },
		scope = { enabled = true },
		statuscolumn = { enabled = false },
		words = { enabled = true },
		lazygit = { enabled = true },
		zen = { enabled = true },
	},
	keys = {
		{
			"<leader>e",
			function()
				Snacks.explorer(explorer_opts())
			end,
			desc = "[E]xplore Snacks Explorer",
		},
		{ "<leader>E", reveal_explorer, desc = "[E]xplore Current File" },
		{
			"<leader>Sz",
			function()
				Snacks.zen()
			end,
			desc = "[Z]en Mode",
		},
		{
			"<leader>SZ",
			function()
				Snacks.zen.Zoom()
			end,
			desc = "[Z]en Zoom Mode",
		},
	},
}
