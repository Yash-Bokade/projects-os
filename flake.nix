{
  description = "Portable NixOS for a pendrive / SD card: niri + ghostty + rofi + Zed + Rust, mono theme";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      ...
    }@inputs:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};

      # One place for every colour / font, and one place for user-level knobs.
      theme = import ./theme.nix;
      vars = import ./vars.nix;
    in
    {
      nixosConfigurations.portable = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs theme vars; };
        modules = [
          ./hosts/portable
          home-manager.nixosModules.home-manager
        ];
      };

      # Live ISO: same desktop, boots from the stick, persistent /home created on first boot.
      nixosConfigurations.live = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs theme vars; };
        modules = [
          ./hosts/live
          home-manager.nixosModules.home-manager
        ];
      };

      # nix build .#iso   ->   result/iso/portable-nixos.iso
      packages.${system} = {
        iso = self.nixosConfigurations.live.config.system.build.isoImage;
        default = self.packages.${system}.iso;
      };

      formatter.${system} = pkgs.nixfmt;

      devShells.${system}.default = pkgs.mkShell {
        packages = [
          pkgs.nixfmt
          pkgs.nil
          pkgs.git
        ];
      };
    };
}
