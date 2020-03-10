#!/bin/bash

function build_overlayfs-patch () { 
  local CWD=$(pwd)
  local tmpdir=$(mktemp -d)

  local PATCH1=${tmpdir}/overlayfs-allow-change-to-lowerdir.diff
  local PATCH2=${tmpdir}/overlayfs-discard-xattr-copy-failure.diff

  local KERNEL_VERSION=$(_chroot dnf list installed kernel | tail -n 1 | sed -E 's/ +/ /g' | cut -d' ' -f2)
  local KERNEL_ARCH=$(_chroot dnf list installed kernel | tail -n 1 | sed -E 's/ +/ /g' | cut -d' ' -f1 | cut -d'.' -f2)
  local CENTOS_RELEASE=$(grep -oE "[0-9.]+" ${CONFIG_ROOTFS_PATH}/etc/redhat-release)

  cat > ${PATCH1} << 'EOS'
diff -ru linux-4.18.0-147.5.1.el8.x86_64/fs/overlayfs/super.c linux-4.18.0-147.5.1.el8.x86_64.new/fs/overlayfs/super.c
--- linux-4.18.0-147.5.1.el8.x86_64/fs/overlayfs/super.c	2020-01-14 23:54:17.000000000 +0900
+++ linux-4.18.0-147.5.1.el8.x86_64.new/fs/overlayfs/super.c	2020-03-02 04:29:36.855735623 +0900
@@ -127,16 +127,11 @@
 
 		if (d->d_flags & DCACHE_OP_REVALIDATE) {
 			ret = d->d_op->d_revalidate(d, flags);
-			if (ret < 0)
+			if (ret <= 0)
 				return ret;
-			if (!ret) {
-				if (!(flags & LOOKUP_RCU))
-					d_invalidate(d);
-				return -ESTALE;
-			}
 		}
 	}
-	return 1;
+	return ret;
 }
 
 static int ovl_dentry_weak_revalidate(struct dentry *dentry, unsigned int flags)
EOS

  cat > ${PATCH2} << 'EOS'
diff -ru linux-4.18.0-147.5.1.el8.x86_64/fs/overlayfs/copy_up.c linux-4.18.0-147.5.1.el8.x86_64.new/fs/overlayfs/copy_up.c
--- linux-4.18.0-147.5.1.el8.x86_64/fs/overlayfs/copy_up.c	2020-01-14 23:54:17.000000000 +0900
+++ linux-4.18.0-147.5.1.el8.x86_64.new/fs/overlayfs/copy_up.c	2020-03-02 04:21:37.701624976 +0900
@@ -110,6 +110,10 @@
 			continue; /* Discard */
 		}
 		error = vfs_setxattr(new, name, value, size, 0);
+		if (error == -EOPNOTSUPP) {
+			error = 0;
+			continue;
+		}
 		if (error)
 			break;
 	}
EOS

  dnf -y install kernel-devel-${KERNEL_VERSION}

  cd ${tmpdir}
  wget -c http://vault.centos.org/${CENTOS_RELEASE}/BaseOS/Source/SPackages/kernel-${KERNEL_VERSION}.src.rpm
  rpm -ivh --define="%_topdir ${tmpdir}/rpmbuild" kernel-${KERNEL_VERSION}.src.rpm
  if [ $? -ne 0 ]; then
    echo "Failed to extract kernel source" >&2
    return 1
  fi

  cd rpmbuild
  dnf -y builddep SPECS/kernel.spec
  rpmbuild -bp --define="%_topdir ${tmpdir}/rpmbuild" SPECS/kernel.spec
  if [ $? -ne 0 ]; then
    echo "Failed to pre-build process of kernel" >&2
    return 1
  fi

  cd BUILD/kernel-*/linux-*
  patch -lp1 < ${PATCH1}
  patch -lp1 < ${PATCH2}
  make -C /lib/modules/${KERNEL_VERSION}.${KERNEL_ARCH}/build M=`pwd`/fs/overlayfs modules
  if [ $? -ne 0 ]; then
    echo "Failed to build overlayfs module" >&2
    return 1
  fi
  xz fs/overlayfs/overlay.ko
  cp fs/overlayfs/overlay.ko.xz ${CONFIG_ROOTFS_PATH}/lib/modules/${KERNEL_VERSION}.${KERNEL_ARCH}/kernel/fs/overlayfs/

  cd ${CWD}
  rm -rf ${tmpdir}

  return 0
}

add_target build overlayfs-patch
