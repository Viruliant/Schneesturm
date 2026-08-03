ls /run/current-system/sw/share/man/man1
. . .
taskset.1.gz
tcc.1.gz
tee.1.gz
test.1.gz
texi2any.1.gz
texi2dvi.1.gz
texi2pdf.1.gz
texindex.1.gz
tic.1m.gz
timedatectl.1.gz
timeout.1.gz
tload.1.gz
toe.1m.gz
top.1.gz
. . .

the man files of our proj should go into /share/man/ just like these, but
`tree ./result/nix/store/` current outputs they are in root dir and not gzip'd:

    ├── man
    │   ├── man1
    │   │   ├── mkc_check_compiler.1
    │   │   ├── mkc_check_custom.1
    │   │   ├── mkc_check_decl.1
    │   │   ├── mkc_check_funclib.1
    │   │   ├── mkc_check_header.1
    │   │   ├── mkc_check_prog.1
    │   │   ├── mkc_check_sizeof.1
    │   │   ├── mkc_check_version.1
    │   │   ├── mkc_compiler_settings.1
    │   │   ├── mkc_install.1
    │   │   ├── mkc_which.1
    │   │   └── mkcmake.1
    │   └── man7
    │       └── mk-configure.7


ok we tried solving the 1st problem commenting installphase to use the current version of installphase

but now we're getting:


[owner@nixos:~/sync/Blizzard/mk-configure_v5]$ cd /home/owner/sync/Blizzard/mk-configure_v5
rm ./flake.lock
nix build
nix develop
warning: creating lock file "/home/owner/sync/Blizzard/mk-configure_v5/flake.lock": 
• Added input 'flake-utils':
    'github:numtide/flake-utils/11707dc2f618dd54ca8739b309ec4fc024de578b?narHash=sha256-l0KFg5HjrsfsO/JpG%2Br7fRrqm12kzFHyUHqHCVpMMbI%3D' (2024-11-13)
• Added input 'flake-utils/systems':
    'github:nix-systems/default/da67096a3b9bf56a91d16901293e51ba5b49a27e?narHash=sha256-Vy1rq5AaRuLzOxct8nz4T6wlgyUR7zLU309k9mBC768%3D' (2023-04-09)
• Added input 'nixpkgs':
    'github:NixOS/nixpkgs/3e41b24abd260e8f71dbe2f5737d24122f972158?narHash=sha256-rxO%2Buc/KFbSJp%2BpgyXRuAX6QlG9hJdnt0BXpEQRXY%2BU%3D' (2026-06-16)
mk-configure + bmkdep development shell ready!
[mk-configure-mono:owner@nixos:~/sync/Blizzard/mk-configure_v5] tree ./result/nix/
./result/nix/ [error opening dir]

0 directories, 0 files
[mk-configure-mono:owner@nixos:~/sync/Blizzard/mk-configure_v5] 
