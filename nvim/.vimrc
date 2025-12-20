" http://dougblack.io/words/a-good-vimrc.html
syntax enable           " enable syntax processing
set tabstop=4       " number of visual spaces per TAB
set softtabstop=4   " number of spaces in tab when editing
set shiftwidth=4   
set smarttab 
set expandtab       " tabs are spaces
set number              " show line numbers
set cursorline          " highlight current line
filetype indent on      " load filetype-specific indent files
set wildmenu            " visual autocomplete for command menu

"set lazyredraw          " redraw only when we need to.
set showmatch           " highlight matching [{()}]
set incsearch           " search as characters are entered
set hlsearch            " highlight matches
let mapleader=","       " leader is comma

set ignorecase 


" macros
nnoremap t :wa <bar> :!make test <CR>
"<bar> separates two commands
"<CR> is the carriage return

" Add date in normal mode
:nnoremap <F5> "=strftime("%Y-%m-%d %H:%M:%S AGB")<CR>P
" Add date in insert mode
:inoremap <F5> <C-R>=strftime("%Y-%m-%d %H:%M:%S AGB")<CR>

" jump to the last position when reopening a file
if has("autocmd")
      au BufReadPost * if line("'\"") > 1 && line("'\"") <= line("$") | exe "normal! g'\"" | endif
endif
