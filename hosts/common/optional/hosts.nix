{ lib, ... }:

{
  networking.stevenblack = {
    enable = true;
    block = [
      "fakenews"
      "gambling"
      "porn"
    ];
  };

  networking.extraHosts = lib.mkDefault '''';
}
