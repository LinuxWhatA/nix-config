{ flake, ... }: {
  home-manager.sharedModules = [ flake.inputs.self.homeModules.gui ];
}
