{ theme, ... }:
{
  programs.bash = {
    enable = true;
    historyControl = [ "ignoredups" ];
    shellAliases = {
      ll = "ls -lah";
      ".." = "cd ..";
      rebuild = "sudo nixos-rebuild switch --flake ~/portable-nixos#portable";
      projects = "column -t -s \"$(printf '\\t')\" ~/Projects/.registry.tsv";
      newproject = "mkproj";
    };
  };

  programs.starship = {
    enable = true;
    settings = {
      add_newline = false;
      format = "$directory$git_branch$git_status$nix_shell$character";
      directory = {
        style = "fg:${theme.primary}";
        truncation_length = 3;
      };
      git_branch = {
        style = "fg:${theme.dim}";
        format = "[$branch]($style) ";
      };
      nix_shell = {
        style = "fg:${theme.secondary}";
        format = "[nix]($style) ";
      };
      character = {
        success_symbol = "[>](fg:${theme.primary})";
        error_symbol = "[>](fg:${theme.secondary})";
      };
    };
  };

  programs.git = {
    enable = true;
    settings = {
      init.defaultBranch = "main";
      pull.rebase = true;
    };
  };

  # `use flake` in a project's .envrc loads its dev shell automatically.
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
    config.global.hide_env_diff = true;
  };

  programs.yazi.enable = true; # terminal file manager (Mod+E)
}
