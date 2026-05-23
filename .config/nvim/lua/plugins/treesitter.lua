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
    local parsers = {
      "lua",
      "python",
      "typescript",
      "tsx",
      "vim",
      "dockerfile",
      "html",
      "css",
      "scss",
      "go",
      "gomod",
      "gosum",
      "gowork",
    }
    local filetypes = {
      "lua",
      "python",
      "typescript",
      "typescriptreact",
      "vim",
      "dockerfile",
      "html",
      "css",
      "scss",
      "go",
      "gomod",
      "gosum",
      "gowork",
    }

    require("nvim-treesitter").setup({
      install_dir = vim.fn.stdpath("data") .. "/site",
    })

    require("nvim-treesitter").install(parsers)

    vim.api.nvim_create_autocmd("FileType", {
      pattern = filetypes,
      callback = function(args)
        pcall(vim.treesitter.start, args.buf)

        if vim.bo[args.buf].filetype ~= "python" then
          vim.bo[args.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
        end
      end,
    })
  end,
}
