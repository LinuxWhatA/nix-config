{ flake, lib, ... }:

let
  inherit (flake) config inputs;
  inherit (inputs) self;
in
{
  imports = [
    {
      users.users.${config.me.username}.isNormalUser = lib.mkDefault true;
      home-manager.users.${config.me.username} = { };
      home-manager.sharedModules = [
        self.homeModules.default
        inputs.plasma-manager.homeModules.plasma-manager
      ];
    }
    self.nixosModules.common
  ];
}
