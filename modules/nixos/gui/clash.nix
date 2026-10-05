# 订阅由机场控制且每次更新重写，mihomo 1.19 的两项要求只能在应用自管的订阅增强里满足，
# nix 侧无处可插：脚本扩展（profiles/<uid>.js，uid 随机生成）删掉已被移除的
# global-client-fingerprint，并把 fallback-filter.geosite 的 gfw 换成 geosite.dat 里
# 实际存在的 geolocation-!cn（v2fly 数据集 2022 年后不再产出 gfw）。
{
  programs.clash-verge = {
    enable = true;
    tunMode = true;
    serviceMode = true;
  };
}
