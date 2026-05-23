return {
  "numToStr/Comment.nvim",
  dependencies = {
    "JoosepAlviste/nvim-ts-context-commentstring",
  },
  config = function()
    require("Comment").setup({
      pre_hook = require("ts_context_commentstring.integrations.comment_nvim").create_pre_hook(),
      -- Lines to be ignored while (un)comment
      ignore = "^$", -- This will ignore empty lines
      -- Whether the cursor should stay at its position
      sticky = true,
    })
  end,
}
