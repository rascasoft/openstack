echo "###############################################"
echo "### Configuring repos #########################"
echo $(date)

#rm -f /etc/yum.repos.d/*
#
#cat >> /etc/yum.repos.d/rhos-release-rhel-7.2.repo <<EOF
##
## RHEL 7.2
##
#[rhelosp-rhel-7-common]
#name=RHEL 7 Common
#baseurl=http://download.eng.bos.redhat.com/rel-eng/repos/rh-common-rhel-7.1/\$basearch/
#enabled=1
#gpgcheck=0
# 
#[rhelosp-rhel-7-server]
#name=Red Hat Enterprise Linux \$releasever - \$basearch - Server
#baseurl=http://download.devel.redhat.com/composes/finished/RHEL-7.2-RC-1.1/compose/Server/\$basearch/os/
#enabled=1
#gpgcheck=0
# 
#[rhelosp-rhel-7-ha]
#name=Red Hat Enterprise Linux \$releasever - \$basearch - HA
#baseurl=http://download.devel.redhat.com/composes/finished/RHEL-7.2-RC-1.1/compose/Server/\$basearch/os/addons/HighAvailability
#enabled=1
#gpgcheck=0
# 
#[rhelosp-rhel-7-extras]
#name=Red Hat Enterprise Linux \$releasever - \$basearch - Extras
#baseurl=http://download.eng.bos.redhat.com/rel-eng/repos/extras-rhel-7.2-candidate/\$basearch
#enabled=1
#gpgcheck=0
# 
#[rhelosp-rhel-7-openvswitch]
#name=Red Hat Enterprise Linux \$releasever - \$basearch - OpenVSwitch Preview
#baseurl=http://ayanami.boston.devel.redhat.com/poodles/rhos-devel-ci/7.0/fleas/2015-10-01.1/
#enabled=1
#gpgcheck=0
#EOF

#yum -y update

yum localinstall -y http://rhos-release.virt.bos.redhat.com/repos/rhos-release/rhos-release-latest.noarch.rpm
rhos-release -P 8-director
#rhos-release 8-director -p 2016-02-02.1
#rhos-release 8 -p 2016-02-04.2 
yum install -y python-tripleoclient
