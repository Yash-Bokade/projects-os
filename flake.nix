# ==========================================================================
#  nomad — a portable NixOS that lives on a 28 GB pendrive / SD card
#  niri (scrollable tiling) - ghostty - mono + NixOS-blue - elixir-first
#
#  This repository does one thing: GitHub Actions builds a bootable ISO
#  from it. Flash the ISO to a stick and you have the whole machine with
#  you — niri, OBS, device tools, WiFi/Bluetooth applets, Firefox (lean),
#  LocalSend and `mkproj` for Elixir projects.
#
#  Repo layout:
#    flake.nix        <- you are here (identity + inputs + the ISO output)
#    shared.nix       <- the OS (services, packages, network, user)
#    iso.nix          <- the live image: boot, persistence, rescue setup
#    home.nix         <- user apps and dotfiles
#    files/*          <- niri / ghostty / waybar / fuzzel / swaylock configs
#    modules/mkproj.* <- the `mkproj` command (elixir project creator)
#    scripts/persist-setup.sh <- one command to enable persistence
#    .github/workflows/build-iso.yml <- builds the ISO on every push
#
#  Build the ISO locally, if you prefer:
#    nix build .#iso
#  The image lands in result/iso/*.iso
# ==========================================================================
{
  description = "nomad: a portable NixOS stick — niri + ghostty + elixir, mono with NixOS-blue";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    impermanence.url = "github:nix-community/impermanence";
  };

  outputs = { self, nixpkgs, home-manager, impermanence, ... }@inputs:
    let
      # ---- EDIT ME (only once, they are used everywhere) --------------
      system   = "x86_64-linux";      # the stick's CPU architecture
      username = "dev";               # your login user
      hostname = "nomad";             # hostname and flake attribute
      timezone = "Asia/Kolkata";
      locale   = "en_IN.UTF-8";
      # -----------------------------------------------------------------

      common = { inherit username hostname timezone locale; };
    in
    {
      # the live system the ISO is built from
      nixosConfigurations."${hostname}-iso" = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs system; } // common;
        modules = [
          ./shared.nix
          ./iso.nix
          ./modules/mkproj.nix
          impermanence.nixosModules.impermanence
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.extraSpecialArgs = { inherit username hostname; };
            home-manager.users.${username} = import ./home.nix;
          }
        ];
      };

      # `nix build .#iso` -> result/iso/*.iso
      packages.${system} = {
        iso = self.nixosConfigurations."${hostname}-iso".config.system.build.isoImage;
        default = self.packages.${system}.iso;
      };
    };
}
