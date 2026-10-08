# winetricks 兼容层工作环境（`nix develop .#wshell`）。
# 与 devShells.default 并列而非合并：wine/mesa 体积大且只服务于 .verb 产出，
# 混进默认环境会让 direnv 每次加载都背上这份代价。
_: {
  perSystem =
    { pkgs, ... }:
    {
      devShells.wshell = pkgs.mkShell {
        name = "wshell";
        meta.description = "Wine/Winetricks environment for authoring and analyzing winetricks verbs";

        nativeBuildInputs = with pkgs; [
          # 交叉编译器只在产出 PE 时才用得上
          pkgsCross.mingwW64.stdenv.cc
          nixfmt

          # staging 带 WoW64，32 位 verb 也要能跑
          wineWow64Packages.staging
          winetricks

          # pev 的 peldd 顶替 ntldd：nixpkgs 未收录 ntldd / mingw-ldd / pestop；pefile 供导入表兜底解析
          binutils
          file
          pev
          (python3.withPackages (ps: [ ps.pefile ]))

          # verb 运行期按 PATH 找这些工具，缺一个就中途失败
          wget
          curl
          p7zip
          unzip
          cabextract
          perl

          # 离线核对该 verb 究竟装了什么：p7zip 解不开 Inno，也读不出 MSI 属性表
          innoextract
          msitools
          # .reg/.inf 必须是 CRLF 才能被 wine 的 regedit 正确吃掉
          dos2unix

          # llvmpipeHook 才是生效的那半：mesa 自身不带 setupHook，不挂它 vulkaninfo 枚举不到 ICD；
          # 但它会一并设 LIBGL_ALWAYS_SOFTWARE=true，要测真实 GPU 须先 unset。
          # xvfb-run 自带 Xvfb 的 store 路径（nixpkgs 的 xvfb 只有 Xvfb 本体），故不另列 xvfb。
          xvfb-run
          vulkan-tools
          vulkan-loader
          mesa
          mesa.llvmpipeHook
          # glxinfo 是 vulkaninfo 的另一半：判定 GL 走的是 lavapipe 还是真实驱动
          mesa-demos

          shellcheck
          jq
          yq-go
          ripgrep
          tree
          git

          # cheapwine 只在 PyPI 上，靠 uv 现装；DLL 覆盖走 distillery.json 的 env.WINEDLLOVERRIDES
          uv
        ];
      };
    };
}
