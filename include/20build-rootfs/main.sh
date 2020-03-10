#!/bin/bash

function config_rootfs ()
{
  CONFIG_ROOTFS_PATH=${CONFIG_ROOTFS_PATH:-"${CONFIG_BASE_PATH}/rootfs"}

  _dialog RET --mixedform "Rootfs for clients" 20 80 10 \
    "Rootfs path" 1 0 "${CONFIG_ROOTFS_PATH}" 1 32 40 0 0

  if [ $? -ne 0 ]; then
    return
  fi

  local LIST=($(echo "$RET" | xargs))
  CONFIG_ROOTFS_PATH=${LIST[0]}
}

function config_rootfs_description () {
  echo "rootfs for clients"
}

function config_rootfs_save () {
  config_update "CONFIG_ROOTFS_PATH" "${CONFIG_ROOTFS_PATH}"
}

function build_rootfs () {
  if [ -e "${CONFIG_ROOTFS_PATH}/etc/centos-release" ]; then
    echo "Failed: rootfs were already builded." >&2
    return 1
  fi


  local tmpdir=$(mktemp -d)
  (
    cd ${tmpdir}
    dnf -y download centos-release
  )

  if [ ! -e ${tmpdir}/centos-release-*.rpm ]; then
    echo "Failed to download centos-release package." >&2
    rm -rf ${tmpdir}
    return 1
  fi

  # initialize
  rpm --root ${CONFIG_ROOTFS_PATH} --initdb
  rpm --root ${CONFIG_ROOTFS_PATH} -ivh --nodeps ${tmpdir}/centos-release-*.rpm
  rm -rf ${tmpdir}

  # install CentOS
  dnf -y --installroot ${CONFIG_ROOTFS_PATH} reinstall centos-release
  dnf -y --installroot ${CONFIG_ROOTFS_PATH} groupinstall "Minimal Install"

  # reset ugid
  _chroot bash -c "rpm -aq | xargs rpm --setugids"

  # disable SELinux
  sed -i -e 's/^SELINUX=.*$/SELINUX=disabled/g' ${CONFIG_ROOTFS_PATH}/etc/selinux/config

  # generate sshd key
  _chroot /usr/libexec/openssh/sshd-keygen rsa
  _chroot /usr/libexec/openssh/sshd-keygen ecdsa
  _chroot /usr/libexec/openssh/sshd-keygen ed25519

  # systemd services
  _chroot systemctl enable tmp.mount
  _chroot systemctl disable kdump.service

  # copy resolve.conf for use DNS in chroot
  cp /etc/resolv.conf ${CONFIG_ROOTFS_PATH}/etc/resolv.conf

  # additional packages
  _chroot dnf -y groupinstall "Server" "Development Tools"
  _chroot dnf -y install nfs-utils kernel epel-release

  # set password
  _chroot passwd root

  return 0
}

function _chroot () {
  local tmpdir=$(mktemp -d)
  mount --bind ${CONFIG_ROOTFS_PATH} ${tmpdir}
  mount --bind /sys ${tmpdir}/sys
  mount -t proc none ${tmpdir}/proc
  mount -t tmpfs tmpfs ${tmpdir}/tmp
  chroot ${tmpdir} "$@"
  umount -R ${tmpdir}
  rm -r ${tmpdir}
}

function action_chroot () {
  _chroot ${@:-bash}
}

add_actions chroot

add_target build rootfs
add_target config rootfs
