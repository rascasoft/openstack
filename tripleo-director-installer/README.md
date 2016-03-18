# OpenStack TripleO / Director installer
This project automates all the stuff that needs to be done to deploy a complete environment via TripleO upstream or Red Hat OpenStack Director (OSPd), typically on baremetal.

## Why

*TripleO Director Installer* aims to approach the TripleO / Director install process by keeping things as simple as possible. It ends in executing all the steps needed one after another.

Each process that is part of the deployment is executed, verified and, if broken, stopped.

So it should be simpler to debug issues. It was first developed to make it simpler the CI on tripleO/OSPd, especially on baremetal, even if also deploying virtual environment is possible (look at the PROVISION_SCRIPT beneath).

## Environments
The way *TripleO Director Installer* works is by environments. So you need to create a directory which defines the environment and pass it to the script like this:

    ./tripleo-director-installer.sh envs/myenv-mitaka/

### What needs to be inside the environment
The environment needs at least these files correctly set up to work properly:

- environment
- instackenv.json
- network-environment.yaml (with directory nic-configs)
- undercloud.conf

Optionally it's possible to define additional files to be launched for provisioning and after introspection:

- $PROVISION_SCRIPT
- $INTROSPECTION_POST_SCRIPT

### Defining the environment file

A typical environment file will contain something similar to this:

    # Undercloud machine
    export UNDERCLOUD=mrg-06.mpc.lab.eng.bos.redhat.com
    export UNDERCLOUDIP=10.16.144.44
    # OpenStack version
    export OPENSTACK_VERSION=osp7
    # SSH related commands
    export SSH="ssh -o StrictHostKeyChecking=no"
    export SCP="scp -o StrictHostKeyChecking=no"
    # Overcloud details
    export CONTROLLERS=3
    export COMPUTES=2
    export STORAGE=0
    export FLOATING_SUBNET="10.16.144.0/21"
    export FLOATING_RANGE_START="10.16.144.76"
    export FLOATING_RANGE_END="10.16.144.83"
    export FLOATING_GW="10.16.151.254"
    # Optional provisioning script (not mandatory)
    #export PROVISION_SCRIPT=undercloud-provisioning.sh
    # Optional post introspection script (not mandatory)
    #export INTROSPECTION_POST_SCRIPT=overcloud-introspection-post.sh
    # Enable SSL (not mandatory)
    #SSL_ENABLE="True"

Most of the options explain themselves by their name. In any case this list describe in details all you need to know:

- **UNDERCLOUD**: fqdn of the undercloud machine
- **UNDERCLOUDIP**: ip address of the undercloud machine
- **OPENSTACK_VERSION**: which version should the script install, choose from **ops7**, **osp8**, **liberty ** and **mitaka**
- **SSH**: default command line to call ssh
- **SCP**: default command line to call scp
- **CONTROLLER**: number of controller nodes to be deployed
- **COMPUTES**: number of compute nodes to be deployed
- **STORAGE**: number of storage nodes to be deployed
- **FLOATING_SUBNET**, **FLOATING_RANGE_START**, **FLOATING_RANGE_END**, **FLOATING_GW**: floating newtok details
- **PROVISION_SCRIPT**: name of the script that will be *eventually* launched before accessing the undercloud for the first time. This script must be present in the environment directory.
- **INTROSPECTION_POST_SCRIPT**: name of the script that will be *eventually* launched after the introspection process. This script must be present in the environment directory.
- **SSL_ENABLE**: enable SSL. If you want to enable SSL you will need additional files (see SSL section)
