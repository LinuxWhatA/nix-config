{
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };
  # Electron/Chromium 自带的 libvulkan 会盖过系统库，不显式给出就找不到 NixOS 的 ICD
  # （ANGLE 报 VK_ERROR_INCOMPATIBLE_DRIVER）。各桌面会话入口不同（labwc wrapper、
  # sddm session、greetd default_session），逐桌面注入必漏，故全局；上游 pipewire.jack 同法。
  environment.sessionVariables.LD_LIBRARY_PATH = [
    "/run/opengl-driver/lib"
    "/run/opengl-driver-32/lib"
  ];

  boot.kernel.sysctl."kernel.sysrq" = 1;
  hardware.enableRedistributableFirmware = true;
}
