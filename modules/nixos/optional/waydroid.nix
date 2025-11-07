{ pkgs, ... }:

{
  virtualisation.waydroid.enable = true;

  environment.systemPackages = with pkgs; [
    wl-clipboard # 剪贴板共享
  ];

  /**
    # https://nixos.wiki/wiki/WayDroid
    sudo waydroid init
    sudo systemctl start waydroid-container
    sudo journalctl -u waydroid-container
    waydroid session start

    # 安装ARM兼容层(libhoudini)、状态栏隐藏(hidestatusbar)
    git clone https://github.com/casualsnek/waydroid_script
    cd waydroid_script
    python3 -m venv venv
    venv/bin/pip install -r requirements.txt
    sudo venv/bin/python3 main.py install libhoudini
    sudo venv/bin/python3 main.py hack hidestatusbar
    waydroid prop set perist.waydroid.multi_windows true
    waydroid prop set persist.waydroid.fake_touch com.hypergryph.arknights
    waydroid prop set persist.waydroid.cursor_on_subsurface true
    sudo mount --bind ~/Downloads ~/.local/share/waydroid/data/media/0/Download
  */
}
