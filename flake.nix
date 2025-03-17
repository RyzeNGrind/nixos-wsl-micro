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
                ];

                environment.systemPackages = with pkgs; [
                  curl
                  git
                  nano
                  nixfmt-rfc-style
                  nixos-container
                  tzdata
                  wget
                  jq
                ];


                services.vscode-server.enable = true;

                system = {
                  stateVersion = "24.11";
                  configurationRevision = 
                    if self ? rev 
                    then self.rev 
                    else throw "Repository must be clean and committed";
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
