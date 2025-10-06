" Vim filetype detection file
" Language: Quest
" Maintainer: Quest Language Team

" Detect .q files as Quest
autocmd BufRead,BufNewFile *.q set filetype=quest

" Enable syntax highlighting for Quest files
autocmd FileType quest setlocal syntax=quest

" Set comment string for commenting plugins
autocmd FileType quest setlocal commentstring=#\ %s

" Set indentation (2 spaces is common for Quest)
autocmd FileType quest setlocal shiftwidth=4 tabstop=4 expandtab

" Match end keywords for indentation
autocmd FileType quest setlocal indentkeys+=0=end,0=elif,0=else,0=catch,0=ensure
