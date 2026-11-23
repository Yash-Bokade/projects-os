{ theme, vars, ... }:
{
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "bak";
    extraSpecialArgs = { inherit theme vars; };
    users.${vars.user} = import ../../home;
  };
}
