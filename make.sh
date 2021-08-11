#!/bin/bash

LOCALDIR=`cd "$( dirname $0 )" && pwd`
cd $LOCALDIR
anykernel_name="AnyKernel3"
defconfig="lineage_oneplus5_defconfig"

case "$1" in
  "-c"|"--clean")
    rm -rf out
    ;;
esac

rm -rf build.log

clone_clang() {
  rm -rf $LOCALDIR/clang
  git clone https://github.com/xiaoxindada/clang.git -b clang-r383902 $LOCALDIR/clang
}

clone_gcc() {
  rm -rf $LOCALDIR/gcc4.9
  rm -rf $LOCALDIR/gcc4.9_32
  git clone https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_aarch64_aarch64-linux-android-4.9.git -b lineage-18.1 $LOCALDIR/gcc4.9
  git clone https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_arm_arm-linux-androideabi-4.9.git -b lineage-18.1 $LOCALDIR/gcc4.9_32
}

build_with_clang() {
  local args="O=out \
          ARCH=arm64 \
          SUBARCH=arm64 \
          CC=clang \
          CLANG_TRIPLE=aarch64-linux-gnu- \
          CROSS_COMPILE=aarch64-linux-android- \
          CROSS_COMPILE_ARM32=arm-linux-androideabi-"

  export PATH="${LOCALDIR}/clang/bin:${LOCALDIR}/gcc4.9/bin:${LOCALDIR}/gcc4.9_32/bin:${PATH}" # clang
  START_TIME=`date +%s`
  make $args $defconfig
  make -j8 $args
  if [ $? = 0 ];then
    echo -e "\033[32m [INFO] Build successfully \033[0m"
    END_TIME=`date +%s`
    EXEC_TIME=$((${END_TIME} - ${START_TIME}))
    EXEC_TIME=$((${EXEC_TIME}/60))
    echo "Runtime is: ${EXEC_TIME} min"
  else
    echo -e "\033[31m [ERROR] Build filed \033[0m"
    exit 1
  fi
}

build_with_gcc() {
  local args="O=out \
          ARCH=arm64 \
          SUBARCH=arm64 \
          CROSS_COMPILE=aarch64-linux-android- \
          CROSS_COMPILE_ARM32=arm-linux-androideabi-"
  
  export PATH="${LOCALDIR}/gcc4.9/bin:${LOCALDIR}/gcc4.9_32/bin:${PATH}" # gcc
  START_TIME=`date +%s`
  make $args $defconfig
  make -j8 $args
  if [ $? = 0 ];then
    echo -e "\033[32m [INFO] Build successfully \033[0m"
    END_TIME=`date +%s`
    EXEC_TIME=$((${END_TIME} - ${START_TIME}))
    EXEC_TIME=$((${EXEC_TIME}/60))
    echo "Runtime is: ${EXEC_TIME} min"
  else
    echo -e "\033[31m [ERROR] Build filed \033[0m"
    exit 1
  fi
}

clone_anykernel() {
  rm -rf $LOCALDIR/$anykernel_name
  git clone https://github.com/xiaoxindada/AnyKernel_dumpling.git -b 11 $LOCALDIR/$anykernel_name
}

package_kernel() {
  local kernel_files="Image.gz Image.gz-dtb"
  for file in $kernel_files ;do
    cp out/arch/arm64/boot/$file $LOCALDIR/$anykernel_name/
  done
  cd $LOCALDIR/$anykernel_name
  rm -rf .git
  echo "Package kernel"
  zip -r kernel-tmp.zip ./*
  rm -rf $LOCALDIR/kernel.zip
  zipalign -p -v 4 kernel-tmp.zip $LOCALDIR/kernel.zip
  rm -rf kernel-tmp.zip
  cd $LOCALDIR
}

make_bootimage() {
  echo "make bootimage"
  local kernel="Image.gz-dtb"
  local ramdisk="ramdisk.cpio"
  local dtb="dtb"
  local pagesize="4096"
  local os_version="11.0.0"
  local os_patch_level="2021-07"
  local header_version="0"
  local base="0x00000000"
  local ramdisk_offset="0x01000000"
  local kernel_offset="0x00008000"
  local dtb_offset="0x01f00000"
  local second_offset="0x00f00000"
  local tags_offset="0x00000100"
  local cmdline="androidboot.hardware=qcom user_debug=31 msm_rtb.filter=0x37 ehci-hcd.park=3 service_locator.enable=1 swiotlb=2048 loop.max_part=7"
  local output="$LOCALDIR/out/arch/arm64/boot"
  local cpio="$LOCALDIR/prebuilts/cpio"
  local mkbootfs="$LOCALDIR/prebuilts/mkbootfs"
  local magiskboot="$LOCALDIR/prebuilts/magiskboot"
  local suffix=".gz"

  case $suffix in
    ".gz")
      local comp="gizp"
      local comp_cmd="gzip -n -f -9"
      ;;
  esac

  clean() {
      rm -rf "$output/dtb"
      rm -rf "$output/boot-new.img"
      rm -rf "$output/magiskboot"
      rm -rf "$output/$ramdisk"
      rm -rf "$output/$ramdisk$suffix"
  }
  clean

  cp $magiskboot $output/magiskboot
  find $output -name "*.dtb" -exec cat {} > $output/dtb \;
  cd $LOCALDIR/ramdisk
  ($mkbootfs ../ramdisk > $output/$ramdisk) || (find . | $cpio -R 0:0 -H newc -o > $output/$ramdisk) 2>/dev/null
  cd $LOCALDIR
  $output/magiskboot compress="$comp" "$output/$ramdisk" "$output/$ramdisk$suffix" || cat $output/$ramdisk | $comp_cmd > $output/$ramdisk$suffix
  [ $? != 0 ] && { echo -e "\033[31m [ERROR] ramdisk package filed! \033[0m"; clean; exit 1; }
  python $LOCALDIR/prebuilts/mkbootimg.py \
    --kernel "$output/$kernel" \
    --ramdisk "$output/$ramdisk$suffix" \
    --dtb "$output/$dtb" \
    --cmdline "$cmdline androidboot.selinux=permissive" \
    --base "$base" \
    --second_offset "$second_offset" \
    --kernel_offset "$kernel_offset" \
    --ramdisk_offset "$ramdisk_offset" \
    --dtb_offset "$dtb_offset" \
    --tags_offset "$tags_offset" \
    --pagesize "$pagesize" \
    --os_version "$os_version" \
    --os_patch_level "$os_patch_level" \
    --header_version "$header_version" \
    --output "$output/boot-new.img"
  [ $? != 0 ] && { echo -e "\033[31m [ERROR] Kernel package filed! \033[0m"; clean; exit 1; }
  echo "Make bootimage complete: $output/boot-new.img"
}

#clone_clang
#clone_gcc
#build_with_clang
build_with_gcc
clone_anykernel
package_kernel
make_bootimage
