#!/bin/bash

function build_kernel () { 
  _chroot dnf -y update kernel

  local KERNEL_VERSION=$(_chroot dnf list installed kernel | tail -n 1 | sed -E 's/ +/ /g' | cut -d' ' -f2)
  local KERNEL_ARCH=$(_chroot dnf list installed kernel | tail -n 1 | sed -E 's/ +/ /g' | cut -d' ' -f1 | cut -d'.' -f2)

  cp ${CONFIG_ROOTFS_PATH}/boot/vmlinuz-${KERNEL_VERSION}.${KERNEL_ARCH} ${CONFIG_PXE_TFTP_ROOT}/vmlinuz
  return 0
}

add_target build kernel
