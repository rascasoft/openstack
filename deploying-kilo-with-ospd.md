# Deploying OpenStack Kilo with OSPd

## Step 1: provision a machine for the undercloud:

 # h2-r3-foreman-v37.scale.openstack.engineering.redhat.com
 FOREMANIP=10.1.16.17
 # macb8ca3a66f440.example.com
 UNDERCLOUDIP=10.1.241.13
 # working dir
 WORKINGDIR=$(dirname $0)
 SSH="ssh -o StrictHostKeyChecking=no"
 SCP="scp -o StrictHostKeyChecking=no"

echo -n "Identifying undercloud host: "
UNDERCLOUD=$($SSH root@$FOREMANIP hammer host list | grep $UNDERCLOUDIP | awk '{print $3}')
echo $(date)
check_exit

echo -n "Setting host to be rebuilt by Foreman: "
echo $(date)
$SSH root@$FOREMANIP hammer host update --name $UNDERCLOUD --build=1 &> /dev/null
check_exit

echo -n "Rebooting $UNDERCLOUD and wait to go down: "
echo $(date)
$SSH root@$UNDERCLOUDIP "reboot" &> /dev/null
while true
 do
  nc $UNDERCLOUDIP 22 < /dev/null &> /dev/null
  if [ $? -ne 0 ]
   then
    break
   else
    sleep 5
    echo -n "."
  fi
 done
echo "Done."

echo -n "Waiting for $UNDERCLOUD to come up again: "
echo $(date)
while true
 do
  nc $UNDERCLOUDIP 22 < /dev/null &> /dev/null
  if [ $? -eq 0 ]
   then
    break
   else
    sleep 5
    echo -n "."
  fi
 done
echo "Done."

cd $WORKINGDIR

## Step 2 - Uploading installation scripts and repos to $UNDERCLOUD (root)
$SCP -r undercloud-preparation.sh root@$UNDERCLOUDIP: &> /dev/null

## Step 3 - Starting undercloud preparation in $UNDERCLOUD
$SSH root@$UNDERCLOUDIP ./undercloud-preparation.sh

## Step 4 - Uploading installation scripts to $UNDERCLOUD (stack)
$SCP -r create-stonith-from-instackenv.py follow-events.py opensink instackenv.json undercloud-install.sh overcloud-*.sh network-environment.yaml nic-configs stack@$UNDERCLOUDIP: &> /dev/null

## Step 5 - Starting undercloud installation in $UNDERCLOUD (user stack)
$SSH stack@$UNDERCLOUDIP ./undercloud-install.sh

## Step 6 - Starting overcloud introspection (user stack)
$SSH stack@$UNDERCLOUDIP ./overcloud-introspection.sh

## Step 7 - Starting overcloud deploy (user stack)
$SSH stack@$UNDERCLOUDIP ./overcloud-deploy.sh

## Step 8 - Starting overcloud post operations"
$SSH root@$UNDERCLOUDIP /home/stack/overcloud-post.sh