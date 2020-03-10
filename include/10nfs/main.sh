#!/bin/bash

function prepare_nfs () {
  dnf -y install nfs-utils
  systemctl enable --now nfs-server
}

function check_nfs () {
  showmount -e | grep "^${CONFIG_ROOTFS_PATH} " > /dev/null 2>&1
  if [ $? -ne 0 ]; then
    echo "Error: (nfs) rootfs is not exported." >&2
    return 1
  fi

  return 0
}

function build_nfs () {
  local NFS_OPT="ro,async,no_root_squash,no_subtree_check"

  cat /etc/exports | grep "^${CONFIG_ROOTFS_PATH} " > /dev/null 2>&1
  if [ $? -ne 0 ]; then
    echo "${CONFIG_ROOTFS_PATH} 192.168.20.0/24(${NFS_OPT})" >> /etc/exports
  fi

  exportfs -ra
}

# prepare target
add_target prepare nfs
add_target check nfs
add_target build nfs
