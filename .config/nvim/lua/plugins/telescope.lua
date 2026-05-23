return {
  "nvim-telescope/telescope.nvim",
  version = "0.1.4",
  dependencies = {
    "nvim-lua/plenary.nvim",
    {
      "nvim-telescope/telescope-fzf-native.nvim",
      -- NOTE: If you are having trouble with this installation,
      --       refer to the README for telescope-fzf-native for more instructions.
      build = "make",
      cond = function()
        return vim.fn.executable("make") == 1
      end,
      config = function()
        -- Enable telescope fzf native, if installed
        pcall(require("telescope").load_extension, "fzf")
      end,
    },
  },
  config = function()
    require("telescope").setup({
      defaults = {
        mappings = {
          i = {
            ["<C-u>"] = false,
            ["<C-d>"] = false,
          },
        },
        -- NOTES: Default ignore patterns without .gitignore
        file_ignore_patterns = {
          ".node_modules/",
          ".git/",
          ".next/",
          ".lock",
        },
      },
    })
    -- NOTE: Keymap settings
    local builtin = require("telescope.builtin")
    local utils = require("telescope.utils")
    local actions = require("telescope.actions")
    local action_state = require("telescope.actions.state")
    -- See `:help telescope.builtin`
    vim.keymap.set("n", "<leader>?", builtin.oldfiles, { desc = "[?] Find recently opened files" })
    vim.keymap.set(
      "n",
      "<leader>/",
      builtin.current_buffer_fuzzy_find,
      { desc = "[/] Fuzzily search in current buffer" }
    )
    vim.keymap.set("n", "<leader>sf", builtin.find_files, { desc = "[S]earch [F]iles" })
    vim.keymap.set(
      "n",
      "<leader>sh",
      "<CMD>Telescope find_files hidden=true<CR>",
      { desc = "[S]earch [H]idden files" }
    )
    vim.keymap.set(
      "n",
      "<leader>sH",
      "<CMD>Telescope find_files hidden=true no_ignore=true<CR>",
      { desc = "[S]earch [H]idden & gitignored files" }
    )
    vim.keymap.set("n", "<leader>sv", builtin.help_tags, { desc = "[S]earch [V]im help tags" })
    vim.keymap.set("n", "<leader>sw", builtin.grep_string, { desc = "[S]earch current [W]ord" })
    vim.keymap.set(
      "n",
      "<leader>sG",
      "<CMD>Telescope grep_string search=<CR>",
      { desc = "[S]earch by [G]rep (Fuzzy)" }
    )
    vim.keymap.set("n", "<leader>sg", builtin.live_grep, { desc = "[S]earch by [G]rep" })
    vim.keymap.set("n", "<leader>sd", function()
      builtin.diagnostics({ initial_mode = "normal" })
    end, { desc = "[S]earch [D]iagnostics" })
    vim.keymap.set("n", "<leader>ss", function()
      builtin.spell_suggest({ initial_mode = "normal" })
    end, { desc = "[S]earch [S]pell Suggestions" })
    vim.keymap.set("n", "<leader>sj", builtin.jumplist, { desc = "[S]earch [J]ump list" })
    vim.keymap.set("n", "<leader>sJ", function()
      builtin.jumplist({ initial_mode = "normal", default_text = vim.fn.getcwd() })
    end, { desc = "[S]earch [J]ump list in current directory" })
    vim.keymap.set("n", "<leader>st", builtin.tagstack, { desc = "[S]earch [T]agstack" })

    local buffer_searcher
    buffer_searcher = function()
      builtin.buffers({
        sort_mru = true,
        attach_mappings = function(prompt_bufnr, map)
          local refresh_buffer_searcher = function()
            actions.close(prompt_bufnr)
            vim.schedule(buffer_searcher)
          end
          local delete_buf = function()
            local selection = action_state.get_selected_entry()
            vim.api.nvim_buf_delete(selection.bufnr, { force = true })
            refresh_buffer_searcher()
          end
          local delete_multiple_buf = function()
            local picker = action_state.get_current_picker(prompt_bufnr)
            local selection = picker:get_multi_selection()
            for _, entry in ipairs(selection) do
              vim.api.nvim_buf_delete(entry.bufnr, { force = true })
            end
            refresh_buffer_searcher()
          end
          map("n", "dd", delete_buf)
          map("n", "<C-d>", delete_multiple_buf)
          map("i", "<C-d>", delete_multiple_buf)
          return true
        end,
      })
    end
    vim.keymap.set("n", "<leader>sb", buffer_searcher, { desc = "[S]earch [B]uffers" })
    vim.keymap.set("n", "<leader>sm", builtin.marks, { desc = "[S]earch [M]arks" })
    vim.keymap.set("n", "<leader>sq", builtin.quickfix, { desc = "[S]earch [Q]uickfix" })
  end,
}
