vim.g.mapleader = " "
vim.keymap.set("n", "<leader>pv", vim.cmd.Ex)

vim.keymap.set("v", "J", ":m '>+1<CR>gv=gv")
vim.keymap.set("v", "K", ":m '<-2<CR>gv=gv")

vim.keymap.set("n", "J", "mzJ`z")
vim.keymap.set("n", "<C-d>", "<C-d>zz")
vim.keymap.set("n", "<C-u>", "<C-u>zz")
vim.keymap.set("n", "n", "nzzzv")
vim.keymap.set("n", "N", "Nzzzv")

vim.keymap.set("n", "<leader>vwm", function()
    require("vim-with-me").StartVimWithMe()
end)
vim.keymap.set("n", "<leader>svwm", function()
    require("vim-with-me").StopVimWithMe()
end)

-- greatest remap ever
vim.keymap.set("x", "<leader>p", [["_dP]])

-- next greatest remap ever : asbjornHaland
vim.keymap.set({"n", "v"}, "<leader>y", [["+y]])
vim.keymap.set("n", "<leader>Y", [["+Y]])

vim.keymap.set({"n", "v"}, "<leader>d", [["_d]])

-- This is going to get me cancelled
vim.keymap.set("i", "<C-c>", "<Esc>")

vim.keymap.set("n", "Q", "<nop>")
vim.keymap.set("n", "<C-f>", "<cmd>silent !tmux neww tmux-sessionizer<CR>")
vim.keymap.set("n", "<leader>f", vim.lsp.buf.format)
vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename)

vim.keymap.set("n", "<C-k>", "<cmd>cnext<CR>zz")
vim.keymap.set("n", "<C-j>", "<cmd>cprev<CR>zz")
vim.keymap.set("n", "<leader>k", "<cmd>lnext<CR>zz")
vim.keymap.set("n", "<leader>j", "<cmd>lprev<CR>zz")

vim.keymap.set("n", "<leader>s", [[:%s/\<<C-r><C-w>\>/<C-r><C-w>/gI<Left><Left><Left>]])
vim.keymap.set("n", "<leader>x", "<cmd>!chmod +x %<CR>", { silent = true })

vim.keymap.set("n", "<leader><leader>", function()
    vim.cmd("so")
end)

-- buffers
--vim.api.nvim_set_keymap("n", "tk", ":blast<enter>", {noremap=false})
--vim.api.nvim_set_keymap("n", "tj", ":bfirst<enter>", {noremap=false})
vim.api.nvim_set_keymap("n", "bp", ":bprev<enter>", {noremap=false})
vim.api.nvim_set_keymap("n", "bn", ":bnext<enter>", {noremap=false})
vim.api.nvim_set_keymap("n", "bd", ":bdelete<enter>", {noremap=false})

-- vim test
vim.keymap.set("n", "<leader>tn", ":TestNearest<CR>")
vim.keymap.set("n", "<leader>tf", ":TestFile<CR>") 
vim.keymap.set("n", "<leader>ts", ":TestSuite<CR>") 
vim.keymap.set("n", "<leader>tl", ":TestLast<CR>") 
vim.keymap.set("n", "<leader>tv", ":TestVisit<CR>") 

-- yank to clipboard
vim.keymap.set({ "n", "v" }, "<leader>y", [["+y]])

--format code using LSP
vim.keymap.set("n", "<leader>fmd", vim.lsp.buf.format)

-- markdown preview
vim.keymap.set("n", "<leader>mp", ":MarkdownPreview<CR>")

-- copy file path
vim.keymap.set("n", "<leader>cp", ":let @\" = expand(\"%:p\")<CR>")
