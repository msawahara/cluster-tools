#!/bin/bash

function build_readonly-root () { 
  local MODULESDIR=/usr/lib/dracut/modules.d
  local MODULENAME=92readonly-root

  local moddir=${CONFIG_ROOTFS_PATH}${MODULESDIR}/${MODULENAME}

  mkdir -p ${CONFIG_ROOTFS_PATH}/ramdisk
  mkdir -p ${moddir}

  
  cat > ${moddir}/module-setup.sh << 'EOS'
#!/bin/bash

check() {
  return 0
}

depends() {
  return
}

installkernel() {
  hostonly='' instmods overlay
}

install() {
  inst_multiple modprobe

  inst_hook cleanup 99 "$moddir/readonly-root.sh"
}
EOS

  cat > ${moddir}/readonly-root.sh << 'EOS'
#!/bin/bash

SYSROOT=/sysroot
RAMDISK=${SYSROOT}/ramdisk

function load_overlay () {
  modprobe overlay
  mount -t tmpfs tmpfs ${RAMDISK}
}

function do_overlay () {
   LOWER=$1
   OVERLAY_WORKDIR=${RAMDISK}/overlay
   mkdir -p ${OVERLAY_WORKDIR}${LOWER}/{upper,work}
   mount -t overlay -o lowerdir=${LOWER},upperdir=${OVERLAY_WORKDIR}${LOWER}/upper,workdir=${OVERLAY_WORKDIR}${LOWER}/work overlay ${LOWER}
}

load_overlay

umount ${SYSROOT}/var/lib/nfs/rpc_pipefs

for dir in /etc /var
do
  do_overlay ${SYSROOT}${dir}
done

mount -t rpc_pipefs rpc_pipefs ${SYSROOT}/var/lib/nfs/rpc_pipefs
EOS

  chmod a+x ${moddir}/{module-setup.sh,readonly-root.sh}

  return 0
}

add_target build readonly-root
