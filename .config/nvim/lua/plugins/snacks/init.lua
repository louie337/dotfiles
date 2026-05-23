local dashboard = require("plugins.snacks.dashboard")

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
    picker = { enabled = true },
    notifier = { enabled = false },
    quickfile = { enabled = true },
    scope = { enabled = true },
    statuscolumn = { enabled = false },
    words = { enabled = true },
    lazygit = { enabled = true },
  },
  keys = {
    { "<leader>e", function() Snacks.explorer() end, desc = "[E]xplore Snacks Explorer" },
    { "<leader>E", function() Snacks.explorer.reveal() end, desc = "[E]xplore Current File" },
  },
}
