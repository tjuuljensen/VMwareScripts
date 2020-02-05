  #!/bin/bash
  # vmware-helper.sh
  #
  # Author: Torsten Juul-Jensen, tjuuljensen@gmail.com
  # February 4, 2019
  # Developed for Fedora Workstation
  #
  # This script is made for certain VMware Workstation "helper tasks"
  # The script is built for an easy-to-configure setup for Linux computers as well as the maintenance of the installation over the long run.
  # The script has support for automatically reading serial numbers from a config file and use them in the registration of the software
  #
  # It handles:
  # - online check for latest version
  # - download of latest software
  # - installation of VMware workstation.
  # - serial numbers read from files
  # - patch kernel modules for recent kernel versions
  #
  # script will automatically escalate to root privileges if needed.
  #
  # last edited: February 5, 2020 07:00

  _set-flags-init () {
      # Distribution flags
      PRINTVERSIONFLAG=0
      SHOWSERIALFLAG=0
      DOWNLOADFLAG=0
      INSTALLFLAG=0
      PATCHFLAG=0
  }

  _parse_arguments () {

      if [[ $# -eq 0 ]] ; then _help ; fi

        while [[ $# -gt 0 ]]
        do
          case $1 in
              -d | --download )
                  DOWNLOADFLAG=1
                  shift
                  ;;
              -i | --install )
                  # elevate privileges to root
                  [ "$UID" -eq 0 ] || exec sudo bash "$0" "$@" # check if script is root and restart as root if not
                  DOWNLOADFLAG=1
                  INSTALLFLAG=1
                  shift
                  ;;
              -p | --patch )
                # patch option has three valid inputs: "current", "latest" or a specific kernel name
                OPTION=$2
                if [ ${OPTION,,} = "current" ] ; then # "current" entered as parameter to patch - use current loaded kernel
                  SELECTEDKERNEL=$(uname -r)
                else
                  if [ ${OPTION,,} = "latest" ] ; then # "latest" entered as parameter to patch - use latest kernel
                    SELECTEDKERNEL=$(rpm -qa kernel | sed 's/kernel-//g' | sort -r -V | awk 'NR==1')
                  else # a specific kernel was parsed as parameter to patch - use this kernel (short format 5.4.10 allowed )
                    SELECTEDKERNEL=$(rpm -qa kernel | sed 's/kernel-//g' | grep $OPTION | sort -r -V | awk 'NR==1')
                    if [ -z $SELECTEDKERNEL ]  ; then # kernel not found
                      echo Not a valid kernel option
                      _help
                      exit 1
                    fi
                  fi
                fi
                PATCHFLAG=1
                shift
                shift
                ;;
              -v | --version )
                # for printing the latest online version of vmware
                  PRINTVERSIONFLAG=1
                  shift
                  ;;
              -s | --serial )
                # display serial number read from serial numbers file
                SHOWSERIALFLAG=1
                shift
                ;;
              -t | --target-directory)
                # directory to download to (and install from)
                if [ -d $2 ] ; then
                  DOWNLOADDIR=$2
                else
                  echo Target directory does not exist
                  exit 2
                fi
                shift
                shift
                ;;
              -c | --config-file )
                # path to serial numbers file
                if realpath -e -q $2 &>/dev/null ; then
                  CONFIGFILE=$2
                else
                  echo "Config file ($2) does not exist"
                  exit 2
                fi
                shift
                shift
                ;;
              -h | --help )
                _help
                exit 1
                ;;
              * )
               _help
               exit 1
          esac
      done
  }

  _defineVariables () {
    # Basic variables - download directory and script execution directory
    if [ -z $DOWNLOADDIR ] ; then DOWNLOADDIR=. ; fi # If it has not been declared by command line args it is set to current directory
    SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )" #set the variable to the place where script is loaded from

    # Read config file with serial numbers
    if [ -z $CONFIGFILE ] ; then CONFIGFILE=$SCRIPTDIR/serialnumbers.config ; fi # If CONFIGFILE has not been declared by command line args, it is set to a default value (serianlnum... in script directory)
    if [[ -f $CONFIGFILE ]] ; then # file exists
      source $CONFIGFILE # Load serial numbers from config file
    fi

    # define URL locations and extract key information for later use
    VMWAREURL=https://www.vmware.com/go/getworkstation-linux
    BINARYURL=$(curl -I $VMWAREURL 2>&1 | grep Location | cut -d ' ' -f2 | sed 's/\r//g') # Full URL to binary installer
    BINARYFILENAME="${BINARYURL##*/}" # Filename of binary installer
    VMWAREVERSION=$(echo $BINARYURL | cut -d '-' -f4 ) # In the format XX.XX.XX
    MAJORVERSION=$(echo $BINARYURL | cut -d '-' -f4 | cut -d '.' -f1) # In the format XX
    # Another way of getting MAJORVERSION: curl -sIkL $VMWAREURL | grep "filename=" | sed -r 's|^([^.]+).*$|\1|; s|^[^0-9]*([0-9]+).*$|\1|'
    MYUSER=$(logname) #
    MYUSERDIR=/home/$MYUSER #
    RUNNINGKERNEL=$(uname -r) #

    if [ ! -z "VMWARESERIAL$MAJORVERSION" ] ; then # VMWARESERIALXX of the current major release is defined in config file
      # TMPSERIAL is used to translate serial numbers from config file - if major version is 15 then the value of the entry VMWARESERIAL15 is assigned to TMPSERIAL.
      TMPSERIAL=VMWARESERIAL$MAJORVERSION # Addressing of a dynamic variable is different. Therefore it is put into CURRENTVMWSERIAL
      CURRENTVMWSERIAL=${!TMPSERIAL}
    fi
  }

  _help()
  {
      SCRIPT_NAME=$(basename $0)
      echo "usage: $SCRIPT_NAME [--version] [--download ] | [--install] | [--patch [latest|current]] | [--help] [--config-file <filewithserial.config>] [target-directory <download directory>]"
  }

  _confirm () {
    # prompt user for confirmation. Default is No
      read -r -p "${1:-Do you want to proceed? [y/N]} " RESPONSE
      RESPONSE=${RESPONSE,,}
      if [[ $RESPONSE =~ ^(yes|y| ) ]]
        then
          true
        else
          false
      fi
  }

  _downloadVMWareWorkstation(){
    cd $DOWNLOADDIR
    wget --content-disposition -N -q --show-progress $BINARYURL # Overwrite file, quiet
    chmod +x $BINARYFILENAME
  }

  _installVMwareWorkstation(){
    # download has been done. Now install vmware workstation
    ./$BINARYFILENAME --required --console --eulas-agreed #

    # add serial number if serial number is defined
    if [ ! -z $CURRENTVMWSERIAL ] ; then #Serial number for major version is loaded as a variable
      /usr/lib/vmware/bin/vmware-vmx --new-sn $CURRENTVMWSERIAL #please note that this variable needs to be addressed differently because it's dynamically defined
    fi
    vmware-modconfig --console --install-all
  }

  _outputSerial () {
    if [ ! -z $CURRENTVMWSERIAL ] ; then # variable is not defined
      echo "Serial Number (from .config): $CURRENTVMWSERIAL"
    else
      echo "Serial number not found in .config file"
    fi
  }

