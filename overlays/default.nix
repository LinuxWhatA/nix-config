{
  outputs,
  inputs,
}:

let
  addPatches =
    pkg: patches:
    pkg.overrideAttrs (oldAttrs: {
      patches = (oldAttrs.patches or [ ]) ++ patches;
    });
in
{
  # Adds my custom packages
  additions = final: prev: import ../pkgs { pkgs = final; };

  # Modifies existing packages
  modifications = final: prev: {
    # wechat
    wechat = prev.wechat.overrideAttrs (old: {
      src = prev.fetchurl {
        url = "https://dldir1v6.qq.com/weixin/Universal/Linux/WeChatLinux_x86_64.AppImage";
        hash = "sha256-gBWcNQ1o1AZfNsmu1Vi1Kilqv3YbR+wqOod4XYAeVKo=";
      };
    });
  };
}
