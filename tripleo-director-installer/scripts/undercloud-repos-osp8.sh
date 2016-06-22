echo "###############################################"
echo "### Configuring repos #########################"
echo $(date)

yum localinstall -y http://rhos-release.virt.bos.redhat.com/repos/rhos-release/rhos-release-latest.noarch.rpm
rhos-release -P 8-director
yum install -y python-tripleoclient
