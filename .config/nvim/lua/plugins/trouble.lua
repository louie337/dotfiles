return {
  "folke/trouble.nvim",
  dependencies = { "nvim-tree/nvim-web-devicons" },
  cmd = "Trouble",
  keys = {
    {
      "<leader>xX",
      "<cmd>Trouble diagnostics toggle<cr>",
      desc = "Trouble Diagnostics (Global)",
    },
    {
      "<leader>xx",
      "<cmd>Trouble diagnostics toggle filter.buf=0<cr>",
      desc = "Trouble Diagnostics (Current Buffer)",
    },
    {
      "<leader>xs",
      "<cmd>Trouble symbols toggle<cr>",
      desc = "Trouble [S]ymbols",
    },
    {
      "<leader>xL",
      "<cmd>Trouble lsp toggle<cr>",
      desc = "Trouble [L]SP",
    },
    {
      "<leader>xl",
      "<cmd>Trouble loclist toggle<cr>",
      desc = "Trouble [L]ocation List)",
    },
    {
      "<leader>xq",
      "<cmd>Trouble qflist toggle<cr>",
      desc = "Trouble [Q]uickfix List",
    },
  },
  config = true,
}
