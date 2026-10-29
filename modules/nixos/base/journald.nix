# journald 默认按根分区 10% 封顶，长期开着能攒到数 GB 并连快照一起胀；
# 100M 够回溯若干次启动，也省 SSD 写入。
{
  services.journald.settings.Journal = {
    SystemMaxUse = "100M";
    SystemMaxFileSize = "16M";
  };
}
