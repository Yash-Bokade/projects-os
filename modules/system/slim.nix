# Keep the closure small so the OS stays well inside its 28 GB partition.
{ ... }:
{
  documentation = {
    enable = true;
    man.enable = true;
    doc.enable = false;
    info.enable = false;
    nixos.enable = false;
  };

  environment.defaultPackages = [ ];
  programs.command-not-found.enable = false;
}
