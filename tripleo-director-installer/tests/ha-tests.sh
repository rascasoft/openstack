#!/bin/bash

# Raoul Scarazzini (rasca@redhat.com) - 2016/07/06:
# This script provides a test suite parser for the overcloud-ha-test-suite and must be ran from the undercloud

set -e

function usage {
  echo "Usage $0 -e <envfile>

-e, --environment <envfile>	Specify file containing the environment variables
-t, --test <test sequence>	Test sequence file
"
}

source /home/stack/stackrc

if [ $# -gt 0 ]
 then
  while :; do
   case $1 in
    -h|-\?|--help)
        usage
        exit
        ;;
    -e|--environment)
        source $2 &> /dev/null
        shift
        ;;
    -t|--test)
        if [ -f "$2" ]
         then
          test_sequence="$2"
         else
          echo "Test file list must be passed ($2 does not exist)"
          exit 1
        fi
        shift
        ;;
    --)
        shift
        break
        ;;
    -?*)
        usage
        exit 1
        ;;
    *)
        break
   esac

   shift
  done
 else
  usage
  exit 1
fi

# Populating overcloud elements
echo "#######################################################"
echo -n "$(date) - Setting up test environment vars..."
HATESTDIR=/tmp/overcloud-ha-test-suite
HATEST=overcloud-ha-test-suite.sh
OVERCLOUD_USER="heat-admin"
declare -A controllers
for LINE in $(nova list | awk '/overcloud-controller-/{gsub("ctlplane=",""); print $4"#"$12}')
do
 hostn=$(echo $LINE | cut -f1 -d#)
 hostip=$(echo $LINE | cut -f2 -d#)
 controllers[$hostn]="$hostip"
done
echo "OK"

echo "#######################################################"
# Getting overcloud-ha-test-suite
echo "$(date) - Getting overcloud-ha-test-suite..."
rm -rf $HATESTDIR
git clone https://github.com/rscarazz/openstack/ $HATESTDIR
pushd $HATESTDIR
git filter-branch --prune-empty --subdirectory-filter overcloud-ha-test-suite HEAD;
rm -rf .git
popd
echo "OK"

echo "#######################################################"
# Pushing overcloud-ha-test-suite to all the overcloud hosts
echo -n "$(date) - Pushing overcloud-ha-test-suite to all the overcloud hosts..."
for controllerip in ${controllers[*]}
do
 $SSH $OVERCLOUD_USER@$controllerip rm -rf $HATESTDIR
 $SCP -r $HATESTDIR $OVERCLOUD_USER@$controllerip:$HATESTDIR
done
echo "OK"

# Test execution
for LINE in $(cat $test_sequence | egrep -v "^#|^$")
do
 host=$(echo $LINE | cut -f 1 -d \|)
 testname=$(echo $LINE | cut -f 2 -d \|)
 reconame=$(echo $LINE | cut -f 3 -d \|)
 cmdline="$HATESTDIR/$HATEST --test $HATESTDIR/test/$testname"
 [ "x$reconame" != "x" ] && cmdline="$cmdline --recover $HATESTDIR/recovery/$reconame"
 echo "#######################################################"
 echo "Executing test $testname on $host"
 echo
 if [ "$host" == "undercloud" ]
  then
   $cmdline --undercloud
  else
   $SSH $OVERCLOUD_USER@${controllers[$host]} $cmdline
 fi
done

echo "#######################################################"
echo "$(date) - End"
