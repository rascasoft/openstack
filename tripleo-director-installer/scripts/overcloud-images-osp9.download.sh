#!/bin/bash

echo "$(date) Retrieving images"
source stackrc 
mkdir ~/images
cd ~/images
lftp http://rhos-release.virt.bos.redhat.com/puddle-images/9.0/latest-images/ << EOF
mget *
quit 0
EOF
for i in *.tar; do
tar xvfp $i 
done

echo "$(date) Checking libvirtd"
sudo systemctl is-active libvirtd &> /dev/null
[ $? -ne 0 ] && sudo systemctl restart libvirtd

echo "$(date) Installing libguestfs-tools"
sudo yum -y install libguestfs-tools.noarch

echo "$(date) Changing root password of the overcloud"
virt-customize --root-password password:redhat -a overcloud-full.qcow2
