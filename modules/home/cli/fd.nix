{ pkgs, ... }:

{
  home.packages = [ pkgs.fd ];

  xdg.configFile."fd/ignore".text = ''
    # 版本控制
    .git/
    .svn/

    # 依赖和缓存
    node_modules/
    vendor/
    .cache/
    __pycache__/
    *.py[cod]
    .pytest_cache/
    .venv/

    # 构建输出
    dist/
    build/
    target/
    out/
    *.o
    *.so
    *~

    # 系统文件
    .DS_Store
    Thumbs.db
    *.swp
    *.swo

    # 用户设置
    /sys/
    /tmp/
    /mnt/
    /proc/
  '';
}
