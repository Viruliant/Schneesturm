
enter the environment:

```
cd /home/owner/sync/Blizzard/mk-configure_v6
nix build
nix develop
```

man 1 of the commands:
```
tree ./result/share/man
./result/share/man
├── man1
│   ├── mkc_check_compiler.1.gz
│   ├── mkc_check_custom.1.gz
│   ├── mkc_check_decl.1.gz
│   ├── mkc_check_funclib.1.gz
│   ├── mkc_check_header.1.gz
│   ├── mkc_check_prog.1.gz
│   ├── mkc_check_sizeof.1.gz
│   ├── mkc_check_version.1.gz
│   ├── mkc_compiler_settings.1.gz
│   ├── mkc_install.1.gz
│   ├── mkc_which.1.gz
│   └── mkcmake.1.gz
└── man7
    └── mk-configure.7.gz
```


```
tree ./result/nix/store/share/man

tree ./result/share/man



# nix log $(nix build --print-out-paths)
nix log "$(nix build --print-out-paths)" > build.log
```


`ls /run/current-system/sw/share/man/man1`

`tree ./result/nix/store/`