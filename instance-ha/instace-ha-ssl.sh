#!/bin/bash
echo "******************* Steps to reproduce the KB https://access.redhat.com/articles/1544823 into a deployed Liberty OPSd overcloud environment"

echo "******************* Parameters"
IPMIUSER=qe-scale
IPMIPASS=d0ckingSt4tion
SSH="ssh -o StrictHostKeyChecking=no"
SCP="scp -o StrictHostKeyChecking=no"
SSHUSER="heat-admin"
source stackrc
COMPUTES=$(nova list | egrep "overcloud-.*compute" | awk '{print $12}' | cut -f2 -d=)
CONTROLLERS=$(nova list | grep overcloud-controller | awk '{print $12}' | cut -f2 -d=)
CONTROLLER=$(nova list | grep overcloud-controller | awk '{print $12}' | head -1 | cut -f2 -d=)

echo "******************* Stonith creation"
./create-stonith-from-instackenv.py instackenv.json > stonith-create.sh
$SCP ./stonith-create.sh $SSHUSER@$CONTROLLER:
$SSH $SSHUSER@$CONTROLLER "sudo bash ./stonith-create.sh"

#echo "******************* Fix bug https://bugzilla.redhat.com/show_bug.cgi?id=1283084"; sleep 10
#for NODE in $CONTROLLERS $COMPUTES; do $SSH heat-admin@$NODE "sudo sed -i 's/evacute/evacuate/' /sbin/fence_compute; sudo sed -i 's/evacute/evacuate/' '/usr/lib/ocf/resource.d/openstack/Nova*'"; done

#echo "******************* Fix bug https://bugzilla.redhat.com/show_bug.cgi?id=1285922"; sleep 10
#for NODE in $CONTROLLERS $COMPUTES; do $SSH heat-admin@$NODE "sudo sed -i -e 's/^verbose=.*/verbose=false/g' /etc/nova/nova.conf"; done

