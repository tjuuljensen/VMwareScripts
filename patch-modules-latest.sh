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

sudo -u $MYUSER git clone https://github.com/mkubecek/vmware-host-modules.git

cd vmware-host-modules

if [[ $(git branch | grep $VMWAREVERSION) != "" ]] ; then # current vmware version exists in mkubecek's github library
  git checkout workstation-$VMWAREVERSION
  sudo make install

  mv /usr/lib/vmware/lib/libz.so.1/libz.so.1 /usr/lib/vmware/lib/libz.so.1/libz.so.1.old
  ln -s /lib/x86_64-linux-gnu/libz.so.1 /usr/lib/vmware/lib/libz.so.1/libz.so.1
  systemctl restart vmware && vmware &
else
  echo "Current VMware version $VMWAREVERSION doesn't exist in mkubecek's github repo"
fi
