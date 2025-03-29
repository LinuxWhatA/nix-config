{
  programs.firefox = {
    enable = true;
    languagePacks = [ "zh-CN" ];
    profiles.lwa = {
      userChrome = builtins.readFile ./userChrome.css;
      search = {
        force = true;
        default = "bing";
      };
      settings = {
        # "sidebar.revamp" = true; # 侧栏
        # "sidebar.verticalTabs" = true; # 垂直标签页
        # "sidebar.main.tools" = "aichat,history"; # 侧栏工具
        "layout.css.has-selector.enabled" = true; # 启用 CSS 选择器
        "privacy.donottrackheader.enabled" = true; # 向网站发出“请勿跟踪”请求
        "browser.preferences.moreFromMozilla" = false; # 不显示更多 Firefox 产品
        "privacy.globalprivacycontrol.enabled" = true; # 要求网站不许出售或共享我的数据
        "browser.crashReports.unsubmittedCheck.autoSubmit2" = false; # 不发送积压的崩溃报告
        "toolkit.legacyUserProfileCustomizations.stylesheets" = true; # 启用自定义样式
        "browser.uiCustomization.state" = builtins.toJSON {
          # 自定义 UI
          placements = {
            unified-extensions-area = [
              "_3c078156-979c-498b-8990-85f7987dd929_-browser-action"
            ];
            nav-bar = [
              "firefox-view-button"
              # "sidebar-button"
              "back-button"
              "forward-button"
              "stop-reload-button"
              "urlbar-container"
              "save-to-pocket-button"
              "downloads-button"
              "fxa-toolbar-menu-button"
              "unified-extensions-button"
              "adguardadblocker_adguard_com-browser-action"
              "_5efceaa7-f3a2-4e59-a54b-85319448e305_-browser-action"
              "firefox_tampermonkey_net-browser-action"
            ];
            toolbar-menubar = [
              "menubar-items"
            ];
            vertical-tabs = [
              "tabbrowser-tabs"
            ];
            PersonalToolbar = [
              "personal-bookmarks"
            ];
          };
          seen = [
            "developer-button"
            "adguardadblocker_adguard_com-browser-action"
            "firefox_tampermonkey_net-browser-action"
            "_5efceaa7-f3a2-4e59-a54b-85319448e305_-browser-action"
          ];
          dirtyAreaCache = [
            "nav-bar"
            "vertical-tabs"
            "PersonalToolbar"
            "unified-extensions-area"
            "toolbar-menubar"
            "TabsToolbar"
          ];
          currentVersion = 20;
          newElementCount = 7;
        };
      };
    };
    policies = {
      DisableTelemetry = true; # 关闭遥测
      AppAutoUpdate = false; # 禁用自动更新
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
        "{3c078156-979c-498b-8990-85f7987dd929}" = {
          # 侧边栏
          installation_mode = "normal_installed";
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/sidebery/latest.xpi";
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