#echo "******************* Fix bug https://bugzilla.redhat.com/show_bug.cgi?id=1292856"; sleep 10
# Installing latest fence_compute
#wget https://github.com/beekhof/fence-agents/raw/master/fence/agents/compute/fence_compute.py
#sed -i -e "s/^sys.path.append.*/sys.path.append\(\"\/usr\/share\/fence\"\)/g" ./fence_compute.py
#for NODE in $COMPUTES $CONTROLLERS; do $SCP NovaEvacuate fence_compute.py heat-admin@$NODE:/tmp; $SSH heat-admin@$NODE "sudo cp /tmp/fence_compute.py /usr/sbin/fence_compute"; done
# Installing updated ocf agents and pacemaker release
#wget https://github.com/beekhof/openstack-resource-agents/raw/master/ocf/NovaCompute
#wget https://github.com/beekhof/openstack-resource-agents/raw/master/ocf/NovaEvacuate
#for NODE in $COMPUTES $CONTROLLERS; do $SSH heat-admin@$NODE "sudo cp /tmp/{NovaCompute,NovaEvacuate} /usr/lib/ocf/resource.d/openstack/"; done
echo "******************* Updating packages"
brew_root="http://10.16.36.64/brewroot/packages/"
resource_agents_pkgs="resource-agents"
resource_agents_major_version="3.9.5"
resource_agents_minor_version="54.el7_2.6"
fence_agents_pkgs="fence-agents-rhevm fence-agents-intelmodular fence-agents-apc-snmp fence-agents-common fence-agents-eps fence-agents-cisco-mds fence-agents-mpath fence-agents-ilo2 fence-agents-bladecenter fence-agents-wti fence-agents-emerson fence-agents-cisco-ucs fence-agents-kdump fence-agents-ibmblade fence-agents-ipdu fence-agents-ilo-moonshot fence-agents-ilo-ssh fence-agents-ifmib fence-agents-all fence-agents-vmware-soap fence-agents-rsa fence-agents-drac5 fence-agents-brocade fence-agents-scsi fence-agents-ilo-mp fence-agents-rsb fence-agents-compute fence-agents-ipmilan fence-agents-eaton-snmp fence-agents-apc fence-agents-hpblade"
fence_agents_major_version="4.0.11"
fence_agents_minor_version="27.el7_2.5"
pacemaker_pkgs="pacemaker pacemaker-cli pacemaker-cluster-libs pacemaker-doc pacemaker-libs pacemaker-nagios-plugins-metadata pacemaker-remote pacemaker-debuginfo"
pacemaker_major_version="1.1.13"
pacemaker_minor_version="10.el7_2.2"
for NODE in $COMPUTES $CONTROLLERS; do $SSH heat-admin@$NODE "
mkdir -p /tmp/new-rpms;
rm -f /tmp/new-rpms/*;
cd /tmp/new-rpms;
for pkg in $resource_agents_pkgs; do curl -O $brew_root/resource-agents/$resource_agents_major_version/$resource_agents_minor_version/x86_64/\$pkg-$resource_agents_major_version-$resource_agents_minor_version\.x86_64.rpm; done;
for pkg in $fence_agents_pkgs; do curl -O $brew_root/fence-agents/$fence_agents_major_version/$fence_agents_minor_version/x86_64/\$pkg-$fence_agents_major_version-$fence_agents_minor_version\.x86_64.rpm; done;
for pkg in $pacemaker_pkgs; do curl -O $brew_root/pacemaker/$pacemaker_major_version/$pacemaker_minor_version/x86_64/\$pkg-$pacemaker_major_version-$pacemaker_minor_version\.x86_64.rpm; done;
sudo yum -y localinstall *.rpm"; done

echo "******************* Fix bug https://bugzilla.redhat.com/show_bug.cgi?id=1275324 (increased timeout for systemd resources to 200s)"; sleep 10
$SSH heat-admin@$CONTROLLER "sudo pcs config | grep systemd | awk '{print \$2}' | while read RESOURCE; do sudo pcs resource update \$RESOURCE op start timeout=200s op stop timeout=200s; done"

#echo "******************* Fix bug https://bugzilla.redhat.com/show_bug.cgi?id=1288528"; sleep 10
#cat > oslo_1288528.patch <<EOF
#--- /usr/lib/python2.7/site-packages/oslo_service/service.py.old	2015-12-11 05:35:00.415842099 -0500
#+++ /usr/lib/python2.7/site-packages/oslo_service/service.py	2015-12-11 05:37:08.663065880 -0500
#@@ -352,11 +352,11 @@
#         # Setup child signal handlers differently
# 
#         def _sigterm(*args):
#-            SignalHandler().clear()
#+            self.signal_handler.clear()
#             self.launcher.stop()
# 
#         def _sighup(*args):
#-            SignalHandler().clear()
#+            self.signal_handler.clear()
#             raise SignalExit(signal.SIGHUP)
# 
#         self.signal_handler.clear()
#EOF
#for NODE in $CONTROLLERS $COMPUTES; do $SCP oslo_1288528.patch heat-admin@$NODE:/tmp/; done
#for NODE in $CONTROLLERS $COMPUTES; do $SSH heat-admin@$NODE "sudo patch -p1 /usr/lib/python2.7/site-packages/oslo_service/service.py /tmp/oslo_1288528.patch"; done

echo "******************* Step 1"; sleep 10
for NODE in $COMPUTES; do $SSH $SSHUSER@$NODE "sudo openstack-service stop; sudo openstack-service disable; sudo systemctl stop libvirtd; sudo systemctl disable libvirtd"; done

echo "******************* Step 2-3"; sleep 10
sudo dd if=/dev/urandom of=./authkey bs=4096 count=1
for NODE in $CONTROLLERS $COMPUTES; do $SCP ./authkey $SSHUSER@$NODE:/tmp/; ssh $SSHUSER@$NODE "sudo mkdir -p /etc/pacemaker/; sudo mv /tmp/authkey /etc/pacemaker/; sudo chown root:root /etc/pacemaker/authkey"; done

echo "******************* Step 4"; sleep 10
for NODE in $COMPUTES; do $SSH $SSHUSER@$NODE "sudo systemctl enable pacemaker_remote; sudo systemctl start pacemaker_remote"; done

echo "******************* Step 5-6 not necessary"; sleep 10

echo "******************* Step 7"; sleep 10
$SCP ./overcloudrc $SSHUSER@$CONTROLLER:
$SSH $SSHUSER@$CONTROLLER "source ./overcloudrc; sudo pcs resource create nova-evacuate ocf:openstack:NovaEvacuate auth_url=\$OS_AUTH_URL username=\$OS_USERNAME password=\$OS_PASSWORD tenant_name=\$OS_TENANT_NAME no_shared_storage=1"

echo "******************* Step 8"; sleep 10
$SSH $SSHUSER@$CONTROLLER "for i in \$(sudo pcs status | grep IP | awk '{ print \$1 }'); do sudo pcs constraint order start \$i then nova-evacuate ; done"
$SSH $SSHUSER@$CONTROLLER "for i in openstack-glance-api-clone neutron-metadata-agent-clone openstack-nova-conductor-clone; do sudo pcs constraint order start \$i then nova-evacuate require-all=false ; done"

echo "******************* Step 9 (with increased timeout)"; sleep 10
$SSH $SSHUSER@$CONTROLLER "sudo pcs resource disable openstack-keystone --wait=600"

echo "******************* Step 10-11"; sleep 10
$SSH $SSHUSER@$CONTROLLER "controllers=\$(sudo cibadmin -Q -o nodes | grep uname | sed s/.*uname..// | awk -F\\\" '{print \$1}'); for controller in \${controllers}; do sudo pcs property set --node \${controller} osprole=controller ; done"

echo "******************* Step 12-13"; sleep 10
$SSH $SSHUSER@$CONTROLLER "stonithdevs=\$(sudo pcs stonith | awk '{print \$1}'); for i in \$(sudo cibadmin -Q --xpath //primitive --node-path | tr ' ' '\n' | awk -F \"id='\" '{print \$2}' | awk -F \"'\" '{print \$1}' | uniq); do
    found=0
    if [ -n \"\$stonithdevs\" ]; then
        for x in \$stonithdevs; do
            if [ \$x = \$i ]; then
                found=1
            fi
        done
    fi
    if [ \$found = 0 ]; then
        sudo pcs constraint location \$i rule resource-discovery=exclusive score=0 osprole eq controller
    fi
done"

echo "******************* Step 14"; sleep 10
$SSH $SSHUSER@$CONTROLLER "sudo pcs resource create neutron-openvswitch-agent-compute systemd:neutron-openvswitch-agent --clone interleave=true --disabled --force"
$SSH $SSHUSER@$CONTROLLER "sudo pcs constraint location neutron-openvswitch-agent-compute-clone rule resource-discovery=exclusive score=0 osprole eq compute"
$SSH $SSHUSER@$CONTROLLER "sudo pcs constraint order start neutron-server-clone then neutron-openvswitch-agent-compute-clone require-all=false"
$SSH $SSHUSER@$CONTROLLER "sudo pcs resource create libvirtd-compute systemd:libvirtd --clone interleave=true --disabled --force"
$SSH $SSHUSER@$CONTROLLER "sudo pcs constraint location libvirtd-compute-clone rule resource-discovery=exclusive score=0 osprole eq compute"
$SSH $SSHUSER@$CONTROLLER "sudo pcs constraint order start neutron-openvswitch-agent-compute-clone then libvirtd-compute-clone"
$SSH $SSHUSER@$CONTROLLER "sudo pcs constraint colocation add libvirtd-compute-clone with neutron-openvswitch-agent-compute-clone"
$SSH $SSHUSER@$CONTROLLER "sudo pcs resource create ceilometer-compute systemd:openstack-ceilometer-compute --clone interleave=true --disabled --force"
$SSH $SSHUSER@$CONTROLLER "sudo pcs constraint location ceilometer-compute-clone rule resource-discovery=exclusive score=0 osprole eq compute"
$SSH $SSHUSER@$CONTROLLER "sudo pcs constraint order start openstack-ceilometer-notification-clone then ceilometer-compute-clone require-all=false"
$SSH $SSHUSER@$CONTROLLER "sudo pcs constraint order start libvirtd-compute-clone then ceilometer-compute-clone"
$SSH $SSHUSER@$CONTROLLER "sudo pcs constraint colocation add ceilometer-compute-clone with libvirtd-compute-clone"

$SSH $SSHUSER@$CONTROLLER "source ./overcloudrc; sudo pcs resource create nova-compute-checkevacuate ocf:openstack:nova-compute-wait auth_url=\$OS_AUTH_URL username=\$OS_USERNAME password=\$OS_PASSWORD tenant_name=\$OS_TENANT_NAME domain=localdomain no_shared_storage=1 op start timeout=300 --clone interleave=true --disabled --force"
$SSH $SSHUSER@$CONTROLLER "sudo pcs constraint location nova-compute-checkevacuate-clone rule resource-discovery=exclusive score=0 osprole eq compute"
$SSH $SSHUSER@$CONTROLLER "sudo pcs constraint order start openstack-nova-conductor-clone then nova-compute-checkevacuate-clone require-all=false"

$SSH $SSHUSER@$CONTROLLER "sudo pcs resource create nova-compute systemd:openstack-nova-compute --clone interleave=true --disabled --force"
$SSH $SSHUSER@$CONTROLLER "sudo pcs constraint location nova-compute-clone rule resource-discovery=exclusive score=0 osprole eq compute"

$SSH $SSHUSER@$CONTROLLER "sudo pcs constraint order start nova-compute-checkevacuate-clone then nova-compute-clone require-all=true"

$SSH $SSHUSER@$CONTROLLER "sudo pcs constraint order start nova-compute-clone then nova-evacuate require-all=false"
$SSH $SSHUSER@$CONTROLLER "sudo pcs constraint order start libvirtd-compute-clone then nova-compute-clone"
$SSH $SSHUSER@$CONTROLLER "sudo pcs constraint colocation add nova-compute-clone with libvirtd-compute-clone"

echo "******************* Step 15"; sleep 10
for COMPUTEID in $(nova list | egrep "overcloud-.*compute" | awk '{print $2}'); do
 COMPUTENAME=$(nova list | grep $COMPUTEID | awk '{print $4}')
 IPMINAME="ipmilan-$COMPUTENAME"
 for IRONICID in $(ironic node-list | grep $COMPUTEID | awk '{print $2}'); do 
  IPMIIP=$(ironic node-show $IRONICID | grep driver_info | sed "s/.*ipmi_address': u'\(.*\)',.*/\1/g")
  $SSH $SSHUSER@$CONTROLLER "sudo pcs stonith create $IPMINAME fence_ipmilan pcmk_host_list=$COMPUTENAME ipaddr=$IPMIIP login=$IPMIUSER passwd=$IPMIPASS lanplus=1 cipher=1 op monitor interval=60s;"
 done
