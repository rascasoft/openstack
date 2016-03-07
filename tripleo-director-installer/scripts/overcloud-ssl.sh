#!/bin/bash

sudo cp overcloud-cacert.pem /etc/pki/ca-trust/source/anchors/
sudo update-ca-trust extract
