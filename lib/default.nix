{ nixpkgs-lib }:
rec {
  hypervisors = [
    "qemu"
    "cloud-hypervisor"
    "firecracker"
    "crosvm"
    "kvmtool"
    "stratovirt"
  ];

  hypervisorsWithNetwork = hypervisors;

  defaultFsType = "ext4";

  withDriveLetters = { volumes, hypervisor, storeOnDisk, ... }:
    let
      offset =
        if storeOnDisk
        then 1
        else 0;
    in
    map ({ fst, snd }:
      fst // {
        letter = snd;
      }
    ) (nixpkgs-lib.zipLists volumes (
      nixpkgs-lib.drop offset nixpkgs-lib.strings.lowerChars
    ));

  createVolumesScript = pkgs: pkgs.lib.concatMapStringsSep "\n" (
    { image
    , label
    , size ? throw "Specify a size for volume ${image} or use autoCreate = false"
    , fsType ? defaultFsType
    , autoCreate ? true
    , ...
    }: pkgs.lib.warnIf
      (label != null && !autoCreate) "Label will be ignored unless autoCreate is provided for the volume"
      (nixpkgs-lib.optionalString autoCreate ''
      PATH=$PATH:${with pkgs.buildPackages; lib.makeBinPath [ coreutils util-linux e2fsprogs ]}

      if [ ! -e '${image}' ]; then
        touch '${image}'
        # Mark NOCOW
        chattr +C '${image}' || true
        fallocate -l${toString size}MiB '${image}'
        mkfs.${fsType} ${pkgs.lib.optionalString (label != null) "-L '${label}'"} '${image}'
      fi
    ''));

  buildRunner = import ./runner.nix;

  makeMacvtap = { microvmConfig, hypervisorConfig }:
    import ./macvtap.nix {
      inherit microvmConfig hypervisorConfig;
      lib = nixpkgs-lib;
    };
}
