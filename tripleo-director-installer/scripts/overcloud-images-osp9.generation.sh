#!/bin/bash

echo "$(date) Generating images"
source stackrc
mkdir -p ~/images
cd ~/images
#wget http://download.eng.bos.redhat.com/brewroot/packages/rhel-guest-image/7.2/20151102.0/images/rhel-guest-image-7.2-20151102.0.x86_64.qcow2
# image with bnx2 firmware
#wget http://mrg-05.mpc.lab.eng.bos.redhat.com/images/rhel-guest-image-7.2-20151102.0.x86_64.qcow2
wget http://download.eng.bos.redhat.com/brewroot/packages/rhel-guest-image/7.2/20160302.0/images/rhel-guest-image-7.2-20160302.0.x86_64.qcow2
export USE_DELOREAN_TRUNK=0
export RHOS=1
export DIB_LOCAL_IMAGE=rhel-guest-image-7.2-20160302.0.x86_64.qcow2
export DIB_CLOUD_IMAGES="http://download.eng.bos.redhat.com/brewroot/packages/rhel-guest-image/7.2/20160302.0/images/"
export DIB_YUM_REPO_CONF="/etc/yum.repos.d/rhos-release-9.repo  /etc/yum.repos.d/rhos-release-rhel-7.2.repo /etc/yum.repos.d/rhos-release-9-director.repo"
export DIB_CLOUD_INIT_ETC_HOSTS=false
openstack overcloud image build --all

echo "$(date) Checking libvirtd"
sudo systemctl is-active libvirtd &> /dev/null
[ $? -ne 0 ] && sudo systemctl restart libvirtd

echo "$(date) Installing libguestfs-tools"
sudo yum -y install libguestfs-tools.noarch

echo "$(date) Changing root password of the overcloud"
virt-customize --root-password password:redhat -a overcloud-full.qcow2
