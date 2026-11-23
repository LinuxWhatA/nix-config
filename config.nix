# Configuration for this repo
{
  me = {
    username = "lwa";
    fullname = "LinuxWhatA";
    email = "5351697+linuxwhata@user.noreply.gitee.com";
    sshKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBGUSC4bTGw+GTD3pmcqbYwZfmR5dShH4R+9qhTnerg2";
  };

  # nix 镜像缓存：flake 侧 nixConfig（构建期生效）与系统侧 nix.settings（rebuild 后生效）
  # 共用同一份，否则两处列表各自维护会漂移
  nixSubstituters = [
    "https://mirror.nju.edu.cn/nix-channels/store"
    "https://mirrors.ustc.edu.cn/nix-channels/store"
    "https://mirror.sjtu.edu.cn/nix-channels/store"
    "https://cache.nixos.org/"
  ];
}
