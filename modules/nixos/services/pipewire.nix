{
  security.rtkit.enable = true;
  services.pulseaudio.enable = false;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # 开启会全局注入 libjack 的 LD_LIBRARY_PATH，本机无 JACK 客户端；
    # 需要时用 pkgs.pipewire.jack 的 pw-jack 单独包装对应程序。
  };
}
