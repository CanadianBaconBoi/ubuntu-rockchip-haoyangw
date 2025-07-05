# shellcheck shell=bash

# Build Ubuntu MATE image on top of default Ubuntu config
source $(dirname "${BASH_SOURCE[0]}")/desktop.sh
# Distinguish MATE flavor from others without causing livecd-rootfs
#   to build MATE image
export UBUNTU_FLAVOR=mate
