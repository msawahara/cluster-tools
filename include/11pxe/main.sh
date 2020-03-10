#!/bin/bash

function prepare_pxe () {
  dnf -y install dnsmasq syslinux
  systemctl enable --now dnsmasq
}

function check_pxe () {
  systemctl status dnsmasq > /dev/null 2>&1
  if [ $? -ne 0 ]; then
    echo "Error: (pxe) dnsmasq is not running." >&2
    return 1
  fi

  return 0
}

function config_pxe ()
{
  CONFIG_PXE_TFTP_ROOT=${CONFIG_PXE_TFTP_ROOT:-"${CONFIG_BASE_PATH}/tftp"}

  _dialog RET --mixedform "Network boot" 20 80 10 \
    "TFTP root path" 1 0 "${CONFIG_PXE_TFTP_ROOT}" 1 32 40 0 0 \
    "DHCP range (start,end,time)" 2 0 "${CONFIG_PXE_DHCP_RANGE}" 2 32 40 0 0

  if [ $? -ne 0 ]; then
    return
  fi

  local LIST=($(echo "$RET" | xargs))
  CONFIG_PXE_TFTP_ROOT=${LIST[0]}
  CONFIG_PXE_DHCP_RANGE=${LIST[1]}
}

function config_pxe_description () {
  echo "Network boot"
}

function config_pxe_save () {
  config_update "CONFIG_PXE_TFTP_ROOT" "${CONFIG_PXE_TFTP_ROOT}"
  config_update "CONFIG_PXE_DHCP_RANGE" "${CONFIG_PXE_DHCP_RANGE}"
}

function build_pxe () {
  mkdir -p ${CONFIG_PXE_TFTP_ROOT}/pxelinux.cfg

  cp /usr/share/syslinux/{pxelinux.0,ldlinux.c32,menu.c32,libutil.c32} ${CONFIG_PXE_TFTP_ROOT}

  # Dnsmasq
  cat > /etc/dnsmasq.d/tftp.conf << EOS
# dhcp
listen-address=${CONFIG_NETWORK_IPADDR%/*}
dhcp-range=${CONFIG_PXE_DHCP_RANGE}

# tftp
enable-tftp
tftp-root=${CONFIG_PXE_TFTP_ROOT}
dhcp-boot=pxelinux.0
EOS

  cat > ${CONFIG_PXE_TFTP_ROOT}/pxelinux.cfg/default << EOS
UI menu.c32
PROMPT 0

TIMEOUT 50
DEFAULT linux

LABEL linux
        MENU LABEL Linux
        LINUX vmlinuz
        APPEND root=nfs:${CONFIG_NETWORK_IPADDR%/*}:${CONFIG_ROOTFS_PATH},vers=4.2 ro
        INITRD initramfs-pxeboot.img
EOS

  systemctl restart dnsmasq

  return 0
}

# prepare target
add_target prepare pxe
add_target check pxe
add_target config pxe
add_target build pxe
