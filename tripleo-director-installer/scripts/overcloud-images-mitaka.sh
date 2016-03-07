#!/bin/bash

echo "$(date) Retrieving images"
source stackrc
mkdir ~/images
cd ~/images
lftp https://ci.centos.org/artifacts/rdo/images/mitaka/delorean/stable/ << EOF
get overcloud-full.tar
get deploy-ramdisk-ironic.tar
get ironic-python-agent.tar
quit 0
EOF
for i in *.tar; do
tar xvfp $i
done

echo "$(date) Installing libguestfs-tools"
sudo yum -y install libguestfs-tools.noarch

echo "$(date) Checking libvirtd"
sudo systemctl is-active libvirtd &> /dev/null
[ $? -ne 0 ] && sudo systemctl restart libvirtd

echo "$(date) Downloading Latest Puppet modules"
git clone https://github.com/redhat-openstack/openstack-puppet-modules/ ~/modules

echo "$(date) Changing root password of the overcloud and pushing upstream modules"
virt-customize -a overcloud-full.qcow2 --delete /usr/share/openstack-puppet/modules/  --root-password password:redhat
virt-copy-in -a overcloud-full.qcow2 /home/stack/modules /usr/share/openstack-puppet/
