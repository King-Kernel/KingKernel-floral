# Interactive helpers for Android kernel development
# Copyright (C) 2019 Danny Lin <danny@kdrag0n.dev>
# Copyright (C) 2019 kingbri <bdashore3@gmail.com>
#
# This script must be *sourced* from a Bourne-compatible shell in order to
# function. Nothing will happen if you execute it.
#
# Source a compiler-specific setup script for proper functionality. This is
# only a base script and does not suffice for kernel building without the
# flags that compiler-specific scripts append to kmake_flags.
#


#### CONFIGURATION ####

# Kernel name
kernel_name="KingKernel"

# Defconfig name
defconfig="king_defconfig"

# Target architecture
arch="arm64"

# Base kernel compile flags (extended by compiler setup script)
kmake_flags=(
	-j"$(nproc --all)"
	ARCH="$arch"
	O="out"
)

# Target device name to use in flashable package names
device_name="floral"

zimage_dir="out/arch/arm64/boot"

# Initialize kernel
function init_kernel() {
    git submodule update --init
}

# Reset the current config to the committed defconfig
function mc() {
	kmake "$defconfig"
}

# Open an interactive config editor
function cf() {
	kmake nconfig
}

# Edit the raw text config
function ec() {
	"${EDITOR:-vim}" "$kroot/out/.config"
}

# Get kernel repository root for later use
kroot="$PWD/$(dirname "$0")"

# Show an informational message
function msg() {
    echo -e "\e[1;32m$1\e[0m"
}

# Go to the root of the kernel repository repository
function croot() {
	cd "$kroot"
}

# Get the version of Clang in an user-friendly form
function get_clang_version() {
	"$1" --version | head -n 1 | perl -pe 's/\((?:http|git).*?\)//gs' | sed -e 's/  */ /g' -e 's/[[:space:]]*$//' -e 's/^.*clang/clang/'
}

# Get the version of GCC in an user-friendly form
function get_gcc_version() {
	"$1" --version | head -n 1 | cut -d'(' -f2 | tr -d ')' | sed -e 's/[[:space:]]*$//'
}


#### COMPILATION ####

# Make wrapper for kernel compilation
function kmake() {
	make "${kmake_flags[@]}" "$@"
}

# Create a zipfile 
function mkzip() {
    echo "Removing old kernel files"
    echo " "
    echo "Copying kernel image"
    echo " "
    cp out/arch/arm64/boot/Image.lz4 flasher/Image.lz4
    cp out/arch/arm64/boot/dtbo.img flasher/dtbo.img
    cp out/arch/arm64/boot/dts/google/qcom-base/sm8150-v2.dtb flasher/sm8150-v2.dtb
    read -p 'Version number: ' version
    zipname="KingKernel_floral_v$version.zip"
    echo " "
    cd flasher
    echo "Creating zipfile with name $zipname, please wait..."
    zip -r "$zipname" *
    cd ../
    mkdir -p out/flasher
    mv flasher/$zipname out/flasher/$zipname
    echo "Zip successfuly created"
    echo " "
    echo "Your zip is stored in out/flasher/$zipname"
}

# Push to stable release repository
function push_to_stable() {
    # Variable for y/n when asking to push
    local choice
    
    if [ ! -d "$HOME/$rel_folder" ]; then
        echo "Releases repo doesn't exist! Cloning..."
        git clone git@github.com:King-Kernel/KingKernel-Releases.git $HOME/KingKernel-Releases
    fi;
    echo "Copying zipfile..."
    cd $HOME/$rel_folder
    git checkout floral
    cp $HOME/$ksource/out/flasher/$zipname $HOME/$rel_folder/$zipname
    while true; do
        read -p 'Are you sure you want to push? (y or n): ' choice
        if [ "$choice" == "y" ]; then
            git add . && git commit -m "Release $version" -s
            git push
            break
        elif [ "$choice" == "n" ]; then
            echo "aborting..."
            break
        else
            echo "please input either y or n!"
        fi;
    done;
}

function get_sha() {
    sha1sum "out/flasher/$zipname" | awk '{ print $1 }'
}

function make_boot {
    mkdir -p out/images
    read -p 'Version number: ' version
    echo "Creating boot.img"
    ./scripts/mkbootimg/mkbootimg.py --kernel "$zimage_dir/Image.lz4-dtb" --ramdisk "boot-files/ramdisk" --dtb "$zimage_dir/dts/google/qcom-base/sm8150-v2.dtb" --cmdline 'console=ttyMSM0,115200n8 androidboot.console=ttyMSM0 printk.devkmsg=on msm_rtb.filter=0x237 ehci-hcd.park=3 service_locator.enable=1 androidboot.memcg=1 cgroup.memory=nokmem usbcore.autosuspend=7 androidboot.usbcontroller=a600000.dwc3 swiotlb=2048 androidboot.boot_devices=soc/1d84000.ufshc buildvariant=user' --header_version 2 -o "out/images/KingKernel-$version.img"
    echo "Success! Your file is stored in out/images/KingKernel-$version.img"
}