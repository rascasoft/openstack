echo "###############################################"
echo "### Configuring repos #########################"
echo $(date)

rm -f /etc/yum.repos.d/*

cat >> /etc/yum.repos.d/rhos-release-rhel-7.2.repo <<EOF
#
# RHEL 7.2
#
[beaker-HighAvailability]
name=beaker-HighAvailability
baseurl=http://download.eng.bos.redhat.com/released/RHEL-7/7.2-RC-1/Server/x86_64/os/addons/HighAvailability
enabled=1
gpgcheck=0

[beaker-ResilientStorage]
name=beaker-ResilientStorage
baseurl=http://download.eng.bos.redhat.com/released/RHEL-7/7.2-RC-1/Server/x86_64/os/addons/ResilientStorage
enabled=1
gpgcheck=0

[beaker-Server-debuginfo]
name=beaker-Server-debuginfo
baseurl=http://download.eng.bos.redhat.com/released/RHEL-7/7.2-RC-1/Server/x86_64/debug/tree
enabled=1
gpgcheck=0

[beaker-Server-optional-debuginfo]
name=beaker-Server-optional-debuginfo
baseurl=http://download.eng.bos.redhat.com/released/RHEL-7/7.2-RC-1/Server-optional/x86_64/debug/tree
enabled=1
gpgcheck=0

[beaker-Server-optional]
name=beaker-Server-optional
baseurl=http://download.eng.bos.redhat.com/released/RHEL-7/7.2-RC-1/Server-optional/x86_64/os
enabled=1
gpgcheck=0

[beaker-Server]
name=beaker-Server
baseurl=http://download.eng.bos.redhat.com/released/RHEL-7/7.2-RC-1/Server/x86_64/os
enabled=1
gpgcheck=0

[beaker-Server-RT-debuginfo]
name=beaker-Server-RT-debuginfo
baseurl=http://download.eng.bos.redhat.com/released/RHEL-7/7.2-RC-1/Server-RT/x86_64/debug/tree
enabled=1
gpgcheck=0

[beaker-Server-RT]
name=beaker-Server-RT
baseurl=http://download.eng.bos.redhat.com/released/RHEL-7/7.2-RC-1/Server-RT/x86_64/os
enabled=1
gpgcheck=0

[beaker-Server-SAP-debuginfo]
name=beaker-Server-SAP-debuginfo
baseurl=http://download.eng.bos.redhat.com/released/RHEL-7/7.2-RC-1/Server-SAP/x86_64/debug/tree
enabled=1
gpgcheck=0

[beaker-Server-SAPHANA-debuginfo]
name=beaker-Server-SAPHANA-debuginfo
baseurl=http://download.eng.bos.redhat.com/released/RHEL-7/7.2-RC-1/Server-SAPHANA/x86_64/debug/tree
enabled=1
gpgcheck=0

[beaker-Server-SAPHANA]
name=beaker-Server-SAPHANA
baseurl=http://download.eng.bos.redhat.com/released/RHEL-7/7.2-RC-1/Server-SAPHANA/x86_64/os
enabled=1
gpgcheck=0

[beaker-Server-SAP]
name=beaker-Server-SAP
baseurl=http://download.eng.bos.redhat.com/released/RHEL-7/7.2-RC-1/Server-SAP/x86_64/os
enabled=1
gpgcheck=0
EOF

#yum -y update
yum update -y
yum install -y http://rhos-release.virt.bos.redhat.com/repos/rhos-release/rhos-release-latest.noarch.rpm
rhos-release 7-director 
yum install -y yum-utils 
yum install -y python-rdomanager-oscplugin
