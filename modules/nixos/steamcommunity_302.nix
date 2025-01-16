{
  lib,
  pkgs,
  config,
  ...
}:

let
  cfg = config.my.steamcommunity_302;
in
{
  options.my.steamcommunity_302 = {
    enable = lib.mkEnableOption "Enable steamcommunity 302";
  };

  config = lib.mkIf cfg.enable {
    security.pki.certificates = [
      ''
        -----BEGIN CERTIFICATE-----
        MIIEVjCCAz6gAwIBAgIJAPSqi7Ep9hEuMA0GCSqGSIb3DQEBCwUAMGwxCzAJBgNV
        BAYTAkNOMQswCQYDVQQIDAJYWDELMAkGA1UEBwwCWFgxGjAYBgNVBAoMEVN0ZWFt
        Y29tbXVuaXR5MzAyMQswCQYDVQQLDAJYWDEaMBgGA1UEAwwRU3RlYW1jb21tdW5p
        dHkzMDIwHhcNMjUwMTE2MTUxOTIxWhcNMjYwMTE2MTUxOTIxWjBsMQswCQYDVQQG
        EwJDTjELMAkGA1UECAwCWFgxCzAJBgNVBAcMAlhYMRowGAYDVQQKDBFTdGVhbWNv
        bW11bml0eTMwMjELMAkGA1UECwwCWFgxGjAYBgNVBAMMEVN0ZWFtY29tbXVuaXR5
        MzAyMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA3j5dB9mqGUW8y6W0
        0Sf0BidiT/U7T6WpK5yBbdx7vAeW7W0EuTkMx+zQalNx3SmTyiO524h3QdCgSoGQ
        o+g4MIqKQnWvpRP1Kw7QP6Ev81zROq4B/gZcEO3bWcwH9oNB22nLmI96eZweSkeT
        Ns1Wwa75XnGiej47CLaWKXmipJV13E93Y4j/bNFibhENSJhPS7Qpr9cNg8gffpxZ
        29kvkDPaREtIdEHm8dfp5PCW/yK1MWQxrw3MjF0CKwfb7uubvWjyEpDJOHvQg0EQ
        hyslIDGWKhMpE/5sBNqJbbJPxS6kaFcAoVW1MaSe0Gumqz/jg0yge+2I8Vctpnn1
        4nGrjQIDAQABo4H6MIH3MB0GA1UdDgQWBBT0fxoSlJECYKmWIVffIy7ox0eQhjCB
        ngYDVR0jBIGWMIGTgBT0fxoSlJECYKmWIVffIy7ox0eQhqFwpG4wbDELMAkGA1UE
        BhMCQ04xCzAJBgNVBAgMAlhYMQswCQYDVQQHDAJYWDEaMBgGA1UECgwRU3RlYW1j
        b21tdW5pdHkzMDIxCzAJBgNVBAsMAlhYMRowGAYDVQQDDBFTdGVhbWNvbW11bml0
        eTMwMoIJAPSqi7Ep9hEuMBIGA1UdEwEB/wQIMAYBAf8CAQAwDgYDVR0PAQH/BAQD
        AgEGMBEGA1UdIAQKMAgwBgYEVR0gADANBgkqhkiG9w0BAQsFAAOCAQEAU4Qtgsfs
        n0nagw4tPreOycw8T8yH2RDDPFKwWvTSO3FAR2ZswIrzgSc6jl1SAVaLvx1aQ6rP
        bYaFDZ8ggH9bF3EKnpv6rKOwhpZOPEdaRR0bVjm5d277NfptOYhPMzBDXjjXVZtJ
        ybBZTJ7+C0d9XfXwwb44aTc/8aFBmunjQpYdKH56phEly2T6ReGkcEsbvr3gR1Yj
        oROBvQ1Pydo0sUuQ/PvV/ltySh9ytNi+3hGqaoX0Rt08PreJfvkyiOiVLE8HlPWe
        D0N4VuptWJVlAlSOIs3ZRRRT9/KBqzPLpLL7xOsTvGCvkQAbLt6of9c94dQBYluH
        OQWQYAeTwG64uw==
        -----END CERTIFICATE-----''
    ];

    networking.extraHosts = ''
      127.0.0.1 steamcommunity.com #S302
      127.0.0.1 www.steamcommunity.com #S302
      127.0.0.1 store.steampowered.com #S302
      127.0.0.1 checkout.steampowered.com #S302
      127.0.0.1 api.steampowered.com #S302
      127.0.0.1 help.steampowered.com #S302
      127.0.0.1 login.steampowered.com #S302
      127.0.0.1 store.akamai.steamstatic.com #S302
      127.0.0.1 www.youtube.com #S302
    '';
  };
}
