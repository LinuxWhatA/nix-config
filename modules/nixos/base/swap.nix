# 交换策略：匿名页先压缩进 zram，磁盘 swapfile 只作 zram 满后的兜底。
{
  config,
  lib,
  ...
}:

{
  # 磁盘 swap 未设优先级时内核给负值，总排在 zram 之后；有人设更高优先级就会先落盘，
  # 故下方断言守住这个次序
  zramSwap = {
    # mkDefault 留出主机侧关掉 zram 的余地（内存交给宿主管的主机）
    enable = lib.mkDefault true;
    # 容量取内存一半：压缩页只占原始数据约 1/3，比 generator 的 4G 上限更能吃住桌面负载
    memoryPercent = 50;
    # zstd 兼顾压缩率与 CPU；内核默认的 lzo-rle 压得少
    algorithm = "zstd";
    # 断言以此为基准，钉住以免随上游默认漂移
    priority = 5;
  };

  # 用户态 OOM 按 cgroup 杀内存压力最大的那个，免得内核 OOM killer 砍到合成器；
  # root slice 也要管：重编译、容器、VM 都在 system slice 里
  systemd.oomd = {
    enable = true;
    enableRootSlice = true;
    enableUserSlices = true;
  };

  boot.kernel.sysctl = lib.mkMerge [
    {
      # 空闲内存低于 1/125 就唤醒 kswapd，回收变成平滑的背景行为
      "vm.watermark_scale_factor" = 125;
      # 不许临时抬高水位：为凑分配越过低水位会让回收延迟堆成尖峰
      "vm.watermark_boost_factor" = 0;
    }
    # 只为 zram 调：换出比回收文件页便宜，压缩页之间也无相邻性；无 zram 时反而加重磁盘换入换出
    (lib.mkIf config.zramSwap.enable {
      "vm.swappiness" = 100;
      "vm.page-cluster" = 0;
    })
  ];

  assertions = [
    {
      assertion = lib.all (
        d: d.priority == null || d.priority < config.zramSwap.priority
      ) config.swapDevices;
      message = "磁盘 swap 的 priority 必须低于 zramSwap.priority（${toString config.zramSwap.priority}），否则匿名页会先落盘而不是压缩进内存";
    }
  ];
}
