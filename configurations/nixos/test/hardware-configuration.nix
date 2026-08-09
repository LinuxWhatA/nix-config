# test 为模块测试机：仅提供最小 fileSystems 以满足 NixOS 求值断言（非真实硬件）
{
  fileSystems."/" = {
    device = "tmpfs";
    fsType = "tmpfs";
    options = [
      "noatime"
      "mode=755"
    ];
  };
}