_patchModules(){
  # patching kernel modules to match current kernel and vmware
  # using the source made available in git repo mkubecek/vmware-host-modules

  systemctl stop vmware

  # if function is called with kernel package name (format like "5.4.10-100.fc30.x86_64") use this, otherwise use latest kernel to compile
  if [ $# -eq 0 ] ; then # patch latest kernel
      INSTALLEDKERNEL=$(rpm -qa kernel | sed 's/kernel-//g' | sort -r -V | awk 'NR==1')
    else # this is the default use
      INSTALLEDKERNEL=$1
  fi

  # Enter mkubecek/vmware-host-modules git directory (clone if it doesn' exist)
  cd $MYUSERDIR/git
  if [ ! -d vmware-host-modules ]; then
    sudo -u $MYUSER git clone https://github.com/mkubecek/vmware-host-modules.git
    # Change into mkubecek's repo library
    cd vmware-host-modules
  else
    cd vmware-host-modules
    sudo -u $MYUSER git pull
  fi

  # Check for vmware version branch in git repo mkubecek/vmware-host-modules
  if [[ ! -z $(sudo -u $MYUSER git checkout workstation-$VMWAREVERSION 2>/dev/null) ]] ; then # current vmware version is a branch in mkubecek's github library

    #INSTALLEDKERNEL=$(rpm -qa kernel | sed 's/kernel-//g' | sort -r -V | awk 'NR==1' )
    echo Installed kernel: $INSTALLEDKERNEL
    echo Running kernel: $RUNNINGKERNEL
    #LATESTKERNELVER=$(echo $INSTALLEDKERNEL | sed 's/kernel-//g' | sed 's/\.fc[0-9].*//g')

    # Building modules for the kernel chosen
    if [ $INSTALLEDKERNEL != $RUNNINGKERNEL ] ; then
      echo Building modules for installed kernel $INSTALLEDKERNEL
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
    echo Installed kernel: $INSTALLEDKERNEL
    echo Running kernel: $RUNNINGKERNEL
    echo "There is not a valid branch in mkubecek's repo that matches current Mware version $VMWAREVERSION"
  fi

}

_main () {
  _defineVariables
  (( $PRINTVERSIONFLAG == 1)) && echo Latest online VMware version is: $VMWAREVERSION
  (( $SHOWSERIALFLAG == 1)) && _outputSerial
  (( $DOWNLOADFLAG == 1)) && _downloadVMWareWorkstation
  (( $INSTALLFLAG == 1)) && _confirm "Do you want to install VMware Workstation? [yN]" && _installVMwareWorkstation
  (( $PATCHFLAG == 1)) && _patchModules $SELECTEDKERNEL
}

  #### MAIN ####
_set-flags-init
_parse_arguments $@
_main
