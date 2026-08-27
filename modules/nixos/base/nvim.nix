{
  flake,
  pkgs,
  lib,
  ...
}:

{
  imports = [
    flake.inputs.nixvim.nixosModules.nixvim
  ];

  programs.nixvim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;

    plugins = {
      lualine.enable = true;
      trouble.enable = true;
      lazygit.enable = true;
      bufferline.enable = true;
      nvim-autopairs.enable = true;
    };
    colorschemes.catppuccin.enable = true;
    plugins.gitsigns = {
      enable = true;
      settings = {
        current_line_blame = true;
        trouble = true;
      };
    };
    plugins.lsp = {
      enable = true;
      servers.nixd.enable = true;
    };
    # LSP 通知
    plugins.fidget = {
      enable = true;
      settings.progress = {
        suppress_on_insert = true;
        ignore_done_already = true;
        poll_rate = 1;
      };
    };
    # 代码提示
    plugins = {
      luasnip.enable = true;
      cmp = {
        enable = true;
        autoEnableSources = true;
        settings = {
          sources = [
            { name = "nvim_lsp"; } # 来自 LSP 的补全
            { name = "path"; } # 文件路径补全
            { name = "buffer"; } # 当前打开 buffer 里的文本补全
            { name = "luasnip"; } # 代码片段 (snippet) 补全
          ];
          mapping = {
            "<S-Tab>" = "cmp.mapping.complete()"; # 手动触发补全
            "<C-e>" = "cmp.mapping.abort()"; # 取消补全
            "<Down>" = "cmp.mapping.select_next_item()"; # 向下选择候选
            "<C-j>" = "cmp.mapping.select_next_item()";
            "<Up>" = "cmp.mapping.select_prev_item()"; # 向上选择候选
            "<C-k>" = "cmp.mapping.select_prev_item()";
            "<Tab>" = "cmp.mapping.confirm({ select = true })"; # 确认选择
            "<CR>" = "cmp.mapping.confirm({ select = true })";
          };
        };
      };
    };
    # 代码诊断与格式化
    plugins.none-ls = {
      enable = true;
      sources = {
        diagnostics = {
          statix.enable = true;
        };
        formatting = {
          nixfmt.enable = true;
          shellharden.enable = true;
          shfmt.enable = true;
        };
      };
    };
    # 语法高亮和缩进
    plugins.treesitter = {
      enable = true;
      nixGrammars = true;
      indent.enable = true;
      highlight.enable = true;
      grammarPackages = with pkgs.vimPlugins.nvim-treesitter.builtGrammars; [
        html
        css
        javascript
        typescript
        json
        yaml
        markdown
        markdown_inline
        lua
        vim
        vimdoc
        bash
        dockerfile
        gitignore
        regex
        toml
        xml
        nix
      ];
    };
    # 终端
    plugins.toggleterm = {
      enable = true;
      settings = {
        open_mapping = "[[<C-t>]]";
      };
    };
    # 资源管理器
    plugins.nvim-tree = {
      enable = true;
      openOnSetupFile = true;
      settings.auto_reload_on_write = true;
    };
    # 模糊查找
    plugins.telescope = {
      enable = true;
      keymaps = {
        "<leader>fg" = "live_grep";
        "<C-p>" = {
          action = "git_files";
          options = {
            desc = "Telescope Git Files";
          };
        };
      };
      extensions.fzf-native = {
        enable = true;
      };
    };
    # 缩进
    plugins.indent-blankline = {
      enable = true;
      settings = {
        indent = {
          smart_indent_cap = true;
          char = " ";
        };
        scope = {
          enabled = true;
          char = "│";
        };
      };
    };
    # 命令行增强
    plugins.wilder = {
      enable = true;
      settings.modes = [
        ":"
        "/"
        "?"
      ];
    };

    opts = {
      updatetime = 100; # Faster completion

      number = true;
      relativenumber = true;
      splitbelow = true;
      splitright = true;
      scrolloff = 4;

      autoindent = true;
      clipboard = "unnamedplus";
      expandtab = true;
      shiftwidth = 2;
      smartindent = true;
      tabstop = 2;

      ignorecase = true;
      incsearch = true;
      smartcase = true;
      wildmode = "list:longest";

      swapfile = false;
      undofile = true; # Build-in persistent undo

      termguicolors = lib.mkForce pkgs.stdenv.isLinux;
    };
  };
}
