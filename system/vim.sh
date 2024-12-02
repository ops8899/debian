#!/bin/bash

# 设置Vim在debian 12编辑模式下正常使用鼠标、快捷键复制等功能
sed -i "s/set mouse=a/set mouse-=a/g" /usr/share/vim/vim*/defaults.vim
cat /usr/share/vim/vim*/defaults.vim | grep mouse-=a

# 创建并写入配置
cat > ~/.vimrc << 'EOF'
"==========================================
" 基础设置
"==========================================
set nocompatible                " 关闭 vi 兼容模式
set number                      " 显示行号
syntax on                       " 语法高亮
set mouse=a                     " 启用鼠标
set encoding=utf-8              " 编码设置
set fileencodings=utf-8,ucs-bom,gb18030,gbk,gb2312,cp936
set termencoding=utf-8

"==========================================
" 界面显示
"==========================================
set ruler                       " 显示光标当前位置
set cursorline                  " 高亮显示当前行
set showmatch                   " 高亮显示匹配的括号
set hlsearch                    " 高亮显示搜索结果
set incsearch                   " 实时搜索
set ignorecase                  " 搜索时忽略大小写
set smartcase                   " 搜索时如果包含大写则对大小写敏感
set laststatus=2               " 永远显示状态栏
set showcmd                     " 显示输入的命令
set scrolloff=5                " 距离顶部和底部5行
set sidescrolloff=15           " 距离左右15列

"==========================================
" 编辑和缩进
"==========================================
set autoindent                  " 自动缩进
set smartindent                 " 智能缩进
set tabstop=4                   " Tab键的宽度
set softtabstop=4              " 统一缩进为4
set shiftwidth=4               " 自动缩进长度
set expandtab                   " 用空格代替制表符
set smarttab                    " 在行和段开始处使用制表符

"==========================================
" 文件类型
"==========================================
filetype on                     " 开启文件类型检测
filetype indent on              " 针对不同的文件类型采用不同的缩进格式
filetype plugin on              " 针对不同的文件类型加载对应的插件
filetype plugin indent on       " 启用自动补全

"==========================================
" 实用功能
"==========================================
set paste                       " 粘贴模式
set backspace=indent,eol,start  " 退格键可用
set nowrap                      " 禁止折行
set history=1000               " 历史记录数
set autoread                    " 文件在Vim之外修改过，自动重新读入
set wildmenu                    " 命令模式下的补全菜单
set nobackup                    " 不创建备份文件
set noswapfile                 " 不创建交换文件

"==========================================
" 编码和格式
"==========================================
set fileformat=unix            " 文件格式
set fileformats=unix,dos,mac   " 文件格式检测

"==========================================
" 颜色主题
"==========================================
set background=dark            " 深色背景
set t_Co=256                   " 启用256色

"==========================================
" 自定义快捷键
"==========================================
" 空格作为leader键
let mapleader=" "
" 快速保存
nmap <leader>w :w<CR>
" 快速退出
nmap <leader>q :q<CR>
" 取消搜索高亮
nmap <leader>h :nohl<CR>

"==========================================
" 状态栏设置
"==========================================
set statusline=%F%m%r%h%w\ [FORMAT=%{&ff}]\ [TYPE=%Y]\ [POS=%l,%v][%p%%]\ %{strftime(\"%d/%m/%y\ -\ %H:%M\")}

"==========================================
" 其他设置
"==========================================
set updatetime=300             " 更新时间
set timeoutlen=500            " 键盘快捷键连击时间
EOF
