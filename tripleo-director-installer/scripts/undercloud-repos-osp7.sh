echo "###############################################"
echo "### Configuring repos #########################"
echo $(date)

yum update -y
yum install -y http://rhos-release.virt.bos.redhat.com/repos/rhos-release/rhos-release-latest.noarch.rpm
rhos-release 7-director 
yum install -y yum-utils 
yum install -y python-rdomanager-oscplugin
