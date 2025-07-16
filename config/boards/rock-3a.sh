# shellcheck shell=bash

export BOARD_NAME="Radxa ROCK 3A"
export BOARD_MAKER="Radxa"
export BOARD_SOC="Rockchip RK3568"
export BOARD_CPU="ARM Cortex A55"
export UBOOT_PACKAGE="u-boot-turing-rk35xx"
export UBOOT_RULES_TARGET="rock-3a-rk3568"
export COMPATIBLE_SUITES=("noble")
export COMPATIBLE_FLAVORS=("server" "desktop" "mate")

function config_image_hook__rock-3a() {
    local rootfs="$1"
    local overlay="$2"
    local suite="$3"

    if [ "${suite}" == "jammy" ] || [ "${suite}" == "noble" ]; then
        # Install the rockchip camera engine
        chroot "${rootfs}" apt-get -y install camera-engine-rkaiq-rk3568

        # Fix Bluetooth not working with Radxa RTL8852BE WiFi + BT card
        cp "${overlay}/usr/lib/systemd/system/radxa-a8-bluetooth.service" "${rootfs}/usr/lib/systemd/system/radxa-a8-bluetooth.service"
        chroot "${rootfs}" systemctl enable radxa-a8-bluetooth
    fi

    return 0
}
