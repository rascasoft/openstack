#Instance HA on OSPd
This documents intent is to make some light over the Instance HA functionality that can be added by following <a href="https://access.redhat.com/articles/1544823" target="_blank">the official Red Hat Knowledge Base article</a> into an Red Hat OpenStack Platform Director (OSPd) setup.

When configuring Instance HA inside OSPd, you need to add some new resources into the cluster that you may never have heard about.

##How Instance HA works

###Key resource agents
Here's the list:

- fence_compute (named **fence-nova** inside the cluster): which takes care of marking a compute node with the attrib"evacuate";
- NovaEvacuate (named **nova-evacuate** inside the cluster): which takes care of the effective evacuation of the instances and runs on one of the controllers;
- nova-compute-wait (named **nova-compute-checkevacuate** inside the cluster): which waits for eventual evacuation before starting nova compute services and runs on each compute nodes;

Following the KB article you will notice that other systemd resources will be added into the cluster on the compute nodes (specifically *neutron-openvswitch-agent*, *libvirtd*, *openstack-ceilometer-compute* and *nova-compute*), but the keys for the correct instance HA comprehension are these three resources.

###Evacuation
The principle under which Instance HA works is *evacuation*. This means that when a host, for any reason, becomes unavailable instance on it are evacuated, which means moved to a new available host.
Instance HA works both on shared storage and local storage environment, which means that evacuated instances will maintain the same network setup (static ip, floating ip and so on) and characteristics inside the new host, even if them will be spawned from scratch.

##What happens when a compute node is lost
Once configured, how the system behaves when evacuation is needed? This sequence describes the actions taken by the cluster and the OpenStack components:

1. A compute node (say compute-0) which is running instances gets lost for some reason (power outage, kernel panic, manual intervention);
2. The cluster starts the action sequence to fence this host, since it needs to be sure that the host is *really* down before driving any other operation. Setup is configured to have two levels of fencing for the compute hosts:

    * **IPMI**: which will occur first and will take care of physically reset the host;
    * **fence-nova**: which will occur second and will take care of marking evacuate=yes inside the cluster attributes;

    So the host gets reset and the cluster earn a new property like this:
    
        [root@overcloud-controller-0 ~]# attrd_updater -n evacuate -A
        name="evacuate" host="overcloud-compute-1.localdomain" value="yes"

3. At this point the resource **nova-evacuate** which constantly monitors the properties of the cluster in search of the evacuate tag finds out that compute-0 host needs evacuation, and by internally using nova-compute commands starts the action and the instances are recreated on another available host;
4. In the meantime, while compute-0 turns up again **nova-compute-checkevacuate** will wait (with a default timeout of 120 seconds) evacuation to complete to start in the chain the NovaCompute resource that will enable the fenced host to become available again for running instances;

##What to look for when something is not working
Here there are some tips to follow once you need to debug why instance HA is not working:

1. Check credentials: many resources requires access data the the overcloud coming form the overcloudrc file, so it's not so difficult to do copy errors;
2. Check connectivity: stonith is essential for cluster and if for some reason the cluster is not able to fence the compute nodes, all the instance HA environment will not work;
3. Check errors: inside the controller's cluster log (*/var/log/cluster/corosync.log*) some errors may catch the eye.