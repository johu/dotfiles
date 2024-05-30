return {
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
        telescope = true,
        treesitter = true,
        which_key = true,
      },
    })

    vim.cmd.colorscheme("catppuccin")
  end,
}
