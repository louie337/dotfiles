local dashboard = require("plugins.snacks.dashboard")
local explorer = require("plugins.snacks.explorer")
local explorer_hidden = true
local explorer_ignored = false

local function current_explorer()
	return Snacks.picker.get({ source = "explorer" })[1]
end

local function explorer_opts(opts)
	local current = current_explorer()
	if current then
		explorer_hidden = current.opts.hidden
		explorer_ignored = current.opts.ignored
	end
	opts = vim.tbl_extend("force", { hidden = explorer_hidden, ignored = explorer_ignored }, opts or {})
	local on_close = opts.on_close
	opts.on_close = function(picker)
		explorer_hidden = picker.opts.hidden
		explorer_ignored = picker.opts.ignored
		if on_close then
			on_close(picker)
		end
	end
	return opts
end

local function focus_explorer()
	local current = current_explorer()
	if current then
		current:focus("list", { show = true })
	else
		Snacks.explorer(explorer_opts())
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
		input = { enabled = true },
		notifier = {
			enabled = true,
			timeout = 3000,
		},
		picker = {
			enabled = true,
			sources = {
				explorer = explorer,
			},
		},
		quickfile = { enabled = true },
		scope = { enabled = true },
		scroll = { enabled = false },
		statuscolumn = { enabled = true },
		words = { enabled = true },
		lazygit = { enabled = true },
		rename = { enabled = true },
		scratch = { enabled = true },
		terminal = { enabled = true },
		zen = { enabled = true },
		styles = {
			notification = {
				-- wo = { wrap = true },
			},
		},
	},
	keys = {
		{
			"<leader>e",
			function()
				Snacks.explorer(explorer_opts())
			end,
			desc = "[S]earch [E]xplore Files",
		},
		{ "<leader>E", focus_explorer, desc = "[S]earch [E]xplorer Focus" },
		{
			"<leader>ss",
			function()
				Snacks.picker.spelling()
			end,
			desc = "[S]earch [S]pelling",
		},
		{
			"<leader>sb",
			function()
				Snacks.picker.buffers()
			end,
			desc = "[S]earch Buffers",
		},
		{
			"<leader>s:",
			function()
				Snacks.picker.command_history()
			end,
			desc = "[S]earch Command History",
		},
		{
			"<leader>sf",
			function()
				Snacks.picker.git_files()
			end,
			desc = "[S]earch [F]ind Git Files",
		},
		{
			"<leader>sr",
			function()
				Snacks.picker.recent()
			end,
			desc = "[S]earch [R]ecent Files",
		},
		{
			"<leader>/",
			function()
				Snacks.picker.lines()
			end,
			desc = "[S]earch [B]uffer Lines",
		},
		{
			"<leader>s?",
			function()
				Snacks.picker.grep_buffers()
			end,
			desc = "[S]earch Grep [B]uffers",
		},
		{
			"<leader>sg",
			function()
				Snacks.picker.git_grep()
			end,
			desc = "[S]earch [G]rep gitted files",
		},
		{
			"<leader>sh",
			function()
				Snacks.picker.grep({ hidden = true })
			end,
			desc = "[S]earch [H]idden grep",
		},
		{
			"<leader>sw",
			function()
				Snacks.picker.grep_word()
			end,
			desc = "[S]earch Current [W]ord",
			mode = { "n", "x" },
		},
		{
			'<leader>s"',
			function()
				Snacks.picker.registers()
			end,
			desc = "[S]earch Registers",
		},
		{
			"<leader>sC",
			function()
				Snacks.picker.commands()
			end,
			desc = "[S]earch [C]ommands",
		},
		{
			"<leader>sd",
			function()
				Snacks.picker.diagnostics()
			end,
			desc = "[S]earch [D]iagnostics",
		},
		{
			"<leader>sv",
			function()
				Snacks.picker.help()
			end,
			desc = "[S]earch [H]elp Pages",
		},
		{
			"<leader>si",
			function()
				Snacks.picker.icons()
			end,
			desc = "[S]earch [I]cons",
		},
		{
			"<leader>sj",
			function()
				Snacks.picker.jumps()
			end,
			desc = "[S]earch [J]umps",
		},
		{
			"<leader>sk",
			function()
				Snacks.picker.keymaps()
			end,
			desc = "[S]earch [K]eymaps",
		},
		{
			"<leader>sl",
			function()
				Snacks.picker.loclist()
			end,
			desc = "[S]earch [L]ocation List",
		},
		{
			"<leader>sm",
			function()
				Snacks.picker.marks()
			end,
			desc = "[S]earch [M]arks",
		},
		{
			"<leader>sM",
			function()
				Snacks.picker.man()
			end,
			desc = "[S]earch [M]an Pages",
		},
		{
			"<leader>sp",
			function()
				Snacks.picker.lazy()
			end,
			desc = "[S]earch [P]lugin Specs",
		},
		{
			"<leader>sq",
			function()
				Snacks.picker.qflist()
			end,
			desc = "[S]earch [Q]uickfix List",
		},
		{
			"<leader>sR",
			function()
				Snacks.picker.resume()
			end,
			desc = "[S]earch [R]esume Picker",
		},
		{
			"<leader>su",
			function()
				Snacks.picker.undo()
			end,
			desc = "[S]earch [U]ndo History",
		},
		{
			"<leader>sx",
			function()
				Snacks.picker.colorschemes()
			end,
			desc = "[S]earch Colorschemes",
		},
		{
			"<leader>sGb",
			function()
				Snacks.picker.git_branches()
			end,
			desc = "[S]earch [G]it [B]ranches",
		},
		{
			"<leader>sGl",
			function()
				Snacks.picker.git_log()
			end,
			desc = "[S]earch [G]it [L]og",
		},
		{
			"<leader>sGL",
			function()
				Snacks.picker.git_log_line()
			end,
			desc = "[S]earch [G]it [L]og Line",
		},
		{
			"<leader>sGs",
			function()
				Snacks.picker.git_status()
			end,
			desc = "[S]earch [G]it [S]tatus",
		},
		{
			"<leader>sGS",
			function()
				Snacks.picker.git_stash()
			end,
			desc = "[S]earch [G]it [S]tash",
		},
		{
			"<leader>sGd",
			function()
				Snacks.picker.git_diff()
			end,
			desc = "[S]earch [G]it [D]iff Hunks",
		},
		{
			"<leader>sGf",
			function()
				Snacks.picker.git_log_file()
			end,
			desc = "[S]earch [G]it Log [F]ile",
		},
		{
			"<leader>sGi",
			function()
				Snacks.picker.gh_issue()
			end,
			desc = "[S]earch [G]itHub [I]ssues",
		},
		{
			"<leader>sGI",
			function()
				Snacks.picker.gh_issue({ state = "all" })
			end,
			desc = "[S]earch [G]itHub All [I]ssues",
		},
		{
			"<leader>sGp",
			function()
				Snacks.picker.gh_pr()
			end,
			desc = "[S]earch [G]itHub [P]Rs",
		},
		{
			"<leader>sSP",
			function()
				Snacks.picker.gh_pr({ state = "all" })
			end,
			desc = "[S]earch [G]itHub All [P]Rs",
		},
		{
			"<leader>SGg",
			function()
				Snacks.lazygit.open()
			end,
			desc = "[S]nacks Lazy[G]it",
		},
		{
			"<leader>SGG",
			function()
				Snacks.lazygit.log()
			end,
			desc = "[S]nacks Lazy[G]it Log",
		},
		{
			"<leader>SGB",
			function()
				Snacks.gitbrowse()
			end,
			desc = "[S]nacks [G]it [B]rowse",
			mode = { "n", "v" },
		},
		{
			"<leader>ds",
			function()
				Snacks.picker.lsp_symbols()
			end,
			desc = "[S]nacks LSP [S]ymbols",
		},
		{
			"<leader>ws",
			function()
				Snacks.picker.lsp_workspace_symbols()
			end,
			desc = "[S]nacks LSP Workspace [S]ymbols",
		},
		{
			"gd",
			function()
				Snacks.picker.lsp_definitions()
			end,
			desc = "Snacks [G]o to [D]efinitions",
		},
		{
			"gD",
			function()
				Snacks.picker.lsp_declarations()
			end,
			desc = "Snacks [G]o to [D]eclarations",
		},
		{
			"gr",
			function()
				Snacks.picker.lsp_references()
			end,
			desc = "Snacks [G]o to [R]eferences",
		},
		{
			"gI",
			function()
				Snacks.picker.lsp_implementations()
			end,
			desc = "Snacks [G]o to [I]mplementations",
		},
		{
			"gs",
			function()
				Snacks.picker.lsp_type_definitions()
			end,
			desc = "Snacks [G]o to [T]ype Definitions",
		},
		{
			"gi",
			function()
				Snacks.picker.lsp_incoming_calls()
			end,
			desc = "Snacks [G]o to [I]ncoming Calls",
		},
		{
			"go",
			function()
				Snacks.picker.lsp_outgoing_calls()
			end,
			desc = "Snacks [G]o to [O]utgoing Calls",
		},
		{
			"<leader>Sz",
			function()
				Snacks.zen()
			end,
			desc = "[S]nacks [Z]en Mode",
		},
		{
			"<leader>SZ",
			function()
				Snacks.zen.zoom()
			end,
			desc = "[S]nacks [Z]en Zoom Mode",
		},
		{
			"<leader>S.",
			function()
				Snacks.scratch()
			end,
			desc = "[S]nacks Scratch Buffer",
		},
		{
			"<leader>St",
			function()
				Snacks.scratch.select()
			end,
			desc = "[S]nacks Scratch Lis[t]",
		},
		{
			"<leader>Sn",
			function()
				Snacks.notifier.show_history()
			end,
			desc = "[S]nacks [N]otification History",
		},
		{
			"<leader>SN",
			function()
				Snacks.notifier.hide()
			end,
			desc = "[S]nacks Dismiss [N]otifications",
		},
		{
			"<leader>SX",
			function()
				Snacks.bufdelete()
			end,
			desc = "[S]nacks [B]uffer [D]elete",
		},
		{
			"<leader>SY",
			function()
				Snacks.rename.rename_file()
			end,
			desc = "[S]nacks [R]e[N]ame File",
		},
		{
			"<leader>S`",
			function()
				Snacks.terminal()
			end,
			desc = "[S]nacks Terminal",
		},
		{
			"<leader>S]",
			function()
				Snacks.words.jump(vim.v.count1)
			end,
			desc = "[S]nacks Next Reference",
			mode = { "n", "t" },
		},
		{
			"<leader>S[",
			function()
				Snacks.words.jump(-vim.v.count1)
			end,
			desc = "[S]nacks Previous Reference",
			mode = { "n", "t" },
		},
	},
}
