echo "###############################################"
echo "### Configuring repos #########################"
echo $(date)

yum update -y
#yum -y install epel-release
#curl -o /etc/yum.repos.d/delorean.repo http://trunk.rdoproject.org/centos7/current-tripleo/delorean.repo
#curl -o /etc/yum.repos.d/delorean-current.repo http://trunk.rdoproject.org/centos7/current/delorean.repo
#curl -o /etc/yum.repos.d/delorean-current.repo http://trunk.rdoproject.org/centos7/current-passed-ci/delorean.repo
#curl -o /etc/yum.repos.d/delorean-current.repo http://trunk.rdoproject.org/centos7/consistent/delorean.repo
#sudo sed -i 's/\[delorean\]/\[delorean-current\]/' /etc/yum.repos.d/delorean-current.repo
#sudo /bin/bash -c "cat <<EOF>>/etc/yum.repos.d/delorean-current.repo
#
#includepkgs=diskimage-builder,openstack-heat,instack,instack-undercloud,openstack-ironic,openstack-ironic-inspector,os-cloud-config,os-net-config,python-ironic-inspector-client,python-tripleoclient,tripleo-common,openstack-tripleo-heat-templates,openstack-tripleo-image-elements,openstack-tuskar-ui-extras,openstack-puppet-modules
#EOF"
#curl -o /etc/yum.repos.d/delorean-deps.repo http://trunk.rdoproject.org/centos7/delorean-deps.repo

git clone https://git.openstack.org/openstack-infra/tripleo-ci
export STABLE_RELEASE="mitaka"
./tripleo-ci/scripts/tripleo.sh --repo-setup

yum -y install yum-plugin-priorities
yum -y install python-tripleoclient
