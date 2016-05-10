#Instance HA on OSPd
This document's intent is to make some light over the Instance HA functionality that can be added by following <a href="https://access.redhat.com/articles/1544823" target="_blank">the official Red Hat Knowledge Base article</a> into an Red Hat OpenStack Platform Director (OSPd) setup.

When configuring Instance HA inside OSPd, you need to add some new resources into the cluster that you may never have heard about.

##How Instance HA works

###Key resource agents
Here's the list:

- fence_compute (named **fence-nova** inside the cluster): which takes care of marking a compute node with the attribute "evacuate" set to yes;
- NovaEvacuate (named **nova-evacuate** inside the cluster): which takes care of the effective evacuation of the instances and runs on one of the controllers;
- nova-compute-wait (named **nova-compute-checkevacuate** inside the cluster): which waits for eventual evacuation before starting nova compute services and runs on each compute nodes;

Following the KB article you will notice that other systemd resources will be added into the cluster on the compute nodes (specifically *neutron-openvswitch-agent*, *libvirtd*, *openstack-ceilometer-compute* and *nova-compute*), but the keys for the correct instance HA comprehension are the aforementioned three resources.

###Evacuation
The principle under which Instance HA works is *evacuation*. This means that when a host becomes unavailablea for whatever reason, instances on it are evacuated to an available host.
Instance HA works both on shared storage and local storage environments, which means that evacuated instances will maintain the same network setup (static ip, floating ip and so on) and characteristics inside the new host, even if they will be spawned from scratch.

##What happens when a compute node is lost
Once configured, how does the system behaves when evacuation is needed? The following sequence describes the actions taken by the cluster and the OpenStack components:

1. A compute node (say overcloud-compute-1) which is running instances goes down for some reason (power outage, kernel panic, manual intervention);
2. The cluster starts the action sequence to fence this host, since it needs to be sure that the host is *really* down before driving any other operation (otherwise there is potential for data corruption or multiple identical VMs running at the same time in the infrastructure). Setup is configured to have two levels of fencing for the compute hosts:

    * **IPMI**: which will occur first and will take care of physically resetting the host and hence assuring that the machine is really powered off;
    * **fence-nova**: which will occur afterwards and will take care of marking with a cluster per-node attribute "evacuate=yes";

    So the host gets reset and on the cluster a new node-property like the following will appear:
    
        [root@overcloud-controller-0 ~]# attrd_updater -n evacuate -A
        name="evacuate" host="overcloud-compute-1.localdomain" value="yes"

3. At this point the resource **nova-evacuate** which constantly monitors the attributes of the cluster in search of the evacuate tag will find out that the overcloud-compute-1 host needs evacuation, and by internally using nova-compute commands, will start the evactuation of the instances towards another host;
4. In the meantime, while compute-1 is booting up again, **nova-compute-checkevacuate** will wait (with a default timeout of 120 seconds) for the evacuation to complete before starting the chain via the NovaCompute resource that will enable the fenced host to become available again for running instances;

##What to look for when something is not working
Here there are some tips to follow once you need to debug why instance HA is not working:

1. Check credentials: many resources require access data the the overcloud coming form the overcloudrc file, so it's not so difficult to do copy errors;
2. Check connectivity: stonith is essential for cluster and if for some reason the cluster is not able to fence the compute nodes, the whole instance HA environment will not work;
3. Check errors: inside the controller's cluster log (*/var/log/cluster/corosync.log*) some errors may catch the eye.
