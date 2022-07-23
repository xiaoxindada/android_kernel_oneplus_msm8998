#!/bin/bash

LOCALDIR=$(cd "$(dirname $0)" && pwd)
cd $LOCALDIR
anykernel_name="AnyKernel3"
defconfig="sagit_defconfig"

case "$1" in
"-c" | "--clean")
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
          CROSS_COMPILE_ARM32=arm-linux-androideabi- \
          CROSS_COMPILE_COMPAT=arm-linux-androideabi-"

    export PATH="${LOCALDIR}/clang/bin:${LOCALDIR}/gcc4.9/bin:${LOCALDIR}/gcc4.9_32/bin:${PATH}" # clang
    START_TIME=$(date +%s)
    make $args $defconfig
    make mrproper
    make -j12 $args
    if [ $? = 0 ]; then
        echo -e "\033[32m [INFO] Build successfully \033[0m"
        END_TIME=$(date +%s)
        EXEC_TIME=$((${END_TIME} - ${START_TIME}))
        EXEC_TIME=$((${EXEC_TIME} / 60))
        echo "Runtime is: ${EXEC_TIME} min"
    else
        echo -e "\033[31m [ERROR] Build filed \033[0m"
        exit 1
    fi
}

#clone_clang
#clone_gcc
build_with_clang
