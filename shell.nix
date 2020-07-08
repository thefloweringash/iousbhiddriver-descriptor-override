let
  pkgs = import <nixpkgs> {};
  inherit (pkgs) lib stdenv;

  gemConfig = pkgs.defaultGemConfig // {
    libusb = attrs: {
      buildFlags = [ "--enable-system-libusb" ];

      dontBuild = false;

      patches = [
        ./nix/libusb-path.patch
      ];

      postPatch = ''
        substituteInPlace lib/libusb/call.rb \
          --subst-var-by libusb \
            ${lib.getLib pkgs.libusb}/lib/libusb-1.0${stdenv.hostPlatform.extensions.sharedLibrary}
      '';
    };
  };
in

(pkgs.bundlerEnv {
  name = "ruby-env";
  gemdir = ./.;
  inherit gemConfig;
}).env
