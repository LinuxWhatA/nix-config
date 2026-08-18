# Redmi Book Pro 14 2022 (TM2107, BIOS RMARB4B1P1111) DSDT 修复
#
# 原始 BIOS DSDT 的 SVRP 方法中 PPPB buffer 声明为 0x12 字节但只装载了 17
# 字节数据（SSZE=0x12），SSDT3 的 A025 方法按 SSZE 循环读取时越界：
#   ACPI BIOS Error (bug): AE_AML_BUFFER_LIMIT, Index (0x12) is beyond end of
#   object (length 0x12) ... Aborting method \_SB.A025 / ALIB / SVRP / _Q93
#
# 与 vrolife/modern_laptop 的 fixes/acpi 同样的做法：
#   dsdt.dsl  = 本机 BIOS DSDT 的反编译源码（iasl -e ssdt*.dat -d）
#   patch.diff = 针对反编译源码的补丁（PPPB buffer 0x12->0x11、SSZE 0x12->0x11、
#                OEM Revision 0x02->0x03 供内核替换判定、移除与 MethodObj 冲突
#                的 AFN7 UnknownObj 外部声明）
#   构建时: patch -p0 && iasl -ve && 打包成未压缩 acpi_override.cpio
#
# 注意：升级 BIOS 后需重新 dump 并更新 dsdt.dsl / patch.diff
{
  stdenv,
  acpica-tools,
  cpio,
}:

stdenv.mkDerivation {
  pname = "redmi-acpi-table";
  version = "1.0.0";

  src = ./.;

  nativeBuildInputs = [
    acpica-tools
    cpio
  ];

  buildPhase = ''
    runHook preBuild
    patch -p0 < patch.diff
    iasl -ve dsdt.dsl
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p "$out" kernel/firmware/acpi
    cp dsdt.aml kernel/firmware/acpi/dsdt.aml
    find kernel -print0 | sort -z | cpio --quiet -o -H newc --reproducible --null > "$out/acpi_override.cpio"
    runHook postInstall
  '';

  meta = {
    description = "Patched DSDT (PPPB buffer OOB fix) as uncompressed acpi_override cpio for Redmi Book Pro 14 2022";
    platforms = [ "x86_64-linux" ];
  };
}
