# OpenStack TripleO / Director installer
This project aims to automate all the stuff that needs to be done to deploy a complete environment via TripleO upstream or Red Hat OpenStack Director (OSPd)

## Environments
The way the project works is by environments. So you need to create a directory which defines the environment and pass it to the script like this:

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