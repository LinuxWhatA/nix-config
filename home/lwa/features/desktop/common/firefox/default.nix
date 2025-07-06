{
  programs.firefox = {
    enable = true;
    languagePacks = [ "zh-CN" ];
    profiles.lwa = {
      search = {
        force = true;
        default = "bing";
      };
      preConfig = builtins.readFile ./user.js;
      settings = {
        "sidebar.revamp" = true; # 侧栏
        "sidebar.verticalTabs" = true; # 垂直标签页
        "sidebar.visibility" = "expand-on-hover"; # 悬停时展开侧栏
        "browser.crashReports.unsubmittedCheck.autoSubmit2" = false; # 不发送积压的崩溃报告
      };
    };
    policies = {
      DisableTelemetry = true; # 关闭遥测
      SkipTermsOfUse = true; # 跳过使用条款
      NoDefaultBookmarks = true; # 禁用默认书签
      OverrideFirstRunPage = ""; # 禁用首次访问页面
      DisableFirefoxStudies = true; # 禁用 Firefox 研究
      DisablePocket = true; # 禁用保存网页到 Pocket 的功能
      DontCheckDefaultBrowser = true; # 禁用检查默认浏览器
      PromptForDownloadLocation = true; # 下载前询问文件保存位置
      EncryptedMediaExtensions.Enabled = true; # 启用加密媒体扩展
      DisplayBookmarksToolbar = "newtab"; # 在新标签页显示书签工具栏
      PostQuantumKeyAgreementEnabled = true; # 启用适用于 TLS 的后量子密钥协议
      RequestedLocales = [ "zh_CN" ];
      ExtensionSettings = {
        "adguardadblocker@adguard.com" = {
          # 广告拦截
          default_area = "navbar";
          installation_mode = "normal_installed";
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/adguard-adblocker/latest.xpi";
        };
        "{5efceaa7-f3a2-4e59-a54b-85319448e305}" = {
          # 沉浸式翻译
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
