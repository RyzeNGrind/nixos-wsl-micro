Minimum flake-enabled NixOS-WSL config, preconfigured for local development, including VSCode and Docker integration. Apply within [NixOS-WSL](https://github.com/nix-community/NixOS-WSL) with:
```bash
nixos-rebuild switch --flake github:Avunu/nixos-wsl-micro#nixos --refresh
```
If the above command fails, try:
```powershell
wsl -d NixOS --system --user root -- /mnt/wslg/distro/bin/nixos-wsl-recovery
```
Then rerun `nixos-rebuild`, as above.