nix build
nix develop
cd ~/sync/Blizzard/mk-configure && mkcmake all
which mkcmake
which mkdep
ls ~/sync/Blizzard/mk-configure_v6/result/bin

[owner@nixos:~/sync/Blizzard/mk-configure_v6]$ nix build
nix develop
mk-configure + bmkdep development shell ready!
[mk-configure-mono:owner@nixos:~/sync/Blizzard/mk-configure_v6] cd ~/sync/Blizzard/mk-configure && mkcmake all
which mkcmake
which mkdep
==================================================
all ===> scripts
==================================================
all ===> builtins
==================================================
all ===> examples/helpers
==================================================
all ===> mk
mkdep(1) cannot be found
*** Error code 1

Stop.
bmake[2]: stopped making "all" in /home/owner/sync/Blizzard/mk-configure/mk
*** Error code 1

Stop.
bmake[1]: stopped making "all" in /home/owner/sync/Blizzard/mk-configure
*** Error code 1

Stop.
bmake: stopped making "all" in /home/owner/sync/Blizzard/mk-configure
/nix/store/5mq7yl25ga8vyd11j1nfdfv5zxa7zq4s-mk-configure-f3dd0ad13679f06570ca887516c4d7f1e785469c/bin/mkcmake
which: no mkdep in (/nix/store/sz15z7hh6c2dycdbh1h45shh8bvxda88-bash-interactive-5.3p9/bin:/nix/store/5mq7yl25ga8vyd11j1nfdfv5zxa7zq4s-mk-configure-f3dd0ad13679f06570ca887516c4d7f1e785469c/bin:/nix/store/ci60nv6ngvz78v74712c011kcbr76zn4-bmkdep-f76db982a71c817423e0609ec9625e351e9e9e7d/bin:/nix/store/l7li8yhzbsr1v682slc849ydx4qv66ms-pkg-config-wrapper-0.29.2/bin:/nix/store/rjldc9vyg065shsz7bvpy4rfpa9qah29-patchelf-0.15.2/bin:/nix/store/4w4z93hx82gfdnjpxphjkhblfcqyq63n-bmake-20260313/bin:/nix/store/ajn0kkwki1k2f4dp7azng3srmw78pn2r-makedepend-1.0.9/bin:/nix/store/sf94i342x394ls6l9pfzrvh1f6dmhqzm-gcc-wrapper-15.2.0/bin:/nix/store/06i01ld530x5pnhy1wmz5rbs8491s9x8-gcc-15.2.0/bin:/nix/store/0j5ip7zy01qxi64gkkjzsr4shkrzkj3r-glibc-2.42-67-bin/bin:/nix/store/5kcc5rnag7yymmsr6yqs7993xpdqs62w-coreutils-9.11/bin:/nix/store/b0i9milf5knm3lqjjnzwdvn0crjh9r5g-binutils-wrapper-2.46/bin:/nix/store/0ak73m7gnlzzn70shp4z620bgn7k638k-binutils-2.46/bin:/nix/store/5kcc5rnag7yymmsr6yqs7993xpdqs62w-coreutils-9.11/bin:/nix/store/i6hlg4ss9m53gvh8jqp0zgac67x6mblg-findutils-4.10.0/bin:/nix/store/lxzzxlm3dis6as7y13l13ywb0nh1c3h8-diffutils-3.12/bin:/nix/store/c3pj1yrqn88cc8zkr5hywmvy15m0r6c9-gnused-4.10/bin:/nix/store/q0n8l9xz66pbpj37fxk5vid6dsfpx5vb-gnugrep-3.12/bin:/nix/store/piwn8xr8m88c6cbn0mqiya9r8848712a-gawk-5.4.1/bin:/nix/store/ycq9wncmd0lgblr87kjlcfvvs5fgivy1-gnutar-1.35/bin:/nix/store/nmrwsdjdncfn7n9drhjfah9pp0c80lav-gzip-1.14/bin:/nix/store/gyddj2bjg2ffiyg0m3a7swygpgvhf9cs-bzip2-1.0.8-bin/bin:/nix/store/rpw665canl7mir8asgc3is4bnyz7brpy-gnumake-4.4.1/bin:/nix/store/1sr8rmx4v0v994lkbzhwc1f0qr1gxxs9-bash-5.3p9/bin:/nix/store/fkfcmqrx3wjaida4czrgxr6ai3w41cq8-patch-2.8/bin:/nix/store/86d5mj51h7cvx49dqnvsrazx3s9zffrn-xz-5.8.3-bin/bin:/nix/store/6kmx9yvcr998bfv0f349n7ylrqw5rmm6-file-5.47/bin:/run/wrappers/bin:/home/owner/.nix-profile/bin:/nix/profile/bin:/home/owner/.local/state/nix/profile/bin:/etc/profiles/per-user/owner/bin:/nix/var/nix/profiles/default/bin:/run/current-system/sw/bin)
[mk-configure-mono:owner@nixos:~/sync/Blizzard/mk-configure] ls ~/sync/Blizzard/mk-configure_v6/result/bin
bmkdep              mkc_check_funclib  mkc_check_version      mkc_which
mkc_check_compiler  mkc_check_header   mkc_compiler_settings
mkc_check_custom    mkc_check_prog     mkc_install
mkc_check_decl      mkc_check_sizeof   mkcmake
