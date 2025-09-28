{ pkgs, ... }:

{
  programs.vim = {
    enable = true;
    defaultEditor = true;
    package = (pkgs.vim_configurable.override { }).customize {
      name = "vim";
      vimrcConfig.packages.myplugins = with pkgs.vimPlugins; {
        start = [
          vim-nix
          vim-lastplace
        ];
        opt = [ ];
      };
      vimrcConfig.customRC = ''
        " 不兼容模式
        set nocompatible
        " 行号与缩进
        set number
        set expandtab
        set tabstop=4
        set shiftwidth=4
        set softtabstop=4
        set autoindent
        " 鼠标功能
        set mouse=a
        " 搜索高亮/忽略大小写
        set hlsearch
        set incsearch
        set ignorecase
        " 高亮
        syntax on
        filetype on
        set cursorline
        set cursorcolumn
        " 文件改动时自动载入
        set autoread
        " 共享剪贴板
        set clipboard=unnamed
        " 退格键删除任意值
        set backspace=indent,eol,start
        " 状态栏
        set statusline=%f\ %h%m%r%=\ %y\ [%{&fileformat}]\ [%{&encoding}]\ \ %-8.(%l,%c%)\ %P
        set laststatus=2
        " 编码
        set fileencodings=ucs-bom,utf-8,cp936,gb18030,big5,euc-jp,euc-kr,latin1
      '';
    };
  };
}
