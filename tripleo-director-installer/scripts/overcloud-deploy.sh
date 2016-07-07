#!/bin/bash

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

set -eux

source environment

source stackrc 

: ${LIGHTWEIGHT:=""}
: ${SSL_ENABLE:=""}
: ${DEPLOY_ARGS:="-e /usr/share/openstack-tripleo-heat-templates/environments/puppet-pacemaker.yaml -e /usr/share/openstack-tripleo-heat-templates/environments/network-isolation.yaml -e /usr/share/openstack-tripleo-heat-templates/environments/net-single-nic-with-vlans.yaml -e /home/stack/network-environment.yaml"}
: ${DEPLOY_EXTRA_ARGS:="--neutron-bridge-mappings datacentre:br-floating"}

# If LIGHTWEIGHT is enabled, change DEPLOY_ARGS
[ "x$LIGHTWEIGHT" != "x" ] && DEPLOY_ARGS="-e /home/stack/wip-mitaka-lightweight-arch -e /home/stack/wip-mitaka-lightweight-arch/environments/puppet-pacemaker.yaml -e /home/stack/wip-mitaka-lightweight-arch/environments/network-isolation.yaml -e /home/stack/wip-mitaka-lightweight-arch/environments/net-single-nic-with-vlans.yaml"

# Mitaka workaround otherwise overcloud deploy will fail
if [ "$OPENSTACK_VERSION" == "mitaka" ]
 then
  if [ "x$LIGHTWEIGHT" != "x" ]
   then
    git clone https://github.com/mbaldessari/tripleo-heat-templates.git -b wip-mitaka-lightweight-arch wip-mitaka-lightweight-arch
   else
    git clone https://git.openstack.org/openstack/tripleo-heat-templates.git
  fi
fi

DEPLOY_ENV_YAML=/tmp/deploy_env.yaml
DEPLOY_ENV_YAML_EXTRAS=""

if [ "$OPENSTACK_VERSION" != "osp7" ]
 then
  DEPLOY_ENV_YAML_EXTRAS="
    # HeatWorkers doesn't modify num_engine_workers, so handle
    # via heat::config
    heat::config::heat_config:
      DEFAULT/num_engine_workers:
        value: 1"
fi

# Set most service workers to 1 to minimise memory usage on
# the deployed overcloud when using the pingtest. We use this
# test over tempest when we are memory constrained, ie the HA jobs.
cat > $DEPLOY_ENV_YAML << EOENV
parameter_defaults:
  controllerExtraConfig:$DEPLOY_ENV_YAML_EXTRAS
    heat::api_cloudwatch::enabled: false
    heat::api_cfn::enabled: false
  HeatWorkers: 1
  CeilometerWorkers: 1
  CinderWorkers: 1
  GlanceWorkers: 1
  KeystoneWorkers: 1
  NeutronWorkers: 1
  NovaWorkers: 1
  SwiftWorkers: 1
EOENV

openstack overcloud deploy --libvirt-type=kvm --ntp-server 10.5.26.10 --control-scale $CONTROLLERS --compute-scale $COMPUTES --ceph-storage-scale $STORAGE --block-storage-scale 0 --swift-storage-scale 0 --control-flavor baremetal --compute-flavor baremetal --ceph-storage-flavor baremetal --block-storage-flavor baremetal --swift-storage-flavor baremetal --templates $DEPLOY_ARGS $SSL_ENABLE $DEPLOY_EXTRA_ARGS \
    ${DEPLOY_ENV_YAML:+-e $DEPLOY_ENV_YAML} || /bin/true

overcloud_status=$(heat stack-list | grep overcloud | awk '{print $6}')
if [ "$overcloud_status" == "CREATE_COMPLETE" ]
 then
  echo "Overcloud deploy completed with success."
 else
  echo "Overcloud deploy not completed. ERROR!"
  exit 1 
fi

echo "###############################################"
echo "$(date) Starting overcloud post operations"

# Post operations
cat >> ~/.ssh/config <<EOF
Host 192.0.2.*
StrictHostKeyChecking no
UserKnownHostsFile=/dev/null
User heat-admin
port 22 
EOF
