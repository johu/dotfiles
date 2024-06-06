return {
  {
    "catppuccin/nvim",
    name = "catppuccin",
    priority = 1000,
    config = function()
      require("catppuccin").setup({
        flavour = "mocha",
        transparent_background = true,
        integrations = {
          alpha = true,
          cmp = true,
          dap = true,
          dap_ui = true,
          indent_blankline = true,
          mason = true,
          notify = true,
          telescope = true,
          treesitter = true,
          which_key = true,
        },
      })

      vim.cmd.colorscheme("catppuccin")
    end,
  },
  {
    "rachartier/tiny-devicons-auto-colors.nvim",
    dependencies = {
      "nvim-tree/nvim-web-devicons",
    },
    event = "VeryLazy",
    config = function()
      local theme_colors = require("catppuccin.palettes").get_palette("macchiato")
      require("tiny-devicons-auto-colors").setup({
        colors = theme_colors,
      })
    end,
  },
}
