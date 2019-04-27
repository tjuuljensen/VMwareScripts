  #!/bin/bash
  # get-vmware-latest.sh
  #
  # This script will handle download of latest software, online latest version check and  install support of VMware workstation.s
  # It was created to be part of an easy-configure setup for Linux computers as well as the maintenance of the installation over the long run.
  # The script has support for automatically reading serial numbers from a config file and use them in the registration of the software
  #
  # script will automatically escalate to root privileges if needed.
  #
  # last edited: April 28, 2019 01:00

  _set-flags-init () {
      # Distribution flags
      PRINTVERSIONFLAG=0
      SHOWSERIALFLAG=0
      DOWNLOADFLAG=0
      INSTALLFLAG=0
  }

  _parse_arguments () {
      _set-flags-init
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
              -v | --version )
                  PRINTVERSIONFLAG=1
                  shift
                  ;;
              -s | --serial )
                  SHOWSERIALFLAG=1
                  shift
                  ;;
              -t | --target-directory)
                if [ -d $2 ] ; then
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
                else
                  echo "Config file ($2) does not exist"
                  exit 444
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
               exit 404
          esac
      done
  }

  _defineVariables () {
    # Basic variables
    if [ -z $DOWNLOADDIR ] ; then DOWNLOADDIR=. ; fi # If it has not been declared by command line args it is set to current directory
    SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

    # Read config file with serial numbers
    if [ -z $CONFIGFILE ] ; then CONFIGFILE=$SCRIPTDIR/serialnumbers.config ; fi # If CONFIGFILE has not been declared by command line args, it is set to a default value
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

  _help()
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
    cd $DOWNLOADDIR
    wget --content-disposition -N -q --show-progress $VMWAREURL # Overwrite file, quiet
    chmod +x $BINARYFILENAME
  }

  _installVMwareWorkstation(){
    # download has been done. Now install vmware workstation 
    ./$BINARYFILENAME --required --console # 
    
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

_main () {
  _defineVariables
  (( $PRINTVERSIONFLAG == 1)) && echo VMware version is: $VMWAREVERSION
  (( $SHOWSERIALFLAG == 1)) && _outputSerial
  (( $DOWNLOADFLAG == 1)) && _downloadVMWareWorkstation
  (( $INSTALLFLAG == 1)) && _confirm "Do you want to install VMware Workstation? [yN]" && _installVMwareWorkstation

}

  #### MAIN ####

_parse_arguments $@
_main
