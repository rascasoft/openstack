#!/bin/bash

# Raoul Scarazzini (rasca@redhat.com) - 2016/03/23:
# This script provides a test suite to be used in the transition between the actual 
# OSPd HA setup, named "Pacemaker", into the future one, named "Pacemaker Light"

function usage {
  echo "Usage $0 -e <envfile> -t A|B|C|D [-r <seconds>]
-e, --environment <envfile>	Specify file containing the environment variables
-t, --test <A|B|C|D>		Specify which test to run
-r, --recover <seconds>		Try to recover environment after seconds

Test suites available:
A - Stop every systemd resource, stop Galera and Rabbitmq, Start every systemd resource
B - Stop Galera and Rabbitmq, stop every systemd resource, Start every systemd resource
C - Stop Galera and Rabbitmq, wait 20 minutes to see if something fails
D - Stop the cluster and check if there are (still) active resources
"
}

function check_failed_actions {
 resource=$1

 $SSH $OVERCLOUD_USER@$OVERCLOUD_CONTROLLER sudo pcs status | grep "Failed Actions:" &> /dev/null
 if [ $? -eq 0 ]
  then
   echo "Errors while disabling $resource!"
   show_failed_actions $resource
   return 1
  else
   echo "No failed actions."
   return 0
  fi
}

function show_failed_actions {
 resource=$1

 echo "Failed Actions (if any):"
 if [ "x$resource" == "x" ]
  then
   $SSH $OVERCLOUD_USER@$OVERCLOUD_CONTROLLER sudo pcs status | sed -n -e '/Failed Actions:/,/^$/ p'
  else
   $SSH $OVERCLOUD_USER@$OVERCLOUD_CONTROLLER sudo pcs status | sed -n -e '/Failed Actions:/,/^$/ p' | grep -A1 $resource
 fi

 echo "Failed Resources (if any):"
  $SSH $OVERCLOUD_USER@$OVERCLOUD_CONTROLLER sudo pcs status | sed -n -e "/Failed Actions:/,/^$/p" | egrep "OCF_|not running|unknown" | awk '{print $2}'|cut -f1 -d_ | sort |uniq
}

function check_resources_process_status {
 if [ "$1" == "pre" ]
  then
   # If the run is for pre we take a snap of the actual resources status
   $SSH $OVERCLOUD_USER@$OVERCLOUD_CONTROLLER sudo pcs resource show | egrep "^ (C|[a-Z])" | sed 's/.* \[\(.*\)\]/\1/g' | sed 's/ \(.*\)(.*):.*/\1/g' | sort > $resources_tmp_file
  else
   [ "$1" != "post" ] && echo "Must pass pre or post as parameter." && exit 1
 fi

 resources=$(cat $resources_tmp_file)

 for resource in $resources
  do
   echo -n "$resource -> "

   case $resource in
   ip-*) #ip_addr=$(pcs resource show $resource | grep Attributes | sed 's/.*ip=\(.*\) cidr.*/\1/g')
        ip_addr=$(echo $resource | sed 's/ip-//g')
        $SSH $OVERCLOUD_USER@$OVERCLOUD_CONTROLLER sudo ip a s | grep $ip_addr &> /dev/null
        ;;
   rabbitmq) $SSH $OVERCLOUD_USER@$OVERCLOUD_CONTROLLER sudo /usr/sbin/rabbitmqctl cluster_status &> /dev/null
             ;;
   redis) $SSH $OVERCLOUD_USER@$OVERCLOUD_CONTROLLER pidof /usr/bin/redis-server &> /dev/null
          ;;
   galera) $SSH $OVERCLOUD_USER@$OVERCLOUD_CONTROLLER pidof /usr/libexec/mysqld &> /dev/null
           ;;
   *cleanup*|delay) echo  -n "no need to check if it's "
                  ;;
   *) $SSH $OVERCLOUD_USER@$OVERCLOUD_CONTROLLER systemctl is-active $resource &> /dev/null
      ;;
   esac
 
   [ $? -eq 0 ] && echo "active" || echo "inactive"
 
  done
}

function check_resource_status {
 resource=$1
 status=$2
 i=1
 return_code=1

 while [ $i -lt $timeout ]
  do
   output=$($SSH $OVERCLOUD_USER@$OVERCLOUD_CONTROLLER sudo pcs status | sed -n -e "/Clone Set: .*\[$resource\]/,/^ [a-Z]/ p" | head -n -1 | tail -n +2 | egrep -v "$status\:")
   if [ "x$output" == "x" ]
    then
     return_code=0
     break
    else
     echo -n "."
     sleep 1
     i=$(expr $i + 1)
   fi
  done
 return $return_code
}

function play_on_resources {
 action=$1
 resources=$2

 case "$action" in
 "enable") resource_status="Started"
          ;;
 "disable") resource_status="Stopped"
         ;;
 *) echo "Wrong action specified."
    exit 1
    ;;
 esac

 for resource in $resources
  do
   echo -n "$(date) - Performing action $action on resource $resource "
   $SSH $OVERCLOUD_USER@$OVERCLOUD_CONTROLLER sudo pcs resource $action $resource
   check_resource_status $resource $resource_status
   if [ $? -ne 0 ]
    then
     check_failed_actions $resource
    else
     echo "Ok"
   fi
  done
}

function recover_wait_start {
 i=1
 while true; do
  [ $i -eq $timeout ] && break

  $SSH $OVERCLOUD_USER@$OVERCLOUD_CONTROLLER sudo pcs status | grep Stopped &> /dev/null
  if [ $? -eq 0 ]
   then
    echo -n "."
   else
    echo "Started."
    return 0
    break
  fi
  sleep 2
 done
 return 1
}

