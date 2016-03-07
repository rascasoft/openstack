#!/bin/bash

sudo mkdir /etc/pki/instack-certs
sudo cp ~/undercloud.pem /etc/pki/instack-certs/.
sudo semanage fcontext -a -t etc_t "/etc/pki/instack-certs(/.*)?"
sudo restorecon -R /etc/pki/instack-certs
