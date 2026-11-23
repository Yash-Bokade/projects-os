# Nix settings tuned for a small disk.
#
# "Global packages installed once": the store is shared by the whole system, and the
# nixpkgs flake registry entry is pinned to the exact nixpkgs this OS was built from
# (nixosSystem registers it automatically). Project flakes use `nixpkgs.url = "nixpkgs"`,
# so their dev shells reuse packages that are already in /nix/store.
{ ... }:
{
  nix = {
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      auto-optimise-store = true; # hard-link identical files
      trusted-users = [
        "root"
        "@wheel"
      ];
      warn-dirty = false;
    };

    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 7d";
    };
  };

  nixpkgs.config.allowUnfree = true; # linux-firmware blobs etc.
}
