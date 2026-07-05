{
  lib,
  pkgs,
  flake,
  config,
  ...
}:

let
  # Sops needs acess to the keys before the persist dirs are even mounted; so
  # just persisting the keys won't work, we must point at /persist
  hasOptinPersistence = config.environment.persistence ? "/persist";
in
{
  users.users.root.openssh.authorizedKeys.keys = [ flake.config.me.sshKey ];
  users.users."${flake.config.me.username}" = {
    isNormalUser = true;
    shell = pkgs.zsh;
    extraGroups = [
      "wheel"
      "networkmanager"
    ];

    openssh.authorizedKeys.keys = [ flake.config.me.sshKey ];
    hashedPassword = "$6$6aT0cza7dVGIOdsf$ICgv1WOo255hp41vzsz2c7m1BtI51MFfmR7K7qJdJ4zRR2yFSNS0mKsqSMhMPPSWbShpi5UzgMmOkd/9UMxEg0";
  };

  services.openssh = {
    enable = true;
    settings = {
      # Harden
      PasswordAuthentication = false;
      PermitRootLogin = "no";

      # Automatically remove stale sockets
      StreamLocalBindUnlink = "yes";
      # Allow forwarding ports to everywhere
      GatewayPorts = "clientspecified";
      # Let WAYLAND_DISPLAY be forwarded
      AcceptEnv = [ "WAYLAND_DISPLAY" ];
      X11Forwarding = true;
    };

    hostKeys = [
      {
        path = "${lib.optionalString hasOptinPersistence "/persist"}/etc/ssh/ssh_host_ed25519_key";
        type = "ed25519";
      }
    ];
  };
}
