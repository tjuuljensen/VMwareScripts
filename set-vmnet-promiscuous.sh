#!/bin/bash
# set-vmnet-promiscuous.sh
# Set vmnet0 to allow promiscuous mode for users in prmisc group
# Used for running vm's like SANS SIFT that requires promiscuous mode

PROMISCUOUS_GROUP=prmisc
MYUSER=$(logname)

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

# elevate privileges to root
[ "$UID" -eq 0 ] || exec sudo bash "$0" "$@"

# add group
echo Adding group $PROMISCUOUS_GROUP...
if grep -q -E "^$PROMISCUOUS_GROUP:" /etc/group ; then
  echo - group $PROMISCUOUS_GROUP already exists, skipping creation
else
  groupadd $PROMISCUOUS_GROUP
fi

# change group & permissions on /dev/vmnet0
echo Changing permissions on /dev/vmnet0
chgrp $PROMISCUOUS_GROUP /dev/vmnet0
chmod g+rw /dev/vmnet0

# Add current user to promiscuous group
echo Adding user $MYUSER to group $PROMISCUOUS_GROUP...
if groups $MYUSER | grep &>/dev/null "\b$PROMISCUOUS_GROUP\b" ; then
    echo - user $MYUSER is already added to group $PROMISCUOUS_GROUP, skipping
else
  echo Adding current user to promiscuous group
  usermod -aG $PROMISCUOUS_GROUP $MYUSER
fi

echo Done.
