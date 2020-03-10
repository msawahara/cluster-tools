#!/bin/bash

MUNGE_VERSION="0.5.14"
SLURM_VERSION="20.02.0"

MUNGE_DOWNLOAD_URL="https://github.com/dun/munge/releases/download/munge-${MUNGE_VERSION}/munge-${MUNGE_VERSION}.tar.xz"
SLURM_DOWNLOAD_URL="https://download.schedmd.com/slurm/slurm-${SLURM_VERSION}.tar.bz2"

function prepare_slurm () {
  dnf -y install bzip2-devel mysql mysql-devel
}

function build_slurm () {
  # install
  build_slurm_install_munge && build_slurm_install_slurm
  if [ $? -ne 0 ]; then
    return $?
  fi

  return 0
}

function build_slurm_install_munge () {
  local CWD=$(pwd)
  local tmpdir=$(mktemp -d)
  local ARCH=$(uname -p)
  
  cd ${tmpdir}

  wget ${MUNGE_DOWNLOAD_URL}

  # --without verify for disable source code verify
  rpmbuild --define="%_topdir ${tmpdir}/rpmbuild" -tb --without verify munge-${MUNGE_VERSION}.tar.xz
  if [ $? -ne 0 ]; then
    echo "Failed to build munge." >&2
    cd ${CWD}
    return 1
  fi

  local MUNGE_RPMS="${CONFIG_BASE_PATH}/RPMS/munge-${MUNGE_VERSION}"
  mkdir -p ${MUNGE_RPMS}

  cp ${tmpdir}/rpmbuild/RPMS/${ARCH}/*.rpm ${MUNGE_RPMS}

  cd ${CWD}
  rm -rf ${tmpdir}

  # install to host
  dnf -y localinstall --nogpgcheck ${MUNGE_RPMS}/*.rpm
  if [ $? -ne 0 ]; then
    echo "Failed to install munge." >&2
    cd ${CWD}
    return 1
  fi

  # install to client
  local chroot_tmpdir=$(mktemp -d -p ${CONFIG_ROOTFS_PATH}/mnt)
  cp ${MUNGE_RPMS}/*.rpm ${chroot_tmpdir}
  _chroot bash -c "dnf -y localinstall --nogpgcheck ${chroot_tmpdir#${CONFIG_ROOTFS_PATH}}/*.rpm"
  rm -rf ${chroot_tmpdir}

  return 0
}

function build_slurm_install_slurm () {
  local CWD=$(pwd)
  local tmpdir=$(mktemp -d)
  local ARCH=$(uname -p)
  
  cd ${tmpdir}

  wget ${SLURM_DOWNLOAD_URL}
  rpmbuild --define="%_topdir ${tmpdir}/rpmbuild" -ts slurm-${SLURM_VERSION}.tar.bz2

  # install depends
  dnf -y builddep ${tmpdir}/rpmbuild/SRPMS/*.rpm

  rpmbuild --define="%_topdir ${tmpdir}/rpmbuild" --rebuild --clean ${tmpdir}/rpmbuild/SRPMS/*.rpm

  local SLURM_RPMS="${CONFIG_BASE_PATH}/RPMS/slurm-${MUNGE_VERSION}"
  mkdir -p ${SLURM_RPMS}

  cp ${tmpdir}/rpmbuild/RPMS/${ARCH}/*.rpm ${SLURM_RPMS}

  cd ${CWD}
  rm -rf ${tmpdir}

  # install to host
  dnf -y localinstall --nogpgcheck --skip-broken ${SLURM_RPMS}/*.rpm
  if [ $? -ne 0 ]; then
    echo "Failed to install slurm." >&2
    cd ${CWD}
    return 1
  fi

  # install to client
  local chroot_tmpdir=$(mktemp -d -p ${CONFIG_ROOTFS_PATH}/mnt)
  cp ${SLURM_RPMS}/*.rpm ${chroot_tmpdir}
  _chroot bash -c "dnf -y localinstall --nogpgcheck --skip-broken ${chroot_tmpdir#${CONFIG_ROOTFS_PATH}}/*.rpm"
  rm -rf ${chroot_tmpdir}

  return 0
}

add_target prepare slurm
add_target build slurm
