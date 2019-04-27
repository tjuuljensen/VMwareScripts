#!/bin/sh
# 
# script will automatically escalate to root privileges. Do not run as root
# last edited: April 27, 2019 16:00


_defineVariables () {
  # Basic variables
  MYUSER=$(logname)
  DOWNLOADDIR=.
  SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

  # Read config file with serial numbers
  CONFIGFILE=$SCRIPTDIR/serialnumbers.config
  if [[ -f $CONFIGFILE ]] ; then # file exists
    source $CONFIGFILE # Load serial numbers from config file
  fi

  # define URL locations and extract key information for later use
  VMWAREURL=https://www.vmware.com/go/getworkstation-linux
  BINARYURL=$(wget $VMWAREURL -O - --content-disposition --spider 2>&1 | grep Location | cut -d ' ' -f2) # Full URL to binary installer
  BINARYFILENAME="${BINARYURL##*/}" # Filename of binary installer
  VMWAREVERSION=$(echo $BINARYURL | cut -d '-' -f4 ) # In the format XX.XX.XX
  MAJORVERSION=$(echo $BINARYURL | cut -d '-' -f4 | cut -d '.' -f1) # In the format XX
  # Another way of getting MAJORVERSION: curl -sIkL $VMWAREURL | grep "filename=" | sed -r 's|^([^.]+).*$|\1|; s|^[^0-9]*([0-9]+).*$|\1|'

  if [ ! -z "VMWARESERIAL$MAJORVERSION" ] ; then # VMWARESERIALXX of the current major release is defined in config file
    # TMPSERIAL is used to translate serial numbers from config file - if major version is 15 then the value of the entry VMWARESERIAL15 is assigned to TMPSERIAL.
    TMPSERIAL=VMWARESERIAL$MAJORVERSION # Addressing of a dynamic variable is different. Therefore it is put into CURRENTVMWSERIAL
    CURRENTVMWSERIAL=${!TMPSERIAL}
  fi
}

_usage()
{
    SCRIPT_NAME=$(basename $0)
    echo "usage: $SCRIPT_NAME [--version] [--download ] | [--install] | [--help] [--config-file <filewithserial.config>] [target-directory <download directory>]"
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
  _defineVariables
  cd $DOWNLOADDIR
  wget --content-disposition -N -q --show-progress $VMWAREURL # Overwrite file, quiet
  chmod +x $BINARYFILENAME
}

_installVMwareWorkstation(){
  # download has been done. Now install vmware workstation (filename on bundle file is predetermined by download section with -O parameter)
  ./$BINARYFILENAME --required --console # /$VMWAREBIN --required --console
  # add serial number if seriual number is defined

  if [ ! -z $CURRENTVMWSERIAL ] ; then #Serial number for major version is loaded as a variable
    /usr/lib/vmware/bin/vmware-vmx --new-sn $CURRENTVMWSERIAL #please note that this variable needs to be addressed differently because it's dynamically defined
  fi

  vmware-modconfig --console --install-all

}


#### MAIN ####

if [[ $# -eq 0 ]]
  then
    _usage
fi

  while [[ $# -gt 0 ]]
  do
    case $1 in
        -d | --download )
              _downloadVMWareWorkstation
              shift
              ;;
        -i | --install )
              # elevate privileges to root
              [ "$UID" -eq 0 ] || exec sudo bash "$0" "$@" # check if script is root
              _downloadVMWareWorkstation && _confirm "Do you want to install VMware Workstation? [yN]" && _installVMwareWorkstation
              shift
              ;;
        -v | --version )
            _defineVariables
            echo VMware version is: $VMWAREVERSION
            shift
            ;;
        -s | --serial )
            _defineVariables
            if [ ! -z $CURRENTVMWSERIAL ] ; then # variable is not defined
              echo "Serial Number (from .config): $CURRENTVMWSERIAL"
            else
              echo "Serial number not found in .config file"
            fi
            shift
            ;;
        -t | --target-directory)
          if realpath -e -q $2 1>/dev/null ; then
            DOWNLOADDIR=$2
          else
            echo Target directory does not exist
            exit 404
          fi
          shift
          shift
          ;;
        -c | --config-file )
            if realpath -e -q $2 &>/dev/null ; then
              CONFIGFILE=$2
              echo $CONFIGFILE
            else
              echo "Config file ($2) does not exist"
              exit 444
            fi
            shift
            shift
            ;;
        -h | --help )
            _usage
            exit 1
            ;;
        * )
           _usage
           exit 404
           shift
    esac
done
