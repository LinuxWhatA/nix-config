{
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  # Electron/Chromium 自带捆绑 libvulkan/libGL（rpath 顺位次于 LD_LIBRARY_PATH），
  # 不给全局变量则图形会话里 dlopen 到捆绑 loader，找不到 NixOS 的 ICD，
  # ANGLE 报 VK_ERROR_INCOMPATIBLE_DRIVER（-9）
  environment.sessionVariables.LD_LIBRARY_PATH = [
    "/run/opengl-driver/lib"
    "/run/opengl-driver-32/lib"
  ];

  boot.kernel.sysctl."kernel.sysrq" = 1;
  hardware.enableRedistributableFirmware = true;
}
