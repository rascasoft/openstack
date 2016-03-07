#!/bin/bash

echo "$(date) Enabling sudoers Defaults requiretty"
sed -i "s/^#Defaults requiretty/Defaults requiretty/g" /etc/sudoers

echo "$(date) Configuring ssh client"
cat >> ~/.ssh/config <<EOF
Host 192.0.2.*
StrictHostKeyChecking no
UserKnownHostsFile=/dev/null
User heat-admin
port 22 
EOF

chmod 600 /home/stack/.ssh/config
