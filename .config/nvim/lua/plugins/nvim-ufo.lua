-- return { 'kevinhwang91/nvim-ufo', dependencies = { 'kevinhwang91/promise-async' }, opts = {}, config = true }
return {
  "kevinhwang91/nvim-ufo",
  dependencies = {
    "kevinhwang91/promise-async", -- NOTE: Requirement
    {
      "luukvbaal/statuscol.nvim",
      config = function()
        local builtin = require("statuscol.builtin")
        require("statuscol").setup({
          relculright = true,
          segments = {
            { text = { builtin.foldfunc, " " }, click = "v:lua.ScFa" }, -- NOTE: The space is to give extra space after the folding icon.
            { text = { "%s" },                  click = "v:lua.ScSa" },
            { text = { builtin.lnumfunc, " " },      click = "v:lua.ScLa" },
          },
        })
      end,
    },
  },
  event = "BufReadPost",
  opts = {
    provider_selector = function()
      return { "treesitter", "indent" }
    end,
  },
  config = function()
    vim.o.foldcolumn = "1" -- '0' is not bad
    vim.o.foldlevel = 99 -- Using ufo provider need a large value, feel free to decrease the value
    vim.o.foldlevelstart = 99
    vim.o.foldenable = true

    vim.o.fillchars = [[eob: ,fold: ,foldopen:,foldsep: ,foldclose:]]
    -- Using ufo provider need remap `zR` and `zM`. If Neovim is 0.6.1, remap yourself
    vim.keymap.set("n", "zR", require("ufo").openAllFolds)
    vim.keymap.set("n", "zM", require("ufo").closeAllFolds)
    require("ufo").setup({})
  end,
}
