{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixos-wsl = {
      url = "github:nix-community/NixOS-WSL/main";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    vscode-server = {
      url = "github:nix-community/nixos-vscode-server";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      nixos-wsl,
      vscode-server,
      ...
    }:
    {
      nixosConfigurations = {
        nix-ws = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [

            nixos-wsl.nixosModules.default

            vscode-server.nixosModules.default

            (
              { pkgs, lib, ... }:
              {

                nix.settings = {
                  experimental-features = [
                    "nix-command"
                    "flakes"
                  ];
                  trusted-users = [
                    "root"
                    "ryzengrind"
                  ];
                };

                programs = {
                  direnv.enable = true;
                  nix-ld.enable = true;
                };

                wsl.extraBin = with pkgs; [
                  { src = "${pkgs.coreutils}/bin/uname"; }
                  { src = "${pkgs.coreutils}/bin/dirname"; }
                  { src = "${pkgs.coreutils}/bin/readlink"; }
                  { src = "${pkgs.git}/bin/git"; }
                  { src = "${bashInteractive}/bin/bash"; }
                  { src = "${findutils}/bin/find"; }
                ];

                environment = {
                  variables = {
                    PATH = lib.mkDefault (lib.mkBefore [
                      "$HOME/.nix-profile/bin"  # Only add your custom paths
                    ]);
                  };
                  systemPackages = with pkgs; [
                    curl
                    git
                    nano
                    nixfmt-rfc-style
                    nixos-container
                    tzdata
                    wget
                    jq
                  ];
                };
                
                # Critical fix from nixos-vscode-server docs
                services.vscode-server = {
                  enable = true;
                  nodejsPackage = pkgs.nodejs-18_x; # Specific version requirement
                  installPath = "$HOME/.cursor-server";
                };

                system = {
                  stateVersion = "24.11";
                  configurationRevision = 
                    if self ? rev 
                    then self.rev 
                    else (lib.trace "Repository must be clean and committed" null);
                };

                users = {
                  users.ryzengrind = {
                    isNormalUser = true;
                    extraGroups = [
                      "docker"
                      "nixbld"
                      "wheel"
                    ];
                    shell = pkgs.bashInteractive;
                  };
                };

                wsl = {
                  enable = true;
                  defaultUser = "ryzengrind";
                  wslConf.network.hostname = "nix-pc";
                  docker-desktop.enable = true;
                  startMenuLaunchers = true;
                  useWindowsDriver = true;
                };
              }
            )
          ];
        };
      };
    };
}
