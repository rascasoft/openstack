#!/bin/bash

echo "$(date) Generating images"
source stackrc 
mkdir -p ~/images
cd ~/images
export NODE_DIST=centos7
export USE_DELOREAN_TRUNK=1
export DELOREAN_TRUNK_REPO="http://trunk.rdoproject.org/centos7/current-tripleo/"
export DELOREAN_REPO_FILE="delorean.repo"
openstack overcloud image build --all

echo "$(date) Installing libguestfs-tools"
sudo yum -y install libguestfs-tools.noarch

echo "$(date) Changing root password of the overcloud"
virt-customize --root-password password:redhat -a overcloud-full.qcow2
