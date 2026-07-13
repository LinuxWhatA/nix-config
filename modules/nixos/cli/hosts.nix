{ lib, ... }:

{
  networking.stevenblack = {
    enable = true;
    block = [];
  };

  networking.extraHosts = lib.mkDefault '''';
}
