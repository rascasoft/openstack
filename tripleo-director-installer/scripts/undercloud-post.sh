#!/bin/bash

echo "$(date) Enabling sudoers Defaults requiretty"
sed -i "s/^#Defaults requiretty/Defaults requiretty/g" /etc/sudoers
