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
    # wechat-uos 添加 Network 分类
    wechat-uos = prev.buildFHSEnv (
      prev.wechat-uos.args
      // {
        extraInstallCommands =
          prev.wechat-uos.args.extraInstallCommands
          + ''
            sed -i 's|^Categories=.*|Categories=Network;Chat;|' \
              $out/share/applications/com.tencent.wechat.desktop
          '';
      }
    );
  };
}
