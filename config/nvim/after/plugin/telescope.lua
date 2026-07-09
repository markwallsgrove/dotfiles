local builtin = require('telescope.builtin')
local telescope = require('telescope')

-- find project file
vim.keymap.set('n', '<leader>pf', builtin.find_files, {})

vim.keymap.set('n', '<leader>vb', builtin.buffers, {})

-- find files that are controlled with git
vim.keymap.set('n', '<C-p>', builtin.git_files, {})

-- grep through the project files
vim.keymap.set('n', '<leader>ps', function()
	builtin.grep_string({ search = vim.fn.input("Grep > ") })
end)

vim.keymap.set('n', '<leader>ds', builtin.lsp_document_symbols, {})

telescope.setup({                                                                                                                                                             
  defaults = {                                                                                                                                                                  
    mappings = {                                                                                                                                                                  
      i = {                                                                                                                                                                         
        ['<C-p>'] = require('telescope.actions.layout').toggle_preview                                                                                                            
      }                                                                                                                                                                         
    },
    preview = {                                                                                                                                                                          
      hide_on_startup = true -- hide previewer when picker starts
    }                                                                                                               
  }
})
