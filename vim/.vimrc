augroup VimDiffColors
    autocmd!
    autocmd ColorScheme,VimEnter * hi DiffAdd    cterm=NONE ctermbg=NONE ctermfg=Green  gui=NONE guibg=NONE guifg=#7CFC00
    autocmd ColorScheme,VimEnter * hi DiffChange cterm=NONE ctermbg=NONE ctermfg=Yellow gui=NONE guibg=NONE guifg=#FFD75F
    autocmd ColorScheme,VimEnter * hi DiffDelete cterm=NONE ctermbg=NONE ctermfg=Red    gui=NONE guibg=NONE guifg=#FF5F5F
    autocmd ColorScheme,VimEnter * hi DiffText   cterm=bold ctermbg=NONE ctermfg=Cyan   gui=bold guibg=NONE guifg=#5FD7FF
augroup END

cnoreabbrev <expr> q ((getcmdtype()==':' && getcmdline()=='q' && &diff && tabpagenr('$')==1 && winnr('$')==2) ? 'qa' : 'q')
