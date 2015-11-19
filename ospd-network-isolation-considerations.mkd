# OSPd Network isolation considerations

When using [network isolation](http://docs.openstack.org/developer/tripleo-docs/advanced_deployment/network_isolation.html) how network are managed by OSPd can be understood by looking into the file *network-environment.yaml* which needs to be passed to the *openstack overcloud deploy* command with a content like this one:

    resource_registry:
      OS::TripleO::BlockStorage::Net::SoftwareConfig: /home/stack/nic-configs/cinder-storage.yaml
      OS::TripleO::Compute::Net::SoftwareConfig: /home/stack/nic-configs/compute.yaml
      OS::TripleO::Controller::Net::SoftwareConfig: /home/stack/nic-configs/controller.yaml
      OS::TripleO::ObjectStorage::Net::SoftwareConfig: /home/stack/nic-configs/swift-storage.yaml
      OS::TripleO::CephStorage::Net::SoftwareConfig: /home/stack/nic-configs/ceph-storage.yaml

    parameter_defaults:
      # Customize the IP subnets to match the local environment
      InternalApiNetCidr: 172.17.0.0/24
      StorageNetCidr: 172.18.0.0/24
      StorageMgmtNetCidr: 172.19.0.0/24
      TenantNetCidr: 172.16.0.0/24
      ExternalNetCidr: 172.20.0.0/24
      InternalApiNetworkVlanID: 2201
      StorageNetworkVlanID: 2203
      StorageMgmtNetworkVlanID: 2204
      TenantNetworkVlanID: 2202
      ExternalNetworkVlanID: 2205
      InternalApiAllocationPools: [{'start': '172.17.0.10', 'end': '172.17.0.200'}]
      StorageAllocationPools: [{'start': '172.18.0.10', 'end': '172.18.0.200'}]
      StorageMgmtAllocationPools: [{'start': '172.19.0.10', 'end': '172.19.0.200'}]
      TenantAllocationPools: [{'start': '172.16.0.10', 'end': '172.16.0.200'}]
      ExternalAllocationPools: [{'start': '172.20.0.10', 'end': '172.20.0.200'}]
      ExternalInterfaceDefaultRoute: 172.20.0.254
      ControlPlaneSubnetCidr: '24'
      ControlPlaneDefaultRoute: 192.0.2.1
      EC2MetadataIp: 192.0.2.1
      DnsServers: ["10.1.241.2"]
      NeutronExternalNetworkBridge: "''"

The resource_registry declaration reads for each component the files in the *nic-configs*. Those files  could be copied locally to the stack user directory on the Undercloud for example from the */usr/share/openstack-tripleo-heat-templates/network/config/single-nic-vlans/*.

The variables in "parameter_defaults" section applies a different default for any of the top-level or nested parameters. Most of the settings are self explaining, for each network we must declare the correspondent cidr, VLAN and IP allocation pools. In addition must exist a default router for the external interface.

The control plane network settings must correspond to the network class declared for the undercloud (in the *undercloud.conf* file user by the *openstack undercloud install* command) and the EC2MetadataIp can be safely assigned to the undercloud IP.

OSPd will deploy a default setup of one *flat* network named **datacentre** associated with **br-ex** which is the same interface used for the external network api interface. This means that the floating IPs network will be shared with public OpenStack APIs and Horzizon dashboard.
But this is not always the desiderata, generally it could make more sense having a separate bridge to manage the floating ip network. So, to make floating IP network using any bridge on the system we must assign "''" to *NeutronExternalNetworkBridge* variable. Otherwise the bridge used will be always **br-ex**.

The association between the **datacentre** network and the **bridge device** is managed inside the configuration of two specific files under the controllers machines:

* */etc/neutron/plugins/openvswitch/ovs_neutron_plugin.ini*:

    datacentre:br-ex

* */etc/neutron/plugins/ml2/ml2_conf.ini*:

    flat_networks: datacentre

And this is the default, but what happens if we don't want to share the external API network (dedicated to the services running into the overcloud, like Horizon) with the external floating IP network (dedicate to the exposition of the instances)?

I this case you need to declare (into *nic-configs/controller.yaml*) a new bridged device, named **br-floating**:

    ...
    ...
    resources:
      OsNetConfigImpl:
        type: OS::Heat::StructuredConfig
        properties:
          group: os-apply-config
          config:
            os_net_config:
              network_config:
                -
                  type: ovs_bridge
                  name: br-floating
                  use_dhcp: false
                  members:
                    -
                      type: interface
                      name: nic1
                -
                  type: ovs_bridge
                  name: {get_input: bridge_name}
                  use_dhcp: false
                  addresses:
                    -
                      ip_netmask:
                        list_join:
                          - '/'
                          - - {get_param: ControlPlaneIp}
                            - {get_param: ControlPlaneSubnetCidr}
                  routes:
                    -
                      ip_netmask: 169.254.169.254/32
                      next_hop: {get_param: EC2MetadataIp}
                  members:
                    -
                      type: interface
                      name: nic2
                      # force the MAC address of the bridge to this interface
                      primary: true
    ...
    ...

So, we are telling to the setup to keep *everything* on nic2 (em2) that will be associated to *br-ex* except for the *br-floating* interface with which we will expose out instances with floating IPs.

Our goal will be reached once we will set on the opensvswitch and ml2 file these settings:

* */etc/neutron/plugins/openvswitch/ovs_neutron_plugin.ini*:

    mappings: flat_networks=datacentre:br-ex,floating:br-floating

* */etc/neutron/plugins/ml2/ml2_conf.ini*:

    flat_networks: datacentre,floating

To create a new flat network named "floating" the overcloud deployment command will be invoked by passing explicitly the mappings we want to use:

    openstack overcloud deploy [...] --neutron-bridge-mappings datacentre:br-ex,floating:br-floating --neutron-flat-networks datacentre,floating

But it is possible to simplify things, associating the mappings directly to the newly created bridge, like this:

* */etc/neutron/plugins/openvswitch/ovs_neutron_plugin.ini*

    mappings: floating:br-float

* */etc/neutron/plugins/ml2/ml2_conf.ini*

    flat_networks: floating

Invoking the deployment command in this way:

    openstack overcloud deploy [...] --neutron-bridge-mappings floating:br-floating --neutron-flat-networks floating

Or, **more simply**, associating the default **datacentre** flat network to the newly created bridge:

* */etc/neutron/plugins/openvswitch/ovs_neutron_plugin.ini*

    mappings: datacentre:br-float

Invoking the deployment with these options:

    openstack overcloud deploy [...] --neutron-bridge-mappings datacentre:br-floating

Each one of the described settings will help us to reach our goal, what to choose depends on how much complexity we want to add to our setup.