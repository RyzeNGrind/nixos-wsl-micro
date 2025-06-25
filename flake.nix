{
  inputs = {
    unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    nixos-wsl = {
      url = "github:nix-community/NixOS-WSL/2411.6.0"; # main";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    vscode-server = {
      url = "github:nix-community/nixos-vscode-server";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Flake-parts for structure
    flake-parts.url = "github:hercules-ci/flake-parts";
    # git-hooks.nix for managing pre-commit hooks via Nix
    git-hooks-nix = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
   inputs @ {
      self,
      nixpkgs,
      unstable,
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
	       # Set up proper nixpkgs configuration with overlays
       	       nixpkgs = {
	         config = {
	           allowUnfree = true;
	           allowBroken = true;
	         };
	         overlays = [
	           # Use the unstable overlay from inputs
	           (_final: prev: {
	             unstable = import inputs.unstable {
	               inherit (prev) system;
	               config.allowUnfree = true;
	             };
	           })
	         ];
	        };
		boot.kernelModules = ["usbip-core" "usbip-host" "vhci-hcd"];
                nix.settings = {
                  experimental-features = [
                    "nix-command"
                    "flakes"
		    "auto-allocate-uids"
		    "ca-derivations"
		    "cgroups"
		    "dynamic-derivations"
		    "fetch-closure"
		    "fetch-tree"
		    "git-hashing"
		    "local-overlay-store"
		    "mounted-ssh-store"
		    "no-url-literals"
		    "pipe-operators"
		    "recursive-nix"
                  ];
                  trusted-users = [
                    "root"
		    "@wheel"
                    "ryzengrind"
                  ];
                };

	        programs = {
                  direnv.enable = true;
                  fish = {
	            enable = true;
	      	    interactiveShellInit = ''
	            # Manual starship init for fish
	            ${pkgs.starship}/bin/starship init fish | source
	            '';
	    	  };
	    	  nix-ld = {
	      	    enable = true;
	      	    libraries = with pkgs; [
	              #  stdenv.cc.cc
	              #  zlib
	              #  openssl
	              #  libunwind
	              #  icu
	              #  libuuid
	            ];
	    	  };
	    	  bash = {
	      	    completion.enable = true;
	      	    interactiveShellInit = ''
	            # Initialize starship first
	            eval "$(${pkgs.starship}/bin/starship init bash)"
	      	    '';
	    	  };
	    	  starship = {
	      	    enable = true;
	      	    settings = {
	            add_newline = true;
	            command_timeout = 5000;
	            character = {
	              error_symbol = "[❯](bold red)";
	              success_symbol = "[❯](bold green)";
	              vicmd_symbol = "[❮](bold blue)";
	            };
	            # Add explicit format wrapping
	            format = "$all $character";
	      	    };
	          };
	        };
                wsl = {
                  enable = true;
                  defaultUser = "ryzengrind";
                  wslConf.network.hostname = "nix-ws";
                  docker-desktop.enable = true;
                  startMenuLaunchers = true;
                  useWindowsDriver = true;
		  extraBin = with pkgs; [
                    { src = "${coreutils}/bin/uname"; }
                    { src = "${coreutils}/bin/dirname"; }
                    { src = "${coreutils}/bin/readlink"; }
                    { src = "${git}/bin/git"; }
                    { src = "${bashInteractive}/bin/bash"; }
                    { src = "${findutils}/bin/find"; }
		    { src = "${coreutils}/bin/mkdir"; }
      		    { src = "${coreutils}/bin/cat"; }
      		    { src = "${coreutils}/bin/whoami"; }
      		    { src = "${coreutils}/bin/ls"; }
      		    { src = "${busybox}/bin/addgroup"; }
      		    { src = "${su}/bin/groupadd"; }
      		    { src = "${su}/bin/usermod"; }
      		    { src = "${shadow}/sbin/unix_chkpwd"; } #<-- CRUCIAL for PAM
      		    { src = "${systemd}/bin/systemctl"; }
      		    { src = "${systemd}/bin/loginctl"; } # Good to include for any linger checks
      		    { src = "${gnugrep}/bin/grep"; }
                  ];
		  usbip.enable = true;
                };
                environment = {
		  extraInit = ''
  		  mkdir -p /usr/bin
  		  ln -sf ${pkgs.systemd}/bin/systemctl /usr/bin/systemctl
  		  ln -sf ${pkgs.gnugrep}/bin/grep /usr/bin/grep
		  '';
                  variables = {
                    PATH = lib.mkDefault (lib.mkBefore [
                      "$HOME/.nix-profile/bin"  # Only add your custom paths
                    ]);
                  };
                  shellAliases = {
      		  # Clear any conflicting aliases
    		  };
    		  pathsToLink = ["/share/bash-completion"];
                  systemPackages = with pkgs; [
                    curl
                    git
		    starship
		    bashInteractive
		    bash-completion
                    nano
                    nixfmt-rfc-style
                    nixos-container
                    tzdata
                    wget
                    jq
	 	    linuxPackages.usbip
		    coreutils
		    findutils
		    gnugrep
		    tzdata
                  ];
                };
                
                # Critical fix from nixos-vscode-server docs
                services.vscode-server = {
                  enable = true;
                  nodejsPackage = pkgs.nodejs_20; # Specific version requirement
                  installPath = "$HOME/.cursor-server";
                };

                system = {
                  stateVersion = "24.11";
                  configurationRevision = 
                    if self ? rev 
                    then self.rev 
                    else (lib.trace "Repository must be clean and committed" null);
                };
		security.sudo = {
    		  enable = true;
    	   	  execWheelOnly = true; # Optional security measure
    		  wheelNeedsPassword = false;
  		};
		systemd.tmpfiles.rules = [
  		  "z /run/systemd/system-generators/wsl-generator 0755 root root -"
  		  "z /run/systemd/user-generators/wsl-user-generator 0755 root root -"
		];
                users = {
                  users.ryzengrind = {
                    isNormalUser = true;
		    hashedPassword = "$6$HI.fENQPPYsDtPh0$2zzBVFLjek./aHlwc0/AW5SdLNVQBixxYQnLyvcQhdFkNuIgT0KdHMTElFSiFd6PeK1.svjGw0zJnNkByQ3fn/";
		    openssh.authorizedKeys.keys = [
		      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILaDf9eWQpCOZfmuCwkc0kOH6ZerU7tprDlFTc+RHxCq ryzengrind@nixdevops.remote"
		      # You can add other authorized keys here if needed, or manage them via Opnix if it exports a list of keys.
		    ];
                    extraGroups = [
                      "audio"
		      "docker"
		      "kvm"
		      "libvirt"
		      "libvirtd"
		      "networkmanager"
		      "nixbld"
                      "podman"
		      "qemu-libvirtd"
		      "users"
		      "video"
                      "wheel"		
                    ];
		    #TODO: change to fish once IDE{cursor,void,zed,vscodium,vscode} shell integration logic working
                    shell = pkgs.bashInteractive; 
                  };
		  users.systemd-oom = {
  		    isSystemUser = true;
  		    description = "systemd OOMd user";
  		    group = "nogroup";
		  };
                };
	        services.openssh = {
    		  enable = true;
    		  settings = {
      		    PasswordAuthentication = true;
      		    PermitRootLogin = "yes";
      		    X11Forwarding = true;
      		    UsePAM = true;
    		  };
    		  openFirewall = true;
  		};
		networking.firewall.enable = true;
  		networking.firewall.allowedTCPPorts = [22 2222];
              }
            )
          ];
        };
      };
    };
}
