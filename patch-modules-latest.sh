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

[ "$UID" -eq 0 ] || exec sudo bash "$0" "$@" # check if script is root and restart as root if not

MYUSER=$(logname)
MYUSERDIR=/home/$MYUSER

VMWAREURL=https://www.vmware.com/go/getworkstation-linux
BINARYURL=$(curl -I $VMWAREURL 2>&1 | grep Location | cut -d ' ' -f2 | sed 's/\r//g') # Full URL to binary installer
VMWAREVERSION=$(echo $BINARYURL | cut -d '-' -f4 ) # In the format XX.XX.XX

systemctl stop vmware

cd $MYUSERDIR/git
if [ ! -d vmware-host-modules ]; then
  sudo -u $MYUSER git clone https://github.com/mkubecek/vmware-host-modules.git
fi

cd vmware-host-modules

if [[ ! -z $(sudo -u $MYUSER git checkout workstation-$VMWAREVERSION 2>/dev/null) ]] ; then # current vmware version is a branch in mkubecek's github library

  if [ $# -eq 0 ] ; then
      INSTALLEDKERNEL=$(rpm -qa kernel | sed 's/kernel-//g' | sort -r -V | awk 'NR==1' )
    else
      INSTALLEDKERNEL=$1
  fi

  #INSTALLEDKERNEL=$(rpm -qa kernel | sed 's/kernel-//g' | sort -r -V | awk 'NR==1' )
  RUNNINGKERNEL=$(uname -r)
  #LATESTKERNELVER=$(echo $INSTALLEDKERNEL | sed 's/kernel-//g' | sed 's/\.fc[0-9].*//g')

  # Build for the kernel is installed
  if [ $INSTALLEDKERNEL != $RUNNINGKERNEL ] ; then
    echo Building modules for latest installed kernel $INSTALLEDKERNEL
    sudo -u $MYUSER make VM_UNAME=$INSTALLEDKERNEL
    make install VM_UNAME=$INSTALLEDKERNEL
    echo "Make sure to reboot before starting VMware (You are running another kernel than the compiled modules for VMware)"
  else # install for current kernel
    echo Building modules for current installed kernel $RUNNINGKERNEL
    sudo -u $MYUSER make
    make install
    systemctl restart vmware
  fi


else
  echo "There is not a valid branch in mkubecek's repo that matches current Mware version $VMWAREVERSION"
fi
