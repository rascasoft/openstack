#!/bin/bash

source environment

# OSP8 workaround otherwise undercloud installation will fail
if [ "$OPENSTACK_VERSION" == "osp8" ]
 then
  sudo rpm -Uvh http://download.devel.redhat.com/brewroot/packages/instack-undercloud/2.2.1/2.el7ost/noarch/instack-undercloud-2.2.1-2.el7ost.noarch.rpm
  sudo yum -y install selinux-policy-devel
fi

echo "$(date) Undercloud installlation"
time openstack undercloud install
[ $? -ne 0 ] && exit 1

echo "###############################################"
echo "$(date) Configuring external bridge access"

function parse_yaml {
   local prefix=$2
   local s='[[:space:]]*' w='[a-zA-Z0-9_]*' fs=$(echo @|tr @ '\034')
   sed -ne "s|^\($s\):|\1|" \
        -e "s|^\($s\)\($w\)$s:$s[\"']\(.*\)[\"']$s\$|\1$fs\2$fs\3|p" \
        -e "s|^\($s\)\($w\)$s:$s\(.*\)$s\$|\1$fs\2$fs\3|p"  $1 |
   awk -F$fs '{
      indent = length($1)/2;
      vname[indent] = $2;
      for (i in vname) {if (i > indent) {delete vname[i]}}
      if (length($3) > 0) {
         vn=""; for (i=0; i<indent; i++) {vn=(vn)(vname[i])("_")}
         printf("%s%s%s=\"%s\"\n", "'$prefix'",vn, $2, $3);
      }
   }'
}

eval $(parse_yaml network-environment.yaml)

# Creating device for accessing external API network from undercloud
sudo ovs-vsctl add-port br-ctlplane vlan$parameter_defaults_ExternalNetworkVlanID tag=$parameter_defaults_ExternalNetworkVlanID -- set interface vlan$parameter_defaults_ExternalNetworkVlanID type=internal
sudo ip link set dev vlan$parameter_defaults_ExternalNetworkVlanID up
sudo ip addr add $parameter_defaults_ExternalInterfaceDefaultRoute/24 dev vlan$parameter_defaults_ExternalNetworkVlanID
sudo iptables -A BOOTSTACK_MASQ -s $parameter_defaults_ExternalNetCidr ! -d $parameter_defaults_ExternalNetCidr -j MASQUERADE -t nat
