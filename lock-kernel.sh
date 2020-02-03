#!/bin/bash
# lock-kernel.sh
#
# locks specific installed kernel with versionlock
# version regex= ^[0-9]+\.[0-9]+\.[0-9]+$


_requireAdmin(){
    # check if script is root and restart as root if not
    [ "$UID" -eq 0 ] || exec sudo bash "$0" "$@"
}

_help(){
  SCRIPT_NAME=$(basename $0)
  echo "usage: $SCRIPT_NAME [--lock <KERNELVERSION_TO_BE_LOCKED>] [--unlock LOCKED_KERNELVERSION] [--install KERNELVERSION] [--info]"
  exit 1
}

_installRequired(){
  # install required packages (python3, dnf versioncheck plugin, ...)
  REQUIREDPACKAGES=("python3" "python3-dnf-plugin-versionlock")
  for i in ${!REQUIREDPACKAGES[@]};
  do
    rpm -q --quiet ${REQUIREDPACKAGES[$i]}  || dnf install -y ${REQUIREDPACKAGES[$i]}
  done
}

_installKernel(){
  if [[ $# -eq 0 ]] ; then
    echo "Error: [_installKernel] Function called with wrong number of parameters"
    exit 2
  fi
  if ( ! rpm -qa kernel* | grep $1 > /dev/null ) ; then
    dnf install -q -y kernel-$1 kernel-devel-$1 kernel-headers-$1
  fi
}

_lockKernel(){
  # Function checks that kernel is installed - if not, install it
  # Lock kernel and set it as default boot

  if [[ $# -eq 0 ]] ; then
    echo "Error: [_lockKernel] Function called with wrong number of parameters"
    exit 2
  fi

  BOOTIMAGE=$(ls /boot/vmlinuz* | grep $1)

  if [ ! -z $BOOTIMAGE ] ; then
    grubby --set-default $BOOTIMAGE
    rpm -qa kernel* | grep $1 | xargs dnf versionlock add
  else
    echo "Error: Cannot lock kernel. No bootimage for kernel-$1 found in /boot/"
    _help
    exit 2
  fi
}

_removeKernelLock(){
  # remove versionlock entries for version parsed to function
  if [[ $# -eq 0 ]] ; then
    echo "Error: [_removeKernelLock] Function called with wrong number of parameters"
    exit 2
  fi

  #grubby --set-default $BOOTIMAGE
  rpm -qa kernel* | grep $1 | xargs dnf versionlock delete
}

_checkVersionFormat(){
  # Check if the parsed parameter matches regex "^[0-9]+\.[0-9]+\.[0-9]+$" (like 5.4.7)
  if [[ $# -eq 0 ]] ; then
    echo "Error: [_checkVersionFormat] Function called with wrong number of parameters"
    exit 2
  fi

  if [[ ! $1 =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] ; then
      echo "Version must match pattern #.#.#"
      exit 2
  fi
}

_parseArguments() {
  # parse script arguments and call functions

  #check if there are command line parameters parsed to the script - if yes, check preconditions
  if [[ $# -eq 0 ]] ; then
    # DEBUG echo $@
    _help
    exit 1
  else
    _requireAdmin $@
    _installRequired
  fi

  while [[ $# -gt 0 ]]
  do
    case $1 in
        -d | --delete | -u | --unlock )
        #dnf versionlock delete *
        _checkVersionFormat $2
        if ( dnf versionlock list kernel*$2  > /dev/null ) ; then
          _removeKernelLock $2
        fi
        shift
        shift
        exit 0
        ;;
        -l | --lock )
        # lock kernel $2
        _checkVersionFormat $2
        _lockKernel $2
        shift
        shift
        exit 0
        ;;
        -i | --install )
        _checkVersionFormat $2
        _installKernel $2
        shift
        shift
        exit 0
        ;;
        --info )
        echo "### Grubby Info: ###"
        grubby --info=ALL | grep index=2 -A 1
        echo "### dnf versionlock Info: ###"
        dnf versionlock list kernel*
        exit 0
        ;;
        * )
        # kernel alone options automates to lock function
        _checkVersionFormat $1
        _lockKernel $1
        shift
        exit 0
      esac
    done

}

### main ###
_parseArguments $@
