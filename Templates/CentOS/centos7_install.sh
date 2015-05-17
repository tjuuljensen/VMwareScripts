#!/bin/bash 
#
#run as superuser
#sudo -i

#update packages
yum -y update

# install missing packages 
yum -y install wget net-tools nano yum-utils

# install vmware packaging public keys
mkdir /tmp/vmware-keys
cd /tmp/vmware-keys
wget http://packages.vmware.com/tools/keys/VMWARE-PACKAGING-GPG-DSA-KEY.pub
wget http://packages.vmware.com/tools/keys/VMWARE-PACKAGING-GPG-RSA-KEY.pub
rpm --import /tmp/vmware-keys/VMWARE-PACKAGING-GPG-DSA-KEY.pub
rpm --import /tmp/vmware-keys/VMWARE-PACKAGING-GPG-RSA-KEY.pub

# create vmware-tools.repo
touch /etc/yum.repos.d/vmware-tools.repo
echo "[vmware-tools]" > /etc/yum.repos.d/vmware-tools.repo
echo "name = VMware Tools" >> /etc/yum.repos.d/vmware-tools.repo
echo "baseurl = http://packages.vmware.com/packages/rhel7/x86_64/" >> /etc/yum.repos.d/vmware-tools.repo
echo "enabled = 1" >> /etc/yum.repos.d/vmware-tools.repo
echo "gpgcheck = 1" >> /etc/yum.repos.d/vmware-tools.repo

# install vmware tools and deploypkg
yum -y install open-vm-tools open-vm-tools-deploypkg 

# restart vmwaretools plugin
systemctl restart vmtoolsd

