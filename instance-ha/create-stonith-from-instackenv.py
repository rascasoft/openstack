#!/bin/python

import os
import json
import sys
from pprint import pprint

# Environmenova variables (need to source before launching):
# export NOVA_VERSION=1.1
# export OS_PASSWORD=$(sudo hiera admin_password)
# export OS_AUTH_URL=http://192.0.2.1:5000/v2.0
# export OS_USERNAME=admin
# export OS_TENANT_NAME=admin
# export COMPUTE_API_VERSION=1.1
# export OS_NO_CACHE=True

# JSON format:
#{ "nodes": [
#{
#  "mac": [
#"b8:ca:3a:66:e3:82"
#  ],
#  "_comment":"host12-rack03.scale.openstack.engineering.redhat.com",
#  "cpu": "",
#  "memory": "",
#  "disk": "",
#  "arch": "x86_64",
#  "pm_type":"pxe_ipmitool",
#  "pm_user":"qe-scale",
#  "pm_password":"d0ckingSt4tion",
#  "pm_addr":"10.1.8.102"
#},
#...

# JSon file as first parameter
jdata = open(sys.argv[1])
data = json.load(jdata)

os_username = os.environ['OS_USERNAME']
os_password = os.environ['OS_PASSWORD']
os_auth_url = os.environ['OS_AUTH_URL']
os_tenant_name = os.environ['OS_TENANT_NAME']
os_compute_api_version = os.environ['COMPUTE_API_VERSION']

print('pcs property set stonith-enabled=false')

from novaclient import client
#nova = client.Client(VERSION, USER, PASSWORD, TENANT, AUTH_URL)
nova = client.Client(os_compute_api_version, os_username, os_password, os_tenant_name, os_auth_url)

from ironicclient import client
kwargs = {'os_username': os_username,'os_password': os_password,'os_auth_url': os_auth_url,'os_tenant_name': os_tenant_name}
ironic = client.get_client(1, **kwargs)

#print ironic.node.list() 
#print data["nodes"]

os.system("cat << END > create-virt-key.sh\nmkdir /etc/cluster/\necho redhat > /etc/cluster/fence_xvm.key\nEND")

hosts={}
for instance in nova.servers.list():
 print('pcs stonith delete stonith-{} || /bin/true'.format(instance.name))
 ironic_node=ironic.node.get_by_instance_uuid(instance.id)
 #ironic_node_mac=ironic.node.list_ports(ironic_node.uuid)[0].address
 if not ironic_node.driver_info.has_key("ipmi_address"):
  if instance.name.find("control") > 0:
   print('cat %s | ssh %s -- "cat > fence_prep.sh; sudo bash fence_prep.sh"' % ("create-virt-key.sh", instance.addresses["ctlplane"][0]["addr"]))
   ip = ironic_node.driver_info["ssh_address"]
   hosts[ip] = ip
 else:
   for node in data["nodes"]:
  #print ironic_node_mac, "-", node["mac"][0]
  #if (node["mac"][0] == ironic_node_mac and 'controller' in instance.name):
    if (node["pm_addr"] == ironic_node.driver_info["ipmi_address"] and 'controller' in instance.name):
     print('pcs stonith create stonith-{} fence_ipmilan pcmk_host_list="{}" ipaddr="{}" action="reboot" login="{}" passwd="{}" lanplus="true" delay=20 op monitor interval=60s'.format(instance.name,instance.name,node["pm_addr"],node["pm_user"],node["pm_password"]))
   #print('pcs stonith create stonith-{} fence_ipmilan pcmk_host_list="{}" ipaddr="{}" action="reboot" login="{}" passwd="{}" lanplus="true" delay=20 op monitor interval=60s'.format(instance.name,instance.name,ironic_node.driver_info["ipmi_address"],ironic_node.driver_info["ipmi_username"],ironic_node.driver_info["ipmi_password"]))

for host in hosts:
    virt_file="fence-{}-prep.sh".format(hosts[host])
    fence_virt_prep="""
wget http://download.eng.bos.redhat.com/brewroot/work/tasks/2585/10972585/fence-virt-{,debuginfo-}0.3.2-3.el7_2.x86_64.rpm
wget http://download.eng.bos.redhat.com/brewroot/work/tasks/2585/10972585/fence-virtd-{,libvirt-,multicast-,tcp-}0.3.2-3.el7_2.x86_64.rpm
yum install -y fence-*.rpm
mkdir /etc/cluster/
echo redhat > /etc/cluster/fence_xvm.key
chmod a+r /etc/cluster/fence_xvm.key
chmod a+rx /etc/cluster/
sed -i -e s/system/session/ -e s/multicast/tcp/ -e s/225.0.0.12/%s/ /etc/fence_virt.conf 
echo "User=stack" >> /usr/lib/systemd/system/fence_virtd.service
sed -i 's@FENCE_VIRTD_ARGS$@FENCE_VIRTD_ARGS -p /tmp/fence_virtd_stack.pid@' /usr/lib/systemd/system/fence_virtd.service
systemctl enable fence_virtd.service
service fence_virtd start
""" % host
    os.system("cat << END > %s\n%s\nEND" %(virt_file, fence_virt_prep))

    print('cat %s | ssh -l root %s -- "cat > fence_prep.sh; bash fence_prep.sh"' % (virt_file, host))
    print('pcs stonith create fence-overcloud-{} fence_virt ipaddr={}'.format(host, host))


print('pcs property set stonith-enabled=true')

jdata.close()
