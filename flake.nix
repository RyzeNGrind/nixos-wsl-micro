{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixos-wsl = {
      url = "github:nix-community/NixOS-WSL/main";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Use PR88 branch which supports multiple paths
    vscode-server = {
      url = "github:nix-community/nixos-vscode-server/pull/88/head";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nixos-wsl, vscode-server, ... }:
  let
    system = "x86_64-linux";
    pkgs = nixpkgs.legacyPackages.${system};
  in
  {
    nixosConfigurations = {
      nix-ws = nixpkgs.lib.nixosSystem {
        inherit system;
        
        modules = [
          nixos-wsl.nixosModules.default
          vscode-server.nixosModules.default
          
          # Your configuration
          ({ config, pkgs, lib, ... }: {
            environment.systemPackages = with pkgs; [
              curl git nano nixfmt-rfc-style nixos-container tzdata wget
            ];

            nix.settings.experimental-features = [ "nix-command" "flakes" ];
            programs.direnv.enable = true;

            services.vscode-server = {
              enable = true;
              # PR88 feature for multiple paths
              installPath = [
                "$HOME/.vscode-server"
                "$HOME/.vscode-server-insiders"
                "$HOME/.cursor-server"
              ];
            };
            
            # Add PR83 functionality as a separate module
            # This implements "enableForUsers" from PR83
            systemd.tmpfiles.rules = [
              "d /usr/lib/vscode-server 0755 root root -"
              "d /usr/lib/vscode-server/bin 0755 root root -"
            ];
            
            # Create a symlink in the global bin directory for all users
            system.activationScripts.vscodeServerLinks = ''
              mkdir -p /usr/lib/vscode-server/bin
              
              # For each vscode-server directory in user home dirs
              for userdir in /home/*/.vscode-server/bin/*; do
                if [ -d "$userdir" ]; then
                  # Get version hash from path
                  version=$(basename "$userdir")
                  
                  # Create system-wide directory if it doesn't exist
                  if [ ! -d "/usr/lib/vscode-server/bin/$version" ]; then
                    mkdir -p "/usr/lib/vscode-server/bin/$version"
                    cp -rT "$userdir" "/usr/lib/vscode-server/bin/$version"
                    
                    # Fix node symlink
                    ln -sf ${pkgs.nodejs-18_x}/bin/node "/usr/lib/vscode-server/bin/$version/node"
                  fi
                fi
              done
              
              # Same for vscode-server-insiders
              for userdir in /home/*/.vscode-server-insiders/bin/*; do
                if [ -d "$userdir" ]; then
                  version=$(basename "$userdir")
                  
                  if [ ! -d "/usr/lib/vscode-server/bin/$version" ]; then
                    mkdir -p "/usr/lib/vscode-server/bin/$version"
                    cp -rT "$userdir" "/usr/lib/vscode-server/bin/$version"
                    ln -sf ${pkgs.nodejs-18_x}/bin/node "/usr/lib/vscode-server/bin/$version/node"
                  fi
                fi
              done
              
              # Same for cursor-server
              for userdir in /home/*/.cursor-server/bin/*; do
                if [ -d "$userdir" ]; then
                  version=$(basename "$userdir")
                  
                  if [ ! -d "/usr/lib/vscode-server/bin/$version" ]; then
                    mkdir -p "/usr/lib/vscode-server/bin/$version"
                    cp -rT "$userdir" "/usr/lib/vscode-server/bin/$version"
                    ln -sf ${pkgs.nodejs-18_x}/bin/node "/usr/lib/vscode-server/bin/$version/node"
                  fi
                fi
              done
            '';
            
            vscode-remote-workaround.enable = true;
            
            # Keep your imports for the vscode-remote-workaround module
            imports = [
              ({ config, lib, pkgs, ... }: let
                cfg = config.vscode-remote-workaround;
              in {
                options.vscode-remote-workaround = {
                  enable = lib.mkEnableOption "automatic VSCode remote server patch";
                  package = lib.mkOption {
                    type = lib.types.package;
                    default = pkgs.nodejs-18_x;
                    defaultText = lib.literalExpression "pkgs.nodejs-18_x";
                    description = lib.mdDoc "The Node.js package to use. You generally shouldn't need to override this.";
                  };
                };

                config = lib.mkIf cfg.enable {
                  systemd.user = {
                    paths.vscode-remote-workaround = {
                      wantedBy = ["default.target"];
                      pathConfig.PathChanged = "%h/.vscode-server/bin";
                    };

                    services.vscode-remote-workaround.script = ''
                      for i in ~/.vscode-server/bin/*; do
                        echo "Fixing vscode-server in $i..."
                        ln -sf ${cfg.package}/bin/node $i/node
                      done
                    '';
                  };
                };
              })
            ];

            system.stateVersion = "24.11";

            users.users.ryzengrind = {
              isNormalUser = true;
              extraGroups = [ "docker" "nixbld" "wheel" ];
              shell = pkgs.bashInteractive;
            };

            wsl = {
              enable = true;
              defaultUser = "ryzengrind";
              wslConf.network.hostname = "nix-pc";
              docker-desktop.enable = true;
              startMenuLaunchers = true;
              useWindowsDriver = true;
            };
          })
        ];
      };
    };
  };
}
