{ flake, ... }:

{
  programs.firefox = {
    enable = true;
    languagePacks = [ "zh-CN" ];
    profiles.default = {
      search = {
        force = true;
        default = "bing";
      };
      # Smoothfox 是 betterfox 的可选平滑滚动脚本，须拼接在 user.js 之后才生效
      preConfig =
        builtins.readFile "${flake.inputs.betterfox}/user.js"
        + "\n"
        + builtins.readFile "${flake.inputs.betterfox}/Smoothfox.js";
      settings = {
        "sidebar.revamp" = true; # 侧栏
        "sidebar.verticalTabs" = true; # 垂直标签页
        "sidebar.visibility" = "expand-on-hover"; # 悬停时展开侧栏
        "dom.security.https_only_mode" = false; # 允许 http
        "browser.contentblocking.category" = "standard"; # 关闭严格模式
      };
    };
    policies = {
      SkipTermsOfUse = true; # 跳过使用条款
      NoDefaultBookmarks = true; # 禁用默认书签
      PromptForDownloadLocation = true; # 下载前询问文件保存位置
      DisplayBookmarksToolbar = "newtab"; # 在新标签页显示书签工具栏
      PostQuantumKeyAgreementEnabled = true; # 启用适用于 TLS 的后量子密钥协议
      RequestedLocales = [ "zh_CN" ];
      ExtensionSettings = {
        "uBlock0@raymondhill.net" = {
          installation_mode = "normal_installed";
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/latest.xpi";
        };
        # 沉浸式翻译
        "{5efceaa7-f3a2-4e59-a54b-85319448e305}" = {
          installation_mode = "normal_installed";
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/immersive-translate/latest.xpi";
        };
      };
    };
  };

  xdg.mimeApps.defaultApplications = {
    "text/html" = [ "firefox.desktop" ];
    "text/xml" = [ "firefox.desktop" ];
    "x-scheme-handler/http" = [ "firefox.desktop" ];
    "x-scheme-handler/https" = [ "firefox.desktop" ];
  };
}