function recover_environment {
 if [ "x$recover" != "x" ]
  then
   echo "$(date) - Waiting $recover seconds to recover environment"
   sleep $recover
   echo "$(date) - Recovering..."
   case $test_sequence in
    "A"|"B"|"C")
     echo -n "$(date) - Cleaning up cluster... "
     echo "$(date) * Step 1: enable all the systemd resources"
     play_on_resources "enable" "$OVERCLOUD_CORE_RESOURCES"

     echo -n "$(date) - Cleaning up failed resources"
     $SSH $OVERCLOUD_USER@$OVERCLOUD_CONTROLLER "sudo pcs status | sed -n -e '/Failed Actions:/,/^$/p' | egrep 'OCF_TIMEOUT|not running' | awk '{print $2}' | cut -f1 -d_ | sort | uniq | while read RES; do sudo pcs resource cleanup \$RES; done"
     ;;
    "D")
     echo -n "Starting cluster "
     $SSH $OVERCLOUD_USER@$OVERCLOUD_CONTROLLER sudo pcs cluster start --all
     ;;
   esac
 fi

 recover_wait_start
 if [ $? -eq 0 ]
  then
   echo "Recovery complete."
  else
   echo "Problems during recovery!"
 fi
}

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
        if [ $? -ne 0 ]
         then
          echo "An environment file must be passed!"
          usage
          exit 1
        fi
        shift
        ;;
    -t|--test)
        test_sequence="$2"
        shift
        ;;
    -r|--recover)
        if [ "$2" -eq "$2" ] 2>/dev/null
         then
          recover=$2
         else
          echo "Error reading recover seconds!"
          usage
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

# Fixed parameters
resources_tmp_file="/tmp/resources.list"
timeout=60

# Populating overcloud elements
echo -n "$(date) - Populationg overcloud elements..."
OVERCLOUD_USER="heat-admin"
source /home/stack/stackrc
OVERCLOUD_COMPUTES=$(nova list | egrep "overcloud-.*compute" | awk '{print $12}' | cut -f2 -d=)
[ $? -ne 0 ] && exit 1
OVERCLOUD_CONTROLLERS=$(nova list | grep overcloud-controller | awk '{print $12}' | cut -f2 -d=)
[ $? -ne 0 ] && exit 1
OVERCLOUD_CONTROLLER=$(nova list | grep overcloud-controller | awk '{print $12}' | head -1 | cut -f2 -d=)
[ $? -ne 0 ] && exit 1
echo "OK"
echo -n "$(date) * Getting systemd resource list..."
OVERCLOUD_CORE_RESOURCES="galera rabbitmq-clone"
OVERCLOUD_SYSTEMD_RESOURCES=$($SSH $OVERCLOUD_USER@$OVERCLOUD_CONTROLLER sudo pcs config show | egrep "Resource:.*systemd"|grep -v "haproxy"|awk '{print $2}')
[ $? -ne 0 ] && exit 1
echo "OK"

case "$test_sequence" in
 "A")
     echo "$(date) * Step 1: disable all the systemd resources"
     play_on_resources "disable" "$OVERCLOUD_SYSTEMD_RESOURCES"
   
     echo "$(date) - List of cluster's failed actions:"
     show_failed_actions
   
     echo "$(date) * Step 2: disable core services"
     play_on_resources "disable" "$OVERCLOUD_CORE_RESOURCES"
   
     echo "$(date) - List of cluster's failed actions:"
     show_failed_actions
   
     echo "$(date) * Step 3: enable each resource one by one and check the status"
     play_on_resources "enable" "$OVERCLOUD_SYSTEMD_RESOURCES"
   
     echo "$(date) - List of cluster's failed actions:"
     show_failed_actions
   
     ;;
"B")
     echo "$(date) * Step 1: disable core services"
     play_on_resources "disable" "$OVERCLOUD_CORE_RESOURCES"
   
     echo "$(date) - List of cluster's failed actions:"
     show_failed_actions
   
     echo "$(date) * Step 2: disable all the systemd resources"
     play_on_resources "disable" "$OVERCLOUD_SYSTEMD_RESOURCES"
   
     echo "$(date) - List of cluster's failed actions:"
     show_failed_actions
   
     echo "$(date) * Step 3: enable all the systemd resources"
     play_on_resources "enable" "$OVERCLOUD_SYSTEMD_RESOURCES"
   
     echo "$(date) - List of cluster's failed actions:"
     show_failed_actions
   
     ;;
"C")
     echo "$(date) * Step 1: disable core services"
     play_on_resources "disable" "$OVERCLOUD_CORE_RESOURCES"
   
     echo "$(date) - List of cluster's failed actions:"
     show_failed_actions
   
     echo "$(date) * Step 2: poll every minute for twenty minutes the status of the resources"
     for i in $(seq 1 20)
      do
       check_failed_actions
       if [ $? -ne 0 ]
        then
         echo "Errors found, test is over."
         break
       fi
       sleep 60
      done
   
     echo "$(date) - List of cluster's failed actions:"
     show_failed_actions

     ;;
"D")
     echo "$(date) * Step 1: checking actual process status"
     check_resources_process_status "pre"
   
     echo "$(date) * Step 2: stopping cluster"
     $SSH $OVERCLOUD_USER@$OVERCLOUD_CONTROLLER sudo pcs cluster stop --all
   
     echo "$(date) * Step 3: checking actual process status"
     check_resources_process_status "post"

     ;;
*)
     echo "Unable to recognize test suite!"
     usage
     exit 1

     ;;
esac

recover_environment "$test_sequence"

echo "$(date) - End"
