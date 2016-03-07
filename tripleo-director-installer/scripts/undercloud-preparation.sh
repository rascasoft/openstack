#!/bin/bash

echo "###############################################"
echo "$(date) Configuring user"

setenforce 0

useradd stack
echo stack | passwd --stdin stack
echo "stack ALL=(root) NOPASSWD:ALL" | tee -a /etc/sudoers.d/stack
chmod 0440 /etc/sudoers.d/stack
mkdir /home/stack/.ssh
cp /root/.ssh/authorized_keys /home/stack/.ssh/
chown stack:stack /home/stack/.ssh -R
chmod 700 /home/stack/.ssh
chmod 600 /home/stack/.ssh/authorized_keys

echo "###############################################"
echo "$(date) Disabling sudoers Defaults requiretty #####"

sed -i "s/^Defaults.*requiretty/#Defaults requiretty/" /etc/sudoers

echo "###############################################"
echo "$(date) Configuring packages"

yum install -y ntp vim tmux openssl wget ntp ntpdate bind-utils net-tools tmux vim git lftp
yum erase -y chrony
rm -f /etc/chrony* 
sed -i s/^server.*// /etc/ntp.conf
echo "server clock.redhat.com iburst" >> /etc/ntp.conf
echo clock.redhat.com > /etc/ntp/step-tickers
echo "SYNC_HWCLOCK=yes" >> /etc/sysconfig/ntpdate 
systemctl enable ntpdate
systemctl enable ntpd 
systemctl disable firewalld

echo "###############################################"
echo "$(date) Configuring hostname"

hostnamectl set-hostname $1
hostnamectl set-hostname --transient $1
sed -i "/127.0.0.1/d" /etc/hosts
echo "127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4 $(echo $1 | cut -f1 -d.) $1" >> /etc/hosts
