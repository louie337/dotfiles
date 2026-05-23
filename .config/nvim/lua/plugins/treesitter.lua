return {
  -- Highlight, edit, and navigate code
  "nvim-treesitter/nvim-treesitter",
  branch = "main",
  lazy = false,
  dependencies = {
    {
      "windwp/nvim-ts-autotag",
      opts = {},
    },
  },
  build = function()
    if vim.fn.executable("tree-sitter") == 1 then
      vim.cmd("TSUpdate")
    end
  end,
  config = function()
    require("nvim-treesitter").setup({
      install_dir = vim.fn.stdpath("data") .. "/site",
    })

    vim.api.nvim_create_autocmd("FileType", {
      pattern = "*",
      callback = function(args)
        local has_parser = pcall(vim.treesitter.start, args.buf)

        if has_parser and vim.bo[args.buf].filetype ~= "python" then
          vim.bo[args.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
        end
      end,
    })
  end,
}
