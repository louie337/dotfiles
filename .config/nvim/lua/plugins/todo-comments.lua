return {
  "folke/todo-comments.nvim",
  dependencies = "nvim-lua/plenary.nvim",
  lazy = false,
  cmd = { "TodoTrouble", "TodoTelescope" },
  event = { "BufReadPost", "BufNewFile" },
  opts = {
    keywords = {
      FIX = {
        icon = " ",
        color = "error",
        alt = { "IMPORTANT", "BUG" },
      },
      TODO = { icon = " ", color = "info" },
      WARN = { icon = " ", color = "warning", alt = { "WARNING", "XXX" } },
      PERF = { icon = " ", alt = { "COMMENT" } },
      NOTE = { icon = " ", color = "hint", alt = { "INFO" } },
      TEST = { icon = " ", color = "test", alt = { "QUESTION" } },
    },
    highlight = {
      multiline = false,
    },
  },
  keys = {
    { "<leader>sT", "<cmd>TodoTelescope<cr>", desc = "[S]earch [T]odo" },
  },
}
