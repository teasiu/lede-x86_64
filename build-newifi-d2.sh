#!/bin/bash
#
# This is free software, license use GPLv3.
#
# Copyright (c) 2021, teasiu
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

# obtain feed list
cd "$proj_dir/openwrt"
feed_list=$(awk '/^src-git/ { print $2 }' feeds.conf.default)

# clone feeds
cd "$proj_dir/openwrt"
./scripts/feeds update -a

# patch feeds
for feed in $feed_list; do
  [ -d "$proj_dir/patches/$feed" ] &&
    {
      cd "$proj_dir/openwrt/feeds/$feed"
      cat "$proj_dir/patches/$feed"/*.patch | patch -p1
    }
done

# modify firmware-info
cd "$proj_dir/openwrt"
Compile_Date=$(date +%Y%m%d)
AB_Firmware_Info=package/base-files/files/etc/openwrt_info
Version_File="package/lean/default-settings/files/zzz-default-settings"
Old_Version="$(egrep -o "R[0-9]+\.[0-9]+\.[0-9]+" ${Version_File})"
Openwrt_Version="${Old_Version}-${Compile_Date}"
Owner_Repo="https://github.com/teasiu/lede-x86_64"
TARGET_PROFILE="d-team_newifi-d2"
Firmware_Type="bin"
echo "${Openwrt_Version}" > ${AB_Firmware_Info}
echo "${Owner_Repo}" >> ${AB_Firmware_Info}
echo "${TARGET_PROFILE}" >> ${AB_Firmware_Info}
echo "${Firmware_Type}" >> ${AB_Firmware_Info}

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
cat "$proj_dir/config-newifi-d2.seed" >.config
make defconfig

# build openwrt
cd "$proj_dir/openwrt"
make download -j8
make -j$(($(nproc) + 1)) || make -j1 V=s

# copy output files
cd "$proj_dir"
cp -a openwrt/bin/targets/*/* artifact
rm -rf artifact/packages

cd "$proj_dir"
cp -a artifact/openwrt-ramips-mt7621-d-team_newifi-d2-squashfs-sysupgrade.bin openwrt/bin/AutoBuild-${TARGET_PROFILE}-${Openwrt_Version}.${Firmware_Type}
rm -rf openwrt/bin/targets
rm -rf openwrt/bin/packages
cd "$proj_dir/openwrt/bin"
Legacy_Firmware="AutoBuild-${TARGET_PROFILE}-${Openwrt_Version}.${Firmware_Type}"
AutoBuild_Firmware="AutoBuild-${TARGET_PROFILE}-${Openwrt_Version}"
if [ -f "${Legacy_Firmware}" ];then
			_MD5=$(md5sum ${Legacy_Firmware} | cut -d ' ' -f1)
			_SHA256=$(sha256sum ${Legacy_Firmware} | cut -d ' ' -f1)
			touch ${AutoBuild_Firmware}.detail
			echo -e "\nMD5:${_MD5}\nSHA256:${_SHA256}" > ${AutoBuild_Firmware}.detail
			echo "Legacy Firmware is detected !"
fi
