{ flake, ... }:

{
  imports = [
    {
      home-manager.sharedModules = [
        flake.inputs.self.homeModules.gui
      ];
    }
  ];
}
