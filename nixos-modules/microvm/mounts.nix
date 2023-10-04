{ config, lib, ... }:

let
  inherit (config.microvm) storeDiskType storeOnDisk writableStoreOverlay;

  inherit (import ../../lib {
    nixpkgs-lib = lib;
  }) defaultFsType withDriveLetters;

  hostStore = builtins.head (
    builtins.filter ({ source, ... }:
      source == "/nix/store"
    ) config.microvm.shares
  );

  roStore =
    if storeOnDisk
    then "/nix/.ro-store"
    else hostStore.mountPoint;

  roStoreDisk =
    if storeOnDisk
    then
      if storeDiskType == "erofs"
      # erofs supports filesystem labels
      then "/dev/disk/by-label/nix-store"
      else "/dev/vda"
    else throw "No disk letter when /nix/store is not in disk";

in
lib.mkIf config.microvm.guest.enable {
  fileSystems = lib.mkMerge [ (
    # built-in read-only store without overlay
    lib.optionalAttrs (
      storeOnDisk &&
      writableStoreOverlay == null
    ) {
      "/nix/store" = {
        device = roStoreDisk;
        fsType = storeDiskType;
        options = [ "x-systemd.after=systemd-modules-load.service" ];
        neededForBoot = true;
      };
    }
  ) ]
}
