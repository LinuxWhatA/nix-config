{ flake, lib, ... }:

let
  inherit (flake) config inputs;
  inherit (inputs) self;
in
{
  imports = [
    {
      users.users.${config.me.username}.isNormalUser = lib.mkDefault true;
      home-manager.useGlobalPkgs = true;
      home-manager.backupFileExtension = "hm-backup";
      home-manager.users.${config.me.username} = { };
      home-manager.sharedModules = [
      	self.homeModules.gui
        self.homeModules.default
      ];
    }
    self.nixosModules.common
  ];
}
