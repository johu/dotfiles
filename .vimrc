"basic
syntax on
set number
set relativenumber
set ruler laststatus=2 number title hlsearch

"autoinstall vim-plug
if empty(glob('~/.vim/autoload/plug.vim'))
	silent !curl -fLo ~/.vim/autoload/plug.vim --create-dirs
	\ https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
	autocmd VimEnter * PlugInstall --sync | source $MYVIMRC
endif

"install plugins
call plug#begin('~/.vim/plugged')
	Plug 'tomasr/molokai'
call plug#end()

"colors
colorscheme molokai
let g:rehash256 = 1
set background=dark

highlight ColorColumn ctermbg=magenta
call matchadd('colorColumn','\%81v',100)

"unbind arrow keys
no <up> <Nop>
no <right> <Nop>
no <down> <Nop>
no <left> <Nop>
ino <up> <Nop>
ino <right> <Nop>
ino <down> <Nop>
ino <left> <Nop>
vno <up> <Nop>
vno <right> <Nop>
vno <down> <Nop>
vno <left> <Nop>

"use system clipboard by default
set clipboard=unnamedplus
