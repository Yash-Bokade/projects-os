# mkproj — npm-init-style Elixir project creator.
# The script itself lives next to this file (easier to read and lint);
# this module just installs it globally as `mkproj`.
{
  config,
  pkgs,
  lib,
  ...
}:
{
  environment.systemPackages = [
    (pkgs.writeShellScriptBin "mkproj" (builtins.readFile ./mkproj.sh))
  ];
}
