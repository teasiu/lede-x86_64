#!/bin/bash
#
# This is free software, license use GPLv3.
#
# Copyright (c) 2021, Chuck <fanck0605@qq.com>
#

set -eu

proj_dir=$(pwd)

# clone openwrt
cd "$proj_dir"
rm -rf openwrt
git clone https://github.com/coolsnowwolf/lede.git openwrt

# patch openwrt
cd "$proj_dir/openwrt"
cat "$proj_dir/patches"/*.patch | patch -p1
ln -sf ../../dl dl
# clone feeds
cd "$proj_dir/openwrt"
./scripts/feeds update -a

# addition packages
cd "$proj_dir/openwrt/package"
svn co https://github.com/teasiu/lede-other-apps/trunk/luci-app-aliddns custom/luci-app-aliddns
svn co https://github.com/teasiu/lede-other-apps/trunk/luci-app-autoupdate custom/luci-app-autoupdate
svn co https://github.com/teasiu/lede-other-apps/trunk/luci-app-admconf custom/luci-app-admconf
# luci-theme-argon
git clone -b 18.06 --depth 1 https://github.com/jerrykuku/luci-theme-argon.git custom/luci-theme-argon
git clone https://github.com/jerrykuku/luci-app-argon-config.git custom/luci-app-argon-config
git clone https://github.com/xiaorouji/openwrt-passwall passwall
# clean up packages
cd "$proj_dir/openwrt/package"
find . -name .svn -exec rm -rf {} +
find . -name .git -exec rm -rf {} +

# install packages
cd "$proj_dir/openwrt"
./scripts/feeds install -a

# customize configs
cd "$proj_dir/openwrt"
cat "$proj_dir/config.seed" >.config
make defconfig

# build openwrt
cd "$proj_dir/openwrt"
make download -j8
make -j$(($(nproc) + 1)) || make -j1 V=s

# copy output files
cd "$proj_dir"
cp -a openwrt/bin/targets/*/* artifact
rm -rf artifact/packages
