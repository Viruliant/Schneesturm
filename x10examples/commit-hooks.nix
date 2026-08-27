{ inputs, ... }:
{
  imports = [ inputs.git-hooks.flakeModule ];
  perSystem =
    { config, ... }:
    {
      pre-commit.settings.hooks = {
        check-symlinks.enable = true;
        detect-private-keys.enable = true;
        fix-byte-order-marker.enable = true;
      };
      x10.devShell.packages = config.pre-commit.settings.enabledPackages ++ [
        config.pre-commit.settings.package
      ];
      x10.devShell.shellHook = config.pre-commit.settings.installationScript;
    };
}
