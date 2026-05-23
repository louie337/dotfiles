-- NOTE: Add git status into buffers
local icons = require("options.icons")

return {
  "lewis6991/gitsigns.nvim",
  opts = {
    signs = {
      add = { text = icons.git.added },
      change = { text = icons.git.modified },
      delete = { text = icons.git.removed },
      topdelete = { text = icons.git.remove },
      changedelete = { text = icons.git.remove },
    },
    current_line_blame = true,
  },
}
