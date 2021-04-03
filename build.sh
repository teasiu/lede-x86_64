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

# clone feeds
cd "$proj_dir/openwrt"
./scripts/feeds update -a

# modify firmware-info
cd "$proj_dir/openwrt"
Compile_Date=$(date +%Y%m%d)
AB_Firmware_Info=package/base-files/files/etc/openwrt_info
Version_File="package/lean/default-settings/files/zzz-default-settings"
Old_Version="$(egrep -o "R[0-9]+\.[0-9]+\.[0-9]+" ${Version_File})"
Openwrt_Version="${Old_Version}-${Compile_Date}"
Owner_Repo="https://github.com/teasiu/lede-x86_64"
TARGET_PROFILE="x86_64"
Firmware_Type="img.gz"
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
cd "$proj_dir"
cp -a artifact/openwrt-x86-64-generic-squashfs-combined.img.gz openwrt/bin/AutoBuild-${TARGET_PROFILE}-${Openwrt_Version}-Legacy.${Firmware_Type}
cp -a artifact/openwrt-x86-64-generic-squashfs-combined-efi.img.gz openwrt/bin/AutoBuild-${TARGET_PROFILE}-${Openwrt_Version}-UEFI.${Firmware_Type}
cp -a artifact/openwrt-x86-64-generic-squashfs-combined.vmdk openwrt/bin/AutoBuild-${TARGET_PROFILE}-${Openwrt_Version}-Legacy.vmdk
cp -a artifact/openwrt-x86-64-generic-squashfs-combined-efi.vmdk openwrt/bin/AutoBuild-${TARGET_PROFILE}-${Openwrt_Version}-UEFI.vmdk
rm -rf openwrt/bin/targets
rm -rf openwrt/bin/packages
cd "$proj_dir/openwrt/bin"
Legacy_Firmware="AutoBuild-${TARGET_PROFILE}-${Openwrt_Version}-Legacy.${Firmware_Type}"
EFI_Firmware="AutoBuild-${TARGET_PROFILE}-${Openwrt_Version}-UEFI.${Firmware_Type}"
AutoBuild_Firmware="AutoBuild-${TARGET_PROFILE}-${Openwrt_Version}"
if [ -f "${Legacy_Firmware}" ];then
			_MD5=$(md5sum ${Legacy_Firmware} | cut -d ' ' -f1)
			_SHA256=$(sha256sum ${Legacy_Firmware} | cut -d ' ' -f1)
			touch ${AutoBuild_Firmware}.detail
			echo -e "\nMD5:${_MD5}\nSHA256:${_SHA256}" > ${AutoBuild_Firmware}-Legacy.detail
			echo "Legacy Firmware is detected !"
fi
if [ -f "${EFI_Firmware}" ];then
			_MD5=$(md5sum ${EFI_Firmware} | cut -d ' ' -f1)
			_SHA256=$(sha256sum ${EFI_Firmware} | cut -d ' ' -f1)
			touch ${AutoBuild_Firmware}-UEFI.detail
			echo -e "\nMD5:${_MD5}\nSHA256:${_SHA256}" > ${AutoBuild_Firmware}-UEFI.detail
			echo "UEFI Firmware is detected !"
fi
