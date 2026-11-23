# User-level knobs. Change these before running scripts/install.sh.
{
  user = "zei";
  fullName = "Zei";
  hostname = "nixos";

  # Volume label of the live ISO (max 32 chars). The persistence service finds the stick by it.
  isoLabel = "NIXOS_PORTABLE";

  # Only used for the very first login. Change it with `passwd` afterwards.
  initialPassword = "portable";
}
