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
	if [ -n "${UBUNTU_FLAVOR}" ] && [ "${UBUNTU_FLAVOR}" != "ubuntu" ]; then
		mkdir -p config/hooks
		cat <<-EOF > config/hooks/999-remove-gnome.chroot
			#!/bin/sh
			set -e

			echo "Running hook to remove GNOME desktop packages..."

			# Remove Ubuntu GNOME metapackages and packages
			apt-get purge --yes apg baobab cloud-init dmz-cursor-theme eog evince \
				evince-common file-roller fprintd fwupd gamemode gamemode-daemon gdm3 \
				gir1.2-accountsservice-1.0 gir1.2-gck-2 gir1.2-gcr-4 gir1.2-gdesktopenums-3.0 \
				gir1.2-gdm-1.0 gir1.2-gmenu-3.0 gir1.2-gnomeautoar-0.1 gir1.2-gnomebg-4.0 \
				gir1.2-gnomebluetooth-3.0 gir1.2-gnomedesktop-3.0 gir1.2-gnomedesktop-4.0 \
				gir1.2-ibus-1.0 gir1.2-javascriptcoregtk-6.0 gir1.2-mutter-14 gir1.2-nma4-1.0 \
				gir1.2-rsvg-2.0 gir1.2-totem-1.0 gir1.2-totemplparser-1.0 gir1.2-upowerglib-1.0 \
				gir1.2-webkit-6.0 gkbd-capplet gnome-bluetooth-3-common gnome-bluetooth-sendto \
				gnome-calculator gnome-calendar gnome-characters gnome-control-center \
				gnome-control-center-data gnome-font-viewer gnome-initial-setup gnome-logs \
				gnome-online-accounts gnome-power-manager gnome-remote-desktop \
				gnome-session-bin gnome-session-common gnome-settings-daemon \
				gnome-settings-daemon-common gnome-shell gnome-shell-common \
				gnome-shell-extension-appindicator gnome-shell-extension-desktop-icons-ng \
				gnome-shell-extension-ubuntu-dock gnome-shell-extension-ubuntu-tiling-assistant \
				gnome-snapshot gnome-startup-applications gnome-system-monitor gnome-terminal \
				gnome-terminal-data gnome-text-editor gnome-user-docs grilo-plugins-0.3-base \
				gsettings-ubuntu-schemas gstreamer1.0-alsa gstreamer1.0-libcamera \
				gstreamer1.0-packagekit gstreamer1.0-plugins-base-apps gstreamer1.0-tools ibus \
				ibus-data ibus-gtk ibus-gtk3 ibus-gtk4 ibus-table libatk-adaptor \
				libavahi-ui-gtk3-0 libcamera0.2 libcolord-gtk4-1t64 libcue2 \
				libedataserverui4-1.0-0t64 libeditorconfig0 libei1 libeis1 libevdocument3-4t64 \
				libevview3-3t64 libfprint-2-2 libfprint-2-tod1 libfreerdp-client3-3 \
				libfreerdp-server3-3 libfreerdp3-3 libgamemode0 libgamemodeauto0 libgdm1 \
				libgnome-bg-4-2t64 libgnome-bluetooth-3.0-13 libgnome-bluetooth-ui-3.0-13 \
				libgnome-rr-4-2t64 libgnomekbd-common libgnomekbd8 libgoa-backend-1.0-2 \
				libgom-1.0-0t64 libgsf-1-114 libgsf-1-common libgsound0t64 libgtksourceview-5-0 \
				libgtksourceview-5-common libgupnp-av-1.0-3 libgupnp-dlna-2.0-4 libibus-1.0-5 \
				libinih1 libjavascriptcoregtk-6.0-1 liblttng-ust-common1t64 \
				liblttng-ust-ctl5t64 liblttng-ust1t64 libmalcontent-0-0 libmediaart-2.0-0 \
				libmutter-14-0 libnautilus-extension4 libpam-fprintd libportal-gtk4-1 \
				librygel-core-2.8-0 librygel-db-2.8-0 librygel-renderer-2.8-0 \
				librygel-server-2.8-0 libsysmetrics1 libtotem0 libtracker-sparql-3.0-0 \
				libtss2-esys-3.0.2-0t64 libtss2-mu-4.0.1-0t64 libtss2-rc0t64 libtss2-sys1t64 \
				libtss2-tcti-cmd0t64 libtss2-tcti-device0t64 libtss2-tcti-libtpms0t64 \
				libtss2-tcti-mssim0t64 libtss2-tcti-spi-helper0t64 libtss2-tcti-swtpm0t64 \
				libtss2-tctildr0t64 libvncclient1 libwebkitgtk-6.0-4 libwinpr3-3 libxcb-res0 \
				libxcb-xv0 mousetweaks mutter-common mutter-common-bin nautilus nautilus-data \
				nautilus-extension-gnome-terminal nautilus-sendto \
				network-manager-config-connectivity-ubuntu pipewire-alsa pipewire-audio \
				plymouth-theme-spinner power-profiles-daemon python3-ibus-1.0 remmina \
				remmina-common remmina-plugin-rdp remmina-plugin-secret remmina-plugin-vnc \
				rygel switcheroo-control systemd-oomd tecla thunderbird totem totem-common \
				totem-plugins tpm-udev tracker tracker-extract tracker-miner-fs ubuntu-desktop \
				ubuntu-desktop-minimal ubuntu-docs ubuntu-session ubuntu-settings \
				ubuntu-wallpapers ubuntu-wallpapers-noble xcursor-themes \
				xdg-desktop-portal-gnome xserver-xephyr xwayland yaru-theme-gnome-shell || true

			# Reconfigure lightdm display manager
			dpkg-reconfigure -fnoninteractive lightdm

			# Remove packages made redundant by removal of GNOME packages
			apt-get autoremove --yes || true
		EOF
		chmod +x config/hooks/999-remove-gnome.chroot
	fi
}

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

        # Remove GNOME packages installed by base Ubuntu config
        remove_gnome
    fi
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
