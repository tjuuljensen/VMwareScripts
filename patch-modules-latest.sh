#!/bin/bash
# patch vmware modules
#
# Author: Torsten Juul-Jensen
# Date: May 9, 2019
#
# Updated maintaned by mkubecek on https://github.com/mkubecek/vmware-host-modules
# libz.so.1 patch grabbed from https://wesley.sh/solved-vmware-workstation-15-fails-to-compile-kernel-modules-with-failed-to-build-vmmon-and-failed-to-build-vmnet/
#
#
MYUSER=$(logname)
MYUSERDIR=/home/$MYUSER

VMWAREURL=https://www.vmware.com/go/getworkstation-linux
BINARYURL=$(wget $VMWAREURL -O - --content-disposition --spider 2>&1 | grep Location | cut -d ' ' -f2) # Full URL to binary installer
VMWAREVERSION=$(echo $BINARYURL | cut -d '-' -f4 ) # In the format XX.XX.XX

cd $MYUSERDIR/git
if [ ! -d vmware-host-modules ]; then
  sudo -u $MYUSER git clone https://github.com/mkubecek/vmware-host-modules.git
fi

cd vmware-host-modules

if [[ ! -z $(git checkout workstation-$VMWAREVERSION 2>/dev/null) ]] ; then # current vmware version is a branch in mkubecek's github library
  [ "$UID" -eq 0 ] || exec sudo bash "$0" "$@" # check if script is root and restart as root if not
  # get github repo to recompile vmware kernel modules to newer kernel modules
  sudo -u $MYUSER git checkout workstation-$VMWAREVERSION
  sudo -u $MYUSER make
  make install

  #mv /usr/lib/vmware/lib/libz.so.1/libz.so.1 /usr/lib/vmware/lib/libz.so.1/libz.so.1.old
  #ln -s /lib/x86_64-linux-gnu/libz.so.1 /usr/lib/vmware/lib/libz.so.1/libz.so.1
  systemctl restart vmware && vmware &
else
  echo "There is not a valid branch in mkubecek's repo that matches current VMware version $VMWAREVERSION"
fi
