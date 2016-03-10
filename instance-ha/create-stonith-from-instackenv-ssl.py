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
os_cacert = os.environ['OS_CACERT']
os_tenant_name = os.environ['OS_TENANT_NAME']
os_compute_api_version = os.environ['COMPUTE_API_VERSION']

print('pcs property set stonith-enabled=false')

from novaclient import client
#nova = client.Client(VERSION, USER, PASSWORD, TENANT, AUTH_URL)
#nova = client.Client(os_compute_api_version, os_username, os_password, os_tenant_name, os_auth_url, insecure=True)
nova = client.Client(os_compute_api_version, os_username, os_password, os_tenant_name, os_auth_url, insecure=False, cacert=os_cacert)
#nova = client.Client(api_version=os_compute_api_version,'username'=os_username,'password'=os_password,'auth_url'=os_auth_url,'tenant_id'=os_tenant_name,'cacert'=os_cacert,'insecure'=False)

from ironicclient import client
kwargs = {'os_username': os_username,'os_password': os_password,'os_auth_url': os_auth_url,'os_tenant_name': os_tenant_name, 'insecure': False}
#kwargs = {'os_username': os_username,'os_password': os_password,'os_auth_url': os_auth_url,'os_tenant_name': os_tenant_name, 'insecure': True}
ironic = client.get_client(1, **kwargs)

#print ironic.node.list() 
#print data["nodes"]

for instance in nova.servers.list():
 ironic_node=ironic.node.get_by_instance_uuid(instance.id)
 #ironic_node_mac=ironic.node.list_ports(ironic_node.uuid)[0].address
 for node in data["nodes"]:
  #print ironic_node_mac, "-", node["mac"][0]
  #print ironic_node.driver_info["ipmi_address"], node["pm_addr"], instance.name
  #if (node["mac"][0] == ironic_node_mac and 'controller' in instance.name):
  if (node["pm_addr"] == ironic_node.driver_info["ipmi_address"] and 'controller' in instance.name):
   print('pcs stonith delete stonith-{} || /bin/true'.format(instance.name))
   print('pcs stonith create stonith-{} fence_ipmilan pcmk_host_list="{}" ipaddr="{}" action="reboot" login="{}" passwd="{}" lanplus="true" delay=20 op monitor interval=60s'.format(instance.name,instance.name,node["pm_addr"],node["pm_user"],node["pm_password"]))
   #print('pcs stonith create stonith-{} fence_ipmilan pcmk_host_list="{}" ipaddr="{}" action="reboot" login="{}" passwd="{}" lanplus="true" delay=20 op monitor interval=60s'.format(instance.name,instance.name,ironic_node.driver_info["ipmi_address"],ironic_node.driver_info["ipmi_username"],ironic_node.driver_info["ipmi_password"]))
print('pcs property set stonith-enabled=true')

jdata.close()
