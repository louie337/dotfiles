return {
	"nvim-lualine/lualine.nvim",
	event = "VeryLazy",
	opts = function(_, opts)
		local icons = require("options.icons")
		local noice = require("noice")

		local function fg(name)
			return function()
				---@type {foreground?:number}?
				local hl = vim.api.nvim_get_hl_by_name(name, true)
				return hl and hl.foreground and { fg = string.format("#%06x", hl.foreground) }
			end
		end

		return {
			options = {
				theme = "auto",
				globalstatus = true,
				disabled_filetypes = { statusline = { "dashboard", "lazy", "alpha" } },
			},
			sections = {
				lualine_a = {
					{
						"mode",
					},
				},
				lualine_b = { "branch" },
				lualine_c = {
					{
						"filetype",
						icon_only = true,
						separator = "",
						padding = { left = 1, right = 0 },
					},
					{ "filename", path = 1, symbols = { modified = "  ", readonly = "", unnamed = "" } },
					{
						function()
							return require("nvim-navic").get_location()
						end,
						cond = function()
							return package.loaded["nvim-navic"] and require("nvim-navic").is_available()
						end,
					},
				},
				lualine_x = {
					{
						"diff",
						symbols = {
							added = icons.git.added,
							modified = icons.git.modified,
							removed = icons.git.removed,
						},
					},
				},
				lualine_y = {
					{ "location", padding = { left = 0, right = 0 } },
				},
				lualine_z = {
					{ "progress", separator = " ", padding = { left = 1, right = 1 } },
				},
			},
			extensions = { "neo-tree" },
		}
	end,
}
