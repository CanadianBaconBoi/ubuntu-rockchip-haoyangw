#!/bin/bash

set -eE 
trap 'echo Error: in $0 on line $LINENO' ERR

if [ "$(id -u)" -ne 0 ]; then 
    echo "Please run as root"
    exit 1
fi

cd "$(dirname -- "$(readlink -f -- "$0")")" && cd ..
mkdir -p build && cd build

if [[ -z ${SUITE} ]]; then
    echo "Error: SUITE is not set"
    exit 1
fi

# shellcheck source=/dev/null
source "../config/suites/${SUITE}.sh"

if [[ -z ${FLAVOR} ]]; then
    echo "Error: FLAVOR is not set"
    exit 1
fi

# shellcheck source=/dev/null
source "../config/flavors/${FLAVOR}.sh"

if [[ -f ubuntu-${RELASE_VERSION}-preinstalled-${FLAVOR}-arm64.rootfs.tar.xz ]]; then
    exit 0
fi

pushd .

tmp_dir=$(mktemp -d)
cd "${tmp_dir}" || exit 1

# Download the custom livecd rootfs package from my latest livecd-rootfs release
wget -O livecd-rootfs_24.04.56_arm64.deb \
        https://github.com/haoyangw/livecd-rootfs/releases/download/24.04.56/livecd-rootfs_24.04.56_arm64.deb

# Install the custom livecd rootfs package
apt-get install ./livecd-rootfs_*.deb --assume-yes --allow-downgrades --allow-change-held-packages
dpkg -i ./livecd-rootfs_*.deb
apt-mark hold livecd-rootfs

rm -rf "${tmp_dir}"

popd

mkdir -p live-build && cd live-build

# Query the system to locate livecd-rootfs auto script installation path
cp -r "$(dpkg -L livecd-rootfs | grep "auto$")" auto

set +e

export ARCH=arm64
export IMAGEFORMAT=none
export IMAGE_TARGETS=none

# Populate the configuration directory for live build
lb config \
    --architecture arm64 \
    --bootstrap-qemu-arch arm64 \
    --bootstrap-qemu-static /usr/bin/qemu-aarch64-static \
    --archive-areas "main restricted universe multiverse" \
    --parent-archive-areas "main restricted universe multiverse" \
    --mirror-bootstrap "http://ports.ubuntu.com" \
    --parent-mirror-bootstrap "http://ports.ubuntu.com" \
    --mirror-chroot-security "http://ports.ubuntu.com" \
    --parent-mirror-chroot-security "http://ports.ubuntu.com" \
    --mirror-binary-security "http://ports.ubuntu.com" \
    --parent-mirror-binary-security "http://ports.ubuntu.com" \
    --mirror-binary "http://ports.ubuntu.com" \
    --parent-mirror-binary "http://ports.ubuntu.com" \
    --keyring-packages ubuntu-keyring \
    --linux-flavours "${KERNEL_FLAVOR}"

if [ "${SUITE}" == "noble" ] || [ "${SUITE}" == "jammy" ]; then
    # Pin rockchip package archives
    (
        echo "Package: *"
        echo "Pin: release o=LP-PPA-jjriek-rockchip"
        echo "Pin-Priority: 1001"
        echo ""
        echo "Package: *"
        echo "Pin: release o=LP-PPA-jjriek-rockchip-multimedia"
        echo "Pin-Priority: 1001"
    ) > config/archives/extra-ppas.pref.chroot
    # Pin ubuntu meta packages for Rockchip
    (
        echo ""
        echo "Package: ubuntu-*-rockchip"
        echo "Pin: release o=LP-PPA-haoyangw-rockchip-bsp"
        echo "Pin-Priority: 1001"
    ) >> config/archives/extra-ppas.pref.chroot
fi

if [ "${SUITE}" == "noble" ]; then
    # Pin custom kernel packages from my PPA
    (
        echo ""
        echo "Package: aicrf-test aic8800-* linux-rockchip* linux-*-rockchip"
        echo "Pin: release o=LP-PPA-haoyangw-rockchip-bsp"
        echo "Pin-Priority: 1001"
    ) >> config/archives/extra-ppas.pref.chroot

    # Ignore custom ubiquity package (mistake i made, uploaded to wrong ppa)
    (
        echo "Package: oem-*"
        echo "Pin: release o=LP-PPA-jjriek-rockchip-multimedia"
        echo "Pin-Priority: -1"
        echo ""
        echo "Package: ubiquity*"
        echo "Pin: release o=LP-PPA-jjriek-rockchip-multimedia"
        echo "Pin-Priority: -1"

    ) > config/archives/extra-ppas-ignore.pref.chroot

    # Also ignore Joshua-Riek's dkms and Linux kernel packages to switch
    #  to my custom kernel on Ubuntu Noble
    (
        echo ""
        echo "Package: aicrf-test aic8800-*"
        echo "Pin: release o=LP-PPA-jjriek-rockchip"
        echo "Pin-Priority: -1"
        echo ""
        echo "Package: linux-rockchip* linux-*-rockchip"
        echo "Pin: release o=LP-PPA-jjriek-rockchip"
        echo "Pin-Priority: -1"

    ) >> config/archives/extra-ppas-ignore.pref.chroot
fi

# Snap packages to install
(
    echo "snapd/classic=stable"
    echo "core22/classic=stable"
    echo "lxd/classic=stable"
) > config/seeded-snaps

# Generic packages to install
echo "software-properties-common" > config/package-lists/my.list.chroot

if [ "${PROJECT}" == "ubuntu" ]; then
    if [ -z "${UBUNTU_FLAVOR}" ] || [ "${UBUNTU_FLAVOR}" == "ubuntu" ]; then
        # Specific packages to install for ubuntu desktop
        (
            echo "ubuntu-desktop-rockchip"
            echo "oem-config-gtk"
            echo "ubiquity-frontend-gtk"
            echo "ubiquity-slideshow-ubuntu"
            echo "localechooser-data"
        ) >> config/package-lists/my.list.chroot
    elif [ "${UBUNTU_FLAVOR}" == "mate" ]; then
        # Specific packages to install for ubuntu mate desktop
        (
            echo "ubuntu-mate-desktop-rockchip"
            echo "oem-config-gtk"
            echo "ubiquity-frontend-gtk"
            echo "ubiquity-slideshow-ubuntu-mate"
            echo "ubiquity-ubuntu-artwork"
            echo "oem-config-slideshow-ubuntu-mate"
            echo "localechooser-data"
        ) >> config/package-lists/my.list.chroot
else
    # Specific packages to install for ubuntu server
    echo "ubuntu-server-rockchip" >> config/package-lists/my.list.chroot
fi

# Build the rootfs
lb build

set -eE 

# Tar the entire rootfs
(cd chroot/ &&  tar -p -c --sort=name --xattrs ./*) | xz -3 -T0 > "ubuntu-${RELASE_VERSION}-preinstalled-${FLAVOR}-arm64.rootfs.tar.xz"
mv "ubuntu-${RELASE_VERSION}-preinstalled-${FLAVOR}-arm64.rootfs.tar.xz" ../
