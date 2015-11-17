# OSPd Network considerations

The default network configuration for OSPd is to have one *flat* network named **datacentre** associated with **br-ex** which is the same interface used for the external network api interface.

This is wrote into the configurations of two specific files under the controllers machines:

* */etc/neutron/plugins/openvswitch/ovs_neutron_plugin.ini*:

    datacentre:br-ex

* */etc/neutron/plugins/ml2/ml2_conf.ini*:

    flat_networks: datacentre

But what happens if you don't want to share the external API network (dedicated to the services running into the overcloud, like Horizon) with the external floating IP network (dedicate to the exposition of the instances)?

I this case for the dev br-ex you need to declare (into *nic-configs/controller.yaml*) a new bridged device:

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

associated with the interested network interface and use this settings:

* */etc/neutron/plugins/openvswitch/ovs_neutron_plugin.ini*:

    mappings: flat_networks=datacentre:br-ex,floating:br-floating

* */etc/neutron/plugins/ml2/ml2_conf.ini*:

    flat_networks: datacentre,floating

and then invoke the overcloud deployment passing explicitly the mappings you want to use:

    openstack overcloud deploy [...] --neutron-bridge-mappings datacentre:br-ex,floating:br-floating --neutron-flat-networks datacentre,floating

But it is possible to simplify things, associating the mappings directly to the newly created bridge:

* */etc/neutron/plugins/openvswitch/ovs_neutron_plugin.ini*

    mappings: floating:br-float

* */etc/neutron/plugins/ml2/ml2_conf.ini*

    flat_networks: floating

Invoking the deployment command in this way:

    openstack overcloud deploy [...] --neutron-bridge-mappings floating:br-floating --neutron-flat-networks floating

Or, **more simply**, associating the default datacentre flat network to the newly created bridge:

* */etc/neutron/plugins/openvswitch/ovs_neutron_plugin.ini*

    mappings: datacentre:br-float

Invoking the deployment with these options:

    openstack overcloud deploy [...] --neutron-bridge-mappings datacentre:br-floating