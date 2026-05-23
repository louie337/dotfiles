return {
  'echasnovski/mini.indentscope',
  version = '*',
  event = { "BufReadPre", "BufNewFile" },
  lazy = true,
  opts = {
    -- symbol = "▏",
    symbol = "┊",
    options = { try_as_border = true },
  },
  init = function()
    vim.api.nvim_create_autocmd("FileType", {
      pattern = { "help", "alpha", "dashboard", "neo-tree", "Trouble", "lazy", "mason" },
      callback = function()
        vim.b.miniindentscope_disable = true
      end,
    })
  end,
}
