local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local lazyrepo = "https://github.com/folke/lazy.nvim.git"
  local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({
      { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
      { out, "WarningMsg" },
      { "\nPress any key to exit..." },
    }, true, {})
    vim.fn.getchar()
    os.exit(1)
  end
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
  spec = {
    {
      "nvim-telescope/telescope.nvim",
      tag = "0.1.5",
      dependencies = { "nvim-lua/plenary.nvim" },
    },

    {
      "rose-pine/neovim",
      name = "rose-pine",
      config = function()
        vim.cmd("colorscheme rose-pine")
      end,
    },

    {
      "nvim-treesitter/nvim-treesitter",
      build = ":TSUpdate",
    },

    "theprimeagen/harpoon",
    "mbbill/undotree",
    "tpope/vim-fugitive",

    {
      "VonHeikemen/lsp-zero.nvim",
      branch = "v3.x",
      dependencies = {
        -- Uncomment the two plugins below if you want to manage the language servers from neovim
        "williamboman/mason.nvim",
        "williamboman/mason-lspconfig.nvim",

        -- LSP Support
        "neovim/nvim-lspconfig",
        -- Autocompletion
        "hrsh7th/nvim-cmp",
        "hrsh7th/cmp-nvim-lsp",
        "L3MON4D3/LuaSnip",
      },
    },

    {
      "nvim-lualine/lualine.nvim",
      dependencies = { "nvim-tree/nvim-web-devicons" },
    },

    {
      "folke/noice.nvim",
      dependencies = {
        "MunifTanjim/nui.nvim",
        "rcarriga/nvim-notify",
      },
    },

    "github/copilot.vim",

    {
      "vim-test/vim-test",
      dependencies = { "preservim/vimux" },
    },

    "terrortylor/nvim-comment",

    {
      "iamcco/markdown-preview.nvim",
      build = "cd app && npm install",
      init = function() vim.g.mkdp_filetypes = { "markdown" } end,
      ft = { "markdown" },
    },
  },
})
