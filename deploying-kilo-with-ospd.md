# Deploying OpenStack Kilo with OSPd

## What we are going to do

These steps describe a way to deploy an overcloud environment using OSPd with OpenStack Kilo.

The deployment will be done on a baremetal environment composed by 5 machines:

* 1 Undercloud node
* 3 Controller nodes
* 1 Compute node

Each of these machines has got 2 nics. The first one, named em1, reach the internal LAN, the second one, named em2, will be used for overcloud provisioning, internal networks and external api access. This setup will be summarized in a file called network-environment.yaml which will be treated in the [overcloud deployment](#step-5---overcloud-deploy).

## Step 1: Undercloud provisioning:

This step strongly depends on which way you provide your machine. Even if it is an automated way or a manual provisioning, what is important is to have an up-to-date installation of Red Hat Enterprise Linux 7.

It strongly recommended that the Undercloud has got *all* the last updates, avoiding known bugs and obtaining the last features, so it would be very useful to launch an update before continuing:

    yum -y update

Once the machine is installed and reachable it is possible to run for the next step.

## Step 2 - Undercloud preparation

The undercloud host needs to be prepared in many ways.
First a **stack** user must be created, this user will be used for all the operations by OSPd:

    useradd stack
    echo stack | passwd --stdin stack
    echo "stack ALL=(root) NOPASSWD:ALL" | tee -a /etc/sudoers.d/stack
    chmod 0440 /etc/sudoers.d/stack
    mkdir /home/stack/.ssh
    cp /root/.ssh/authorized_keys /home/stack/.ssh/
    chown stack:stack /home/stack/.ssh -R
    chmod 700 /home/stack/.ssh
    chmod 600 /home/stack/.ssh/authorized_keys

Some packages needs to be removed/configured/installed:

    yum install -y ntp vim tmux
    yum erase -y chrony
    rm -f /etc/chrony* 
    sed -i s/^server.*// /etc/ntp.conf
    echo "server clock.redhat.com iburst" >> /etc/ntp.conf
    echo clock.redhat.com > /etc/ntp/step-tickers
    echo "SYNC_HWCLOCK=yes" >> /etc/sysconfig/ntpdate 
    systemctl enable ntpdate
    systemctl enable ntpd 
    systemctl disable firewalld

And the hostname must be setup so it will be always resolved:

    hostnamectl set-hostname mrg-06.mpc.lab.eng.bos.redhat.com
    hostnamectl set-hostname --transient mrg-06.mpc.lab.eng.bos.redhat.com
    sed -i '/127.0.0.1/d' /etc/hosts
    echo '127.0.0.1   localhost localhost.localdomain localhost4  localhost4.localdomain4 macb8ca3a66f440 macb8ca3a66f440.example.com'  >> /etc/hosts

Finally it cames the most important part, which is the repositories configuration:

    yum install -y http://rhos-release.virt.bos.redhat.com/repos/rhos-release/rhos-release-latest.noarch.rpm
    rhos-release 7
    rhos-release 7-director
    yum install -y yum-utils
    yum-config-manager --enable rhelosp-rhel-7-server-opt
    yum clean all
    yum install -y python-rdomanager-oscplugin

These seven commands are quite clear: the first one installs the rpm containing the OSPd repositories, the second and the third sets the Red Hat OpenStack release (also for the Director) version which we want to use (in this case the Kilo one, so 7), then yum-utils package is installed to be able to enable the rhelosp-rhel-7-server-opt repository. Once all the metadatas are cleaned it is good to install the Director itself.

## Step 3 - Undercloud installation

Before proceeding with the Undercloud installation a file named *undercloud.conf* must be created in the directory in which we want to launch the installation. The contents of this file strongly depends on how we want to manage the undercloud network. As an example, the file should contain something like this:

    [DEFAULT]
    local_ip = 192.0.2.1/24
    undercloud_public_vip = 192.0.2.2
    undercloud_admin_vip = 192.0.2.3
    #undercloud_service_certificate = /etc/pki/instack-certs/undercloud.pem
    local_interface = em2
    masquerade_network = 192.0.2.0/24
    dhcp_start = 192.0.2.5
    dhcp_end = 192.0.2.24
    network_cidr = 192.0.2.0/24
    network_gateway = 192.0.2.1
    discovery_interface = br-ctlplane
    discovery_iprange = 192.0.2.100,192.0.2.120
    [auth]

Once this file reflects our needs, we can install the undercloud:

    openstack undercloud install

If this steps fails for some reason (which needs to be analyzed case per case) then **the command can be launched again**. So, if the problem is that you need some package, once you install them, then you can safely relaunch the command.

The last step of the Undercloud installation will be to configure the overcloud's external api access from the undercloud machine. This will be done in 4 steps:

    sudo ovs-vsctl add-port br-ctlplane vlan25 tag=25 -- set interface vlan25 type=internal
    sudo ip link set dev vlan25 up
    sudo ip addr add 10.1.2.254/24 dev vlan25
    sudo iptables -A BOOTSTACK_MASQ -s 10.1.2.0/24 ! -d 10.1.2.0/24 -j MASQUERADE -t nat

The first one will add the vlan25 vlan to the br-ctlplane bridge interface, the second will bring this device up, the third will assign to this device a chosen ip that will make the undercloud machine able to access the external network api (see <a href="#step-5---overcloud-deploy">Step 5 - Overcloud deployment</a>) and the last one will configure iptables to MASQUERADE the traffic where the source is the interested network segment.

## Step 4 - Overcloud introspection

Once the Undercloud is ready, we need to prepare the machines to be provisioned by the undercloud itself. This process is named **introspection** and is done using ironic-inspector.

### Building images

The machines will be provided using an image which needs to be created starting from an existing one. Luckily there are some images available from the following repo, which can be used without the need of regenerate anything.
These steps can be used to retrieve them:

    source stackrc
    mkdir ~/images
    cd ~/images
    lftp http://rhos-release.virt.bos.redhat.com/mburns/latest-images/ << EOF
    mget *
    quit 0
    EOF
    for i in *.tar; do
    tar xvfp $i
    done

After the image retrieving it is *optional* to configure the password for the *overcloud-full* image root user:

    sudo yum -y install libguestfs-tools.noarch
    virt-sysprep --root-password password:redhat -a overcloud-full.qcow2

This will be useful in case our machines will be not reachable via network and just via console.
Finally it is possible to load the images into the overcloud provisioning system:

    openstack overcloud image upload --image-path /home/stack/images/

### Introspecting machines

The environment in which we want to deploy our overcloud MUST BE KNOWN. This mean you must be able to fill an instack.json file containg all the information of your environment. The format is this one:

    {
      "nodes":[
    {
      "mac": [ 
    "<IPMI MAC ADDRESS>" 
      ],
      "_comment":"<YOU CAN FILL THIS WITH IPMI FQDN>",
      "cpu": "",
      "memory": "",
      "disk": "",
      "arch": "x86_64",
      "pm_type":"pxe_ipmitool",
      "pm_user":"<IPMI USER>",
      "pm_password":"<IPMI PASSWORD>",
      "pm_addr":"<IMPI IP ADDR>"
    },  
    ...
    ...
      ]
    }

To be sure that you instackenv.json file is good, you can use 

    json_verify < instackenv.json

Remember that the syntax is VERY VERY important in this file, so never forget the correct indentation.

So, once the environment file is complete, we can start the *real* introspection, using these commands:

    openstack baremetal import --json ~/instackenv.json
    openstack baremetal configure boot
    openstack baremetal introspection bulk start

Depending on your hardware this step will take from 10 to 20 minutes (or maybe more).

### Introspection post operations

One more action is needed to complete the introspection part. The first one is the creation of a *flavor* for our baremetal nodes (and the following assignment to all of our introspected nodes):

    openstack flavor create --id auto --ram 8096 --disk 400 --vcpus 8 baremetal
    openstack flavor set --property "cpu_arch"="x86_64" --property "capabilities:boot_option"="local" --property "capabilities:profile"="baremetal" baremetal
    ids="$(ironic node-list --detail | grep pxe_ipmi | awk '{print $(NF-3)}')"
    
    for i in $ids; do
      ironic node-update $i replace properties/capabilities='profile:baremetal,boot_option:local'
    done

Obviously the capabilities of the machines are assigned using the lowest profile available. This means that in this specific example my machines will have *at least* 8 gigabyte of RAM and *at least* 8 cpu.

## Step 5 - Overcloud deploy

### Network environment preparation

As explained on top, before deployng the overcloud we need to create a network-environment.yaml file which will need to reside on the undercloud machine.
The contents of the file vary for each environment, see [OSPd Network Isolation Considerations](ospd-network-isolation-considerations.md) to understand how this can be managed.

### Overcloud effective deployment 

So at this point it will be possible to launch the overcloud deployment with this command:

    openstack overcloud deploy --templates --libvirt-type=kvm --ntp-server 10.5.26.10 --control-scale 3 --compute-scale 1 --ceph-storage-scale 0 --block-storage-scale 0 --swift-storage-scale 0 --control-flavor baremetal --compute-flavor baremetal --ceph-storage-flavor baremetal --block-storage-flavor baremetal --swift-storage-flavor baremetal  --templates -e /usr/share/openstack-tripleo-heat-templates/environments/network-isolation.yaml -e /usr/share/openstack-tripleo-heat-templates/environments/net-single-nic-with-vlans.yaml -e /home/stack/network-environment.yaml --neutron-bridge-mappings datacentre:br-floating

The options reflect what was defined at the top of this document: 3 controllers, 2 computes and 3 ceph nodes, we will use the flavor baremetal fo all the machines kind and we will use some specific templates:

* /usr/share/openstack-tripleo-heat-templates/environments/network-isolation.yaml so to be able to use a network isolated environment (See here *link* for more details);
* /usr/share/openstack-tripleo-heat-templates/environments/net-single-nic-with-vlans.yaml so to use all our vlans into one interface;
* /home/stack/network-environment.yaml so to use the setup declared on top of this document;

Last but not least we will associate our datacentre network segment to our br-floating interface, the one which resides on our LAN, so to be able to publish floating ips on LAN to expose OpenStack's deployed instances.

This command will take around 20 or 30 minutes to complete, depending on the hardware.

### Overcloud network deployment

To be able to test the network environment and so pushing instances into our LAN and make them visible and accessible we need to take some other steps, all related to neutron and all related to overcloud (look at the first source command):

    source ~/overcloudrc
    neutron net-create floating-network --router:external --provider:physical_network datacentre provider:network_type flat
    neutron subnet-create --name floating-subnet --enable_dhcp=False --allocation-pool=start=10.16.144.76,end=10.16.144.83 --gateway=10.16.151.254 floating-network 10.16.144.0/21
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

Making it as simple as possible: two networks with subnets were created, one internal, one external. There is a router which connects the private network to the floating one. There are security groups that will make possible to access to ssh and ping to newly created machines.

We can also choose to automate the creation of an instance, so to be able to check that everything is working:

    private_net_id=$(neutron net-list | grep private-network | awk '{print $2}')
    wget http://download.cirros-cloud.net/0.3.4/cirros-0.3.4-x86_64-disk.img
    glance image-create --name CirrOS --container-format bare --disk-format raw --file cirros-0.3.4-x86_64-disk.img --is-public True
    nova boot --image CirrOS --flavor m1.medium --security-groups pingandssh --nic net-id=$private_net_id cirros-1
    instance_ip=$(nova list | grep cirros-1 | awk '{print $12}' | sed "s/private-network=//g")
    port_id=$(neutron port-list | grep $instance_ip | awk '{print $2}')
    floatingip_id=$(neutron floatingip-list | grep $floatingip | awk '{print $2}')
    neutron floatingip-associate $floatingip_id $port_id
    echo "Instance will be available at the IP $floatingip"

So, the CirrOS machine will be on the private-network and will have a floating-ip associated. The last echo command will give us the IP to point to.

## Step 6 - Overcloud post operations"

Once all these steps are completed we can add to our stack user (in the undercloud) the ability to connect to all the overcloud machines automatically with the hea-admin user:

    cat >> ~/.ssh/config <<EOF
    Host 192.0.2.*
    StrictHostKeyChecking no
    UserKnownHostsFile=/dev/null
    User heat-admin
    port 22 
    EOF

At this point all the operations can be considered complete.