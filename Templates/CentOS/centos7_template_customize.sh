#!/bin/bash 
# For customization of CentOS 7 guest templates
#
# THIS SCRIPT DOES NOT WORK!!!!  (No CUSTOMIZATION)
#
# credit to lonesysadmin.net & serverfault.com for answers
# 
# http://serverfault.com/questions/653052/from-vsphere-5-5-deploying-centos-7-from-template-ignores-customizations
# https://lonesysadmin.net/2013/03/26/preparing-linux-template-vms/
# https://lonesysadmin.net/2015/01/06/centos-7-refusing-vmware-vsphere-guest-os-customizations/
#

#sudo -i

# stop logging services
/sbin/service rsyslog stop
/sbin/service auditd stop

# force logs to rotate and remove old unneeded logs
/usr/sbin/logrotate -f /etc/logrotate.conf
/bin/rm -f /var/log/*-???????? /var/log/*.gz
/bin/rm -f /var/log/dmesg.old
/bin/rm -rf /var/log/anaconda

# truncate auditlog (and other logs)
/bin/cat /dev/null > /var/log/audit/audit.log
/bin/cat /dev/null > /var/log/wtmp
/bin/cat /dev/null > /var/log/lastlog
/bin/cat /dev/null > /var/log/grubby

# fix vmware customization not running 
rm -f /etc/redhat-release 
touch /etc/redhat-release 
echo "Red Hat Enterprise Linux Server release 7.0 (Maipo)" > /etc/redhat-release

#remove old kernels
/bin/package-cleanup -y --oldkernels --count=1

# clean yum cache
/usr/bin/yum clean all

#remove udev hardware rules
/bin/rm -f /etc/udev/rules.d/70*

#remove nic mac addr and uuid from ifcfg scripts
/bin/sed -i "/^\(HWADDR\|UUID\)=/d" /etc/sysconfig/network-scripts/ifcfg-eth0
# this was /bin/sed -i "/^\(HWADDR\|UUID\)=/d" /etc/sysconfig/network-scripts/ifcfg-eno16777984

# clean out /tmp
/bin/rm -rf /tmp/*
/bin/rm -rf /var/tmp/*

#remove host keys (important step security wise.  similar to system GUID in Windows)
/bin/rm -f /etc/ssh/*key*

# remove the root user’s SSH history & other 
/bin/rm -rf ~root/.ssh/
/bin/rm -f ~root/anaconda-ks.cfg

#remove root users shell history
/bin/rm -f ~root/.bash_history
unset HISTFILE

#setting the root password age to 0 
chage -d 0 root

# consider using sys-unconfig (http://www.cyberciti.biz/faq/redhat-rhel-centos-fedora-linux-sys-unconfig-command/)
# sys-unconfig

#and lets shutdown
init 0