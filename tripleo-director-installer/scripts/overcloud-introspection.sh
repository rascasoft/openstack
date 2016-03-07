#!/bin/bash

source stackrc

echo "$(date) Uploading images"
openstack overcloud image upload --image-path /home/stack/images/ 
[ $? -ne 0 ] && exit 1

echo "$(date) Updating neutron subnet with DNS"
netid=$(neutron subnet-list | grep -v "+" |grep -v cidr | awk '{print $2}')
neutron subnet-update $netid --dns-nameserver 10.16.36.29
[ $? -ne 0 ] && exit 1

echo "$(date) Verifying instackenv.json"
json_verify < instackenv.json
[ $? -ne 0 ] && exit 1

echo "$(date) Importing instackenv.json"
openstack baremetal import --json ~/instackenv.json
[ $? -ne 0 ] && exit 1

echo "$(date) Configuring boot for introspection"
openstack baremetal configure boot
[ $? -ne 0 ] && exit 1

echo "$(date) Introspectioning..."
openstack baremetal introspection bulk start
[ $? -ne 0 ] && exit 1

echo "$(date) Creating flavor baremetal"
openstack flavor create --id auto --ram 4096 --disk 40 --vcpus 4 baremetal

echo "$(date) Updating capabilities of flavor baremetal"
openstack flavor set --property "cpu_arch"="x86_64" --property "capabilities:boot_option"="local" --property "capabilities:profile"="baremetal" baremetal
[ $? -ne 0 ] && exit 1

ids="$(ironic node-list --detail | grep pxe_ipmi | awk '{print $(NF-3)}')"
for i in $ids; do
  echo "$(date) Updating node $i"
  ironic node-update $i add properties/capabilities='profile:baremetal,boot_option:local'
  [ $? -ne 0 ] && exit 1
done