done

echo "******************* Step 16"; sleep 10
$SSH $SSHUSER@$CONTROLLER "source ./overcloudrc; sudo pcs stonith create fence-nova fence_compute auth-url=\$OS_AUTH_URL login=\$OS_USERNAME passwd=\$OS_PASSWORD tenant-name=\$OS_TENANT_NAME domain=localdomain record-only=1 no_shared_storage=1 action=off --force"

echo "******************* Step 17"; sleep 10
$SSH $SSHUSER@$CONTROLLER "sudo pcs property set cluster-recheck-interval=1min"

echo "******************* Step 18"; sleep 10
RECONNECT_INTERVAL=$(expr $(expr $(echo $CONTROLLERS | wc -w) + 1) \* 60)
for COMPUTENAME in $(nova list | egrep "overcloud-.*compute" | awk '{print $4}'); do
 $SSH $SSHUSER@$CONTROLLER "sudo pcs resource create $COMPUTENAME ocf:pacemaker:remote reconnect_interval=$RECONNECT_INTERVAL op monitor interval=20; sudo pcs property set --node $COMPUTENAME osprole=compute; sudo pcs stonith level add 1 $COMPUTENAME ipmilan-$COMPUTENAME,fence-nova"
done


echo "******************* Step 19"; sleep 10
$SSH $SSHUSER@$CONTROLLER "sudo pcs resource enable openstack-keystone"
$SSH $SSHUSER@$CONTROLLER "sudo pcs resource enable neutron-openvswitch-agent-compute"
$SSH $SSHUSER@$CONTROLLER "sudo pcs resource enable libvirtd-compute"
$SSH $SSHUSER@$CONTROLLER "sudo pcs resource enable ceilometer-compute"
$SSH $SSHUSER@$CONTROLLER "sudo pcs resource enable nova-compute-checkevacuate"
$SSH $SSHUSER@$CONTROLLER "sudo pcs resource enable nova-compute"

echo "******************* Step 20"; sleep 10
sleep 60
$SSH $SSHUSER@$CONTROLLER "sudo pcs resource cleanup"
$SSH $SSHUSER@$CONTROLLER "sudo pcs status"

#$SSH $SSHUSER@$CONTROLLER "sudo pcs property set stonith-action=off"
#$SSH $SSHUSER@$CONTROLLER "sudo pcs resource update nova-evacuate op monitor interval=120s"
#$SSH $SSHUSER@$CONTROLLER "sudo sudo pcs stonith"
