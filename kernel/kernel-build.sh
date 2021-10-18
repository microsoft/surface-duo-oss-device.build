#!/bin/bash
SCRIPTPATH=`cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd`
retval=0


#Borrowed from build/envsetup.sh
function gettop
{
    local TOPFILE=device_build/kernel/kernel.json
    if [ -n "$TOP" -a -f "$TOP/$TOPFILE" ] ; then
        # The following circumlocution ensures we remove symlinks from TOP.
        (cd $TOP; PWD= /bin/pwd)
    else
        if [ -f $TOPFILE ] ; then
            # The following circumlocution (repeated below as well) ensures
            # that we record the true directory name and not one that is
            # faked up with symlink names.
            PWD= /bin/pwd
        else
            local HERE=$PWD
            local T=
            while [ \( ! \( -f $TOPFILE \) \) -a \( $PWD != "/" \) ]; do
                \cd ..
                T=`PWD= /bin/pwd -P`
            done
            \cd $HERE
            if [ -f "$T/$TOPFILE" ]; then
                echo $T
            fi
        fi
    fi
}

INCREMENTAL=""
BUILD_PATH="/s"

POSITIONAL=()
while [[ $# -gt 0 ]]
do
key="$1"
    case $key in
        -c|--config)
        KERNCONFIG="$2"
        shift # past argument
        shift # past value
        ;;
        -tb|--target)
        TARGET_BUILD_VARIANT="$2"
        shift # past argument
        shift # past value
        ;;
        -ib|--incremental)
        INCREMENTAL="y"
        shift # past argument
        ;;
        -p|--path)
        BUILD_PATH="$2"
        shift # past argument
        shift # past value
        ;;
        *)    # unknown option
        POSITIONAL+=("$1") # save it in an array for later
        shift # past argument
        ;;
    esac
done
set -- "${POSITIONAL[@]}" # restore positional parameters

T=$(gettop)

echo -------------------------------------
echo device kernel-build.sh
echo -------------------------------------
echo T             = ${T}
echo KERNCONFIG    = ${KERNCONFIG}
echo BUILD PATH    = ${BUILD_PATH}

echo "> Generic Environment Setup"
export TARGET_BUILD_VARIANT=$TARGET_BUILD_VARIANT
export KERNEL_DIR=kernel/msm-5.4
export KERNEL_DEFCONFIG=$KERNCONFIG
export DEFCONFIG=vendor/$KERNEL_DEFCONFIG
export OUT_DIR=out/target/product/duo2/obj/kernel/msm-5.4
export MAKE_PATH=$BUILD_PATH/prebuilts/build-tools/linux-x86/bin/
export ARCH=arm64
export CROSS_COMPILE=$BUILD_PATH/prebuilts/gcc/linux-x86/aarch64/aarch64-linux-android-4.9/bin/aarch64-linux-android-
export KERNEL_MODULES_OUT=out/target/product/duo2/dlkm/lib/modules
export KERNEL_HEADERS_INSTALL=out/target/product/duo2/obj/kernel/msm-5.4/usr
export TARGET_PREBUILT_INT_KERNEL="out/target/product/duo2/obj/kernel/msm-5.4/arch/arm64/boot/Image"
export TARGET_INCLUDES="-I$BUILD_PATH/kernel/msm-5.4/include/uapi -I/usr/include -I/usr/include/x86_64-linux-gnu -I$BUILD_PATH/kernel/msm-5.4/include -L/usr/lib -L/usr/lib/x86_64-linux-gnu -fuse-ld=lld"
export TARGET_LINCLUDES="-L/usr/lib -L/usr/lib/x86_64-linux-gnu -fuse-ld=lld"
export VENDOR_KERNEL_MODULES_ARCHIVE=vendor_modules.zip
export VENDOR_RAMDISK_KERNEL_MODULES_ARCHIVE=vendor_ramdisk_modules.zip
case "$KERNEL_DEFCONFIG" in
	"lahaina-qgki-debug_defconfig")
	export VENDOR_RAMDISK_KERNEL_MODULES=`cat ${T}/device_build/kernel/kernel.json | jq -r '."lahaina-qgki-debug_defconfig"'.vendor_ramdisk_kernel_modules`
	;;
	"lahaina-gki_defconfig")
	export VENDOR_RAMDISK_KERNEL_MODULES=`cat ${T}/device_build/kernel/kernel.json | jq -r '."lahaina-gki_defconfig"'.vendor_ramdisk_kernel_modules`
	;;
	*)
	# use lahaina-qgki_defconfig as default
	export VENDOR_RAMDISK_KERNEL_MODULES=`cat ${T}/device_build/kernel/kernel.json | jq -r '."lahaina-qgki_defconfig"'.vendor_ramdisk_kernel_modules`
    esac
