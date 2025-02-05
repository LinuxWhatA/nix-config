{
  inputs,
  ...
}:

{
  imports = [ inputs.sops-nix.nixosModules.sops ];

  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
  };
}
