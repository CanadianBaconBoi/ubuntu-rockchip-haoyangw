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

function remove_gnome() {
	# Metapackage for given flavor's desktop, e.g. 'ubuntu-mate-desktop' for MATE flavor
	flavor_desktop="$1"

	if [ -n "${UBUNTU_FLAVOR}" ] && [ "${UBUNTU_FLAVOR}" != "ubuntu" ]; then
		mkdir -p config/hooks
		cat <<-EOF > config/hooks/999-remove-gnome.chroot
			#!/bin/bash
			set -e

			function get_deps_of() {
				pkg="\$1"
				# 'Depends' or 'Recommends'
				dep_type="\$2"
				# Output a list of all 'Depends' packages for given input package
				apt-cache depends "\$pkg" 2>/dev/null | \\
					grep -E "^\\s+\${dep_type}:" | \\
					awk '{print \$2}' | \\
					grep -vE '^<.*>\$'
			}

			# List of Ubuntu (GNOME) desktop dependencies
			gnome_deps=\$((get_deps_of ubuntu-desktop Depends; get_deps_of ubuntu-desktop-minimal Depends;) | sort -u)

			# List of Ubuntu flavor's desktop dependencies
			flavor_deps=\$((get_deps_of "$flavor_desktop" Depends; get_deps_of "$flavor_desktop" Recommends) | sort -u)

			# Exclude flavor dependencies from list of GNOME dependencies to remove
			deps_to_remove=\$(comm -23 <(echo "\$gnome_deps") <(echo "\$flavor_deps"))

			if [ -n "\$deps_to_remove" ]; then
				# Remove GNOME package dependencies
				echo "Removing GNOME package dependencies..."
				echo "\$deps_to_remove" | xargs apt-get purge --auto-remove --yes || true

				# Reconfigure lightdm display manager after removing gdm3
				dpkg-reconfigure -fnoninteractive lightdm
			fi

			# Remove Ubuntu GNOME metapackages
			apt-get purge --auto-remove --yes ubuntu-desktop ubuntu-desktop-minimal || true

			
		EOF
		chmod +x config/hooks/999-remove-gnome.chroot
	fi
}

pushd .

tmp_dir=$(mktemp -d)
cd "${tmp_dir}" || exit 1

# Clone the livecd rootfs fork
if [ "${PROJECT}" == "ubuntu-mate" ]; then
	git clone -b noble-mate https://github.com/haoyangw/livecd-rootfs.git livecd-rootfs
else
	git clone -b main https://github.com/haoyangw/livecd-rootfs.git livecd-rootfs
fi
cd livecd-rootfs || exit 1

# Install build deps
apt-get update
apt-get build-dep . -y

# Build the package
dpkg-buildpackage -us -uc

# Install the custom livecd rootfs package
apt-get install ../livecd-rootfs_*.deb --assume-yes --allow-downgrades --allow-change-held-packages
dpkg -i ../livecd-rootfs_*.deb
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
    # Pin my U-Boot and RKAIQ fork to support my chosen boards
    (
        echo ""
        echo "Package: u-boot-* camera-engine-rkaiq-rk35*"
        echo "Pin: release o=LP-PPA-haoyangw-rockchip-bsp"
        echo "Pin-Priority: 1001"
    ) >> config/archives/extra-ppas.pref.chroot
fi

if [ "${SUITE}" == "jammy" ]; then
    if [ "${PROJECT}" == "ubuntu-mate" ]; then
        # Pin ubiquity packages on MATE flavor to prevent removal of 'cryptsetup'
        # package(and hence 'ubuntu-mate-desktop') on Ubuntu 22.04
        (
            echo ""
            echo "Package: oem-config* ubiquity*"
            echo "Pin: release o=LP-PPA-haoyangw-rockchip-bsp"
            echo "Pin-Priority: 1001"
        ) >> config/archives/extra-ppas.pref.chroot
    fi
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

if [ "${PROJECT}" == "ubuntu-mate" ] && [ "${SUITE}" == "jammy" ]; then
	# Install MATE desktop's snap packages(removed in Ubuntu 24.04)
	(
		echo "software-boutique/classic=stable"
		echo "ubuntu-mate-welcome/classic=stable"
	) >> config/seeded-snaps
fi

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
	fi
elif [ "${PROJECT}" == "ubuntu-mate" ]; then
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