echo VENDOR_RAMDISK_KERNEL_MODULES: ${VENDOR_RAMDISK_KERNEL_MODULES}
export TARGET_PRODUCT=lahaina
export CLANG_TRIPLE=aarch64-linux-gnu-
export HOSTCC=$BUILD_PATH/prebuilts/clang/host/linux-x86/clang-r416183b/bin/clang
export HOSTAR=$BUILD_PATH/prebuilts/gcc/linux-x86/host/x86_64-linux-glibc2.17-4.8/bin/x86_64-linux-ar
export HOSTLD=$BUILD_PATH/prebuilts/gcc/linux-x86/host/x86_64-linux-glibc2.17-4.8/bin/x86_64-linux-ld
export LD=$BUILD_PATH/prebuilts/clang/host/linux-x86/clang-r416183b/bin/ld.lld

# makefile $(real_cc)
export REAL_CC="$BUILD_PATH/prebuilts/clang/host/linux-x86/clang-r416183b/bin/clang"

# makefile $(real_cc) plus $(TARGET_KERNEL_MAKE_ENV)
export TARGET_KERNEL_MAKE_ENV="
REAL_CC=$REAL_CC \
CLANG_TRIPLE=$CLANG_TRIPLE \
AR=$BUILD_PATH/prebuilts/clang/host/linux-x86/clang-r416183b/bin/llvm-ar \
LLVM_NM=$BUILD_PATH/prebuilts/clang/host/linux-x86/clang-r416183b/bin/llvm-nm \
LD=$LD \
NM=$BUILD_PATH/prebuilts/clang/host/linux-x86/clang-r416183b/bin/llvm-nm \
CONFIG_BUILD_ARM64_DT_OVERLAY=y \
HOSTCC=$HOSTCC \
HOSTAR=$HOSTAR \
HOSTLD=$HOSTLD \
"

# Removed dtc related binary requirements
# DTC_EXT=$BUILD_PATH/out/host/linux-x86/bin/dtc \
# DTC_OVERLAY_TEST_EXT=$BUILD_PATH/out/host/linux-x86/bin/ufdt_apply_overlay \

echo "> Create QC DT vendor symlink"
#Source: vendor/qcom/proprietary/prebuilt_HY11/vendor_links
declare -A symlinkList=(
    ["vendor/qcom/proprietary/devicetree"]="kernel/msm-5.4/arch/arm64/boot/dts/vendor"
    ["vendor/qcom/proprietary/display-devicetree/display"]="vendor/qcom/proprietary/devicetree/qcom/display"
    ["vendor/qcom/proprietary/display-devicetree/bindings"]="vendor/qcom/proprietary/devicetree/bindings/display/qcom"
    ["vendor/qcom/proprietary/camera-devicetree"]="vendor/qcom/proprietary/devicetree/qcom/camera"
)
for i in "${!symlinkList[@]}"
do
    echo ln -sfvT $(realpath --relative-to=$(dirname ${symlinkList[$i]}) $i) ${symlinkList[$i]}
    ln -sfvT $(realpath --relative-to=$(dirname ${symlinkList[$i]}) $i) ${symlinkList[$i]}
    retval=$?
    if [ $retval -ne 0 ]; then
        echo "Create symlink failed $retval"
        return $retval &>/dev/null || exit $retval
    fi
done

echo "> GKI Script - generate kernel .config"
KERN_OUT=$OUT_DIR $KERNEL_DIR/scripts/gki/generate_defconfig.sh $KERNEL_DEFCONFIG
retval=$?
if [ $retval -ne 0 ]; then
    echo "Generate .config failed $retval"
    return $retval &>/dev/null || exit $retval
fi

echo "> Build Kernel HEADERS, Kernel and modules"
HEADERS_INSTALL=0 device/qcom/kernelscripts/buildkernel.sh $TARGET_KERNEL_MAKE_ENV
retval=$?
if [ $retval -ne 0 ]; then
    echo "BUILD failed $retval"
    return $retval &>/dev/null || exit $retval
fi
