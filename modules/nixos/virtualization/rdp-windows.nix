# Windows 11（RDP）虚拟机 —— 参照 RDPWindows.xml（virsh dumpxml RDPWindows）定义，
# 由 NixVirt 管理。xml 是 virt-manager 导出的，默认/冗余值（PCI 地址、控制器、
# 内存单位、on_* 策略等）已省略，由 libvirt 自动补齐。
# 注意：启用后该连接（qemu:///system）上其他未在此声明的虚拟机会被删除。
# 主机配置一行导入：(self + /modules/nixos/virtualization/rdp-windows.nix)
{ flake, ... }:

let
  nixvirt = flake.inputs.NixVirt.lib;

  domainXML = nixvirt.domain.writeXML {
    name = "RDPWindows";
    uuid = "678e2c46-f13a-4b5d-ae75-48c5abe9769b";
    type = "kvm";
    memory = {
      count = 15360000;
    };
    memoryBacking = {
      source = {
        type = "memfd";
      };
      access = {
        mode = "shared";
      };
    };
    vcpu = {
      count = 10;
    };
    os = {
      firmware = "efi";
      type = "hvm";
      machine = "pc-q35-11.0";
      loader = {
        path = "/run/libvirt/nix-ovmf/edk2-x86_64-secure-code.fd";
        secure = true;
      };
      nvram = {
        path = "/var/lib/libvirt/qemu/nvram/RDPWindows_VARS.fd";
        template = "/run/libvirt/nix-ovmf/edk2-i386-vars.fd";
      };
    };
    features = {
      acpi = { };
      apic = { };
      hyperv = {
        relaxed = {
          state = true;
        };
        vapic = {
          state = true;
        };
        spinlocks = {
          state = true;
          retries = 8191;
        };
        vpindex = {
          state = true;
        };
        runtime = {
          state = true;
        };
        synic = {
          state = true;
        };
        stimer = {
          state = true;
        };
        frequencies = {
          state = true;
        };
        tlbflush = {
          state = true;
        };
        ipi = {
          state = true;
        };
      };
      vmport = {
        state = false;
      };
      smm = {
        state = true;
      };
    };
    cpu = {
      mode = "host-passthrough";
    };
    clock = {
      offset = "localtime";
      timer = [
        {
          name = "hpet";
          present = false;
        }
        {
          name = "hypervclock";
          present = true;
        }
      ];
    };
    devices = {
      emulator = "/run/libvirt/nix-emulators/qemu-system-x86_64";
      disk = [
        {
          driver = {
            type = "vpc";
          };
          source = {
            file = "/mnt/Windows/OS/Windows.vhd";
          };
          target = {
            dev = "sda";
            bus = "sata";
          };
        }
      ];
      interface = [
        {
          type = "network";
          mac = {
            address = "52:54:00:59:86:57";
          };
          source = {
            network = "default";
          };
          model = {
            type = "virtio";
          };
        }
      ];
      channel = [
        {
          type = "spicevmc";
          target = {
            type = "virtio";
            name = "com.redhat.spice.0";
          };
        }
        {
          type = "unix";
          target = {
            type = "virtio";
            name = "org.qemu.guest_agent.0";
          };
        }
      ];
      input = [
        {
          type = "tablet";
          bus = "usb";
        }
      ];
      graphics = [
        {
          type = "spice";
          image = {
            compression = false;
          };
        }
      ];
      sound = [ { model = "ich9"; } ];
      audio = [
        {
          id = 1;
          type = "spice";
        }
      ];
      video = [
        {
          model = {
            type = "qxl";
          };
        }
      ];
      redirdev = [
        {
          bus = "usb";
          type = "spicevmc";
        }
        {
          bus = "usb";
          type = "spicevmc";
        }
      ];
      watchdog = {
        model = "itco";
        action = "reset";
      };
    };
  };
in
{
  imports = [
    flake.inputs.NixVirt.nixosModules.default
  ];

  virtualisation.libvirt = {
    enable = true;
    connections."qemu:///system".domains = [
      {
        definition = domainXML;
      }
    ];
  };

  passthru = { inherit domainXML; };
}
