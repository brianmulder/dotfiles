" The plan: neovim tutorial, notes, zettlekasten in vim, anki cards
" https://danielmiessler.com/study/vim/
" Remove the need to hit the escape key to change modes
inoremap jk <ESC>
let mapleader = "'" " leader key close to the l key

" In the operating system - map CAPS LOCK to Ctrl

" A "solid start"
syntax on      " highlight syntax
set number     " show line numbers
set noswapfile " disable the swapfile
set hlsearch   " highlight all results
set ignorecase " ignore case in search
set incsearch  " show search results as you type

" Tabbing
set tabstop      =2
set softtabstop  =2
set shiftwidth   =2
set expandtab

" An example key mapping with the <leader>
" not a particularly usefull example mind you
" nnoremap <leader>bn :bn<cr>
" `cd` to the current open file
nnoremap <leader>cd :cd %:p:h<cr>:pwd<cr>
nnoremap <leader>ni :e $NOTES_DIR/index.md<cr>:cd $NOTES_DIR<cr>
nnoremap <leader>nj :e $JOURNAL_DIR/journal.md<cr>:cd $JOURNAL_DIR<cr>

" Ensure backspace *just* works
" https://vi.stackexchange.com/questions/2162/why-doesnt-the-backspace-key-work-in-insert-mode
set backspace=indent,eol,start

" cheetsheet
" d: delete
" c: change
" y: yank
" v: select (V for line vs. character)
" t: "to" searches for something and stops before it :: verb
" ): sentance  :: noun
" p: paragraph :: noun
" }: paragraph :: noun
" I: Cursor to start of line and mode to insert.

" quiz:
" ct< : *C*hange *T*o *<* (open bracket)

" ?: backward search (as apposed to /)
" *: find the word under your cursor 
" ;: ';' will find the next occurance in conjunction with f or t

