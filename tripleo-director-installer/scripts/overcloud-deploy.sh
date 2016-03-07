#!/bin/bash

source environment

source stackrc 

# The default configuration is to have one flat network named datacentre associated with br-ex:
#
#   /etc/neutron/plugins/openvswitch/ovs_neutron_plugin.ini -> mappings: datacentre:br-ex
#   /etc/neutron/plugins/ml2/ml2_conf.ini -> flat_networks: datacentre
#
# If you don't want to share the external API network (dedicated to the services running into the overcloud like Horizon)
# with the external floating IP network (dedicate to the exposition of the instances) in the dev br-ex you need to declare
# a new bridged device (see nic-configs/controller.br-float-nic1_others-nic2.yaml) associated with the interested network
# interface and use this settings:
#
#   /etc/neutron/plugins/openvswitch/ovs_neutron_plugin.ini -> mappings: flat_networks=datacentre:br-ex,floating:br-floating
#   /etc/neutron/plugins/ml2/ml2_conf.ini -> flat_networks: datacentre,floating
#   openstack overcloud deploy [...] --neutron-bridge-mappings datacentre:br-ex,floating:br-floating --neutron-flat-networks datacentre,floating
# 
# But it is possible to simplify things, associating the mappings directly to the newly created bridge:
#
#   /etc/neutron/plugins/openvswitch/ovs_neutron_plugin.ini -> mappings: floating:br-float
#   /etc/neutron/plugins/ml2/ml2_conf.ini -> flat_networks: floating
#   openstack overcloud deploy [...] --neutron-bridge-mappings floating:br-floating --neutron-flat-networks floating
#
# Or more simply associating the default datacentre flat network to the newly created bridge:
#
#   /etc/neutron/plugins/openvswitch/ovs_neutron_plugin.ini -> mappings: datacentre:br-float
#   openstack overcloud deploy [...] --neutron-bridge-mappings datacentre:br-floating

# Mitaka workaround otherwise overcloud deploy will fail
if [ "$OPENSTACK_VERSION" == "mitaka" ]
 then
  git clone https://git.openstack.org/openstack/tripleo-heat-templates.git
fi

# If SSL is enabled pass all the necessary options
if [ "x$SSL_ENABLE" != "x" ]
 then
  time openstack overcloud deploy --libvirt-type=kvm --ntp-server 10.5.26.10 --control-scale $CONTROLLERS --compute-scale $COMPUTES --ceph-storage-scale $STORAGE --block-storage-scale 0 --swift-storage-scale 0 --control-flavor baremetal --compute-flavor baremetal --ceph-storage-flavor baremetal --block-storage-flavor baremetal --swift-storage-flavor baremetal --templates -e /usr/share/openstack-tripleo-heat-templates/environments/puppet-pacemaker.yaml -e /usr/share/openstack-tripleo-heat-templates/environments/network-isolation.yaml -e /usr/share/openstack-tripleo-heat-templates/environments/net-single-nic-with-vlans.yaml -e /home/stack/network-environment.yaml -e /home/stack/enable-tls.yaml -e /home/stack/cloudname.yaml -e /home/stack/inject-trust-anchor.yaml --neutron-bridge-mappings datacentre:br-floating
 else
  time openstack overcloud deploy --libvirt-type=kvm --ntp-server 10.5.26.10 --control-scale $CONTROLLERS --compute-scale $COMPUTES --ceph-storage-scale $STORAGE --block-storage-scale 0 --swift-storage-scale 0 --control-flavor baremetal --compute-flavor baremetal --ceph-storage-flavor baremetal --block-storage-flavor baremetal --swift-storage-flavor baremetal --templates -e /usr/share/openstack-tripleo-heat-templates/environments/puppet-pacemaker.yaml -e /usr/share/openstack-tripleo-heat-templates/environments/network-isolation.yaml -e /usr/share/openstack-tripleo-heat-templates/environments/net-single-nic-with-vlans.yaml -e /home/stack/network-environment.yaml --neutron-bridge-mappings datacentre:br-floating
fi

overcloud_status=$(heat stack-list | grep overcloud | awk '{print $6}')
if [ "$overcloud_status" == "CREATE_COMPLETE" ]
 then
  echo "Overcloud deploy completed with success."
 else
  echo "Overcloud deploy not completed. ERROR!"
  exit 1 
fi

echo "###############################################"
echo "$(date) Overcloud network deployment"

source overcloudrc

neutron net-create floating-network --router:external --provider:physical_network datacentre --provider:network_type flat
neutron subnet-create --name floating-subnet --enable_dhcp=False --allocation-pool=start=$FLOATING_RANGE_START,end=$FLOATING_RANGE_END --gateway=$FLOATING_GW floating-network $FLOATING_SUBNET
neutron net-create private-network
neutron subnet-create private-network 10.1.1.0/24 --name private-subnet
neutron router-create floating-router
neutron router-interface-add floating-router private-subnet
neutron router-gateway-set floating-router floating-network
neutron security-group-create pingandssh
securitygroup_id=$(neutron security-group-list | grep pingandssh | head -1 | awk '{print $2}')
neutron security-group-rule-create  --direction ingress --protocol tcp --port-range-min 22 --port-range-max 22 $securitygroup_id
neutron security-group-rule-create --protocol icmp --direction ingress $securitygroup_id
floatingip=$(neutron floatingip-create floating-network | grep floating_ip_address | awk '{print $4}')

#[stack@mrg-06 ~]$ neutron net-list                                                                                                                 
#...
#| 6fde7d2a-e2d9-4b0f-a982-b7cbc3244807 | private-network                                    | 31a5ccd5-07bd-4103-a4a3-ab2c6d6148d7 10.1.1.0/24      |
#...
private_net_id=$(neutron net-list | grep private-network | awk '{print $2}')
wget http://download.cirros-cloud.net/0.3.4/cirros-0.3.4-x86_64-disk.img
glance image-create --name CirrOS --container-format bare --disk-format raw --file cirros-0.3.4-x86_64-disk.img --is-public True
nova boot --image CirrOS --flavor m1.medium --security-groups pingandssh --nic net-id=$private_net_id cirros-1                                                                 

#[stack@mrg-06 ~]$ nova list
#...
#| eb29c1a1-c30e-4f8f-91ea-cec1fd38c088 | cirros-1 | BUILD  | spawning   | NOSTATE     | private-network=10.1.1.5 |
#...
instance_ip=$(nova list | grep cirros-1 | awk '{print $12}' | sed "s/private-network=//g")

#[stack@mrg-06 ~]$ neutron port-list
#...
#| 61ce215d-3dc7-4873-af73-342620cdc3b6 |                                                 | fa:16:3e:8d:8b:8d | {"subnet_id": "31a5ccd5-07bd-4103-a4a3-ab2c6d6148d7", "ip_address": "10.1.1.5"}      |
#...
port_id=$(neutron port-list | grep $instance_ip | awk '{print $2}')

#[stack@mrg-06 ~]$ neutron floatingip-list
#...
#| 624f5256-ee89-438f-8335-904017e74a18 |                  | 10.16.144.77        |         |
#...
floatingip_id=$(neutron floatingip-list | grep $floatingip | awk '{print $2}')
neutron floatingip-associate $floatingip_id $port_id

echo "###############################################"
echo "$(date) Instance will be available at the IP $floatingip"

# Post operations
cat >> ~/.ssh/config <<EOF
Host 192.0.2.*
StrictHostKeyChecking no
UserKnownHostsFile=/dev/null
User heat-admin
port 22 
EOF
