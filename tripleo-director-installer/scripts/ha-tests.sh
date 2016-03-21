#!/bin/bash

# Raoul Scarazzini (rasca@redhat.com) - 2016/01/21:
# This script provides a test suite to be used in the transition between the actual 
# OSPd HA setup, named "Pacemaker", into the future one, named "Pacemaker Light"

function usage {
  echo "Usage $0 -t A|B|C|D [-r <seconds>]
-t, --test <A|B|C|D>		Specify which test to run
-r, --recover <seconds>		Try to recover environment after seconds

Test suites available:
A - Stop every sytemd resource, stop Galera and Rabbitmq, Start every systemd resource
B - Stop Galera and Rabbitmq, stop every systemd resource, Start every systemd resource
C - Stop Galera and Rabbitmq, wait 20 minutes to see if something fails
D - Stop the cluster and check if there are (still) active resources
"
}

function check_failed_actions {
 resource=$1

 pcs status | grep "Failed Actions:" &> /dev/null
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
   pcs status | sed -n -e '/Failed Actions:/,/^$/ p'
  else
   pcs status | sed -n -e '/Failed Actions:/,/^$/ p' | grep -A1 $resource
 fi

 echo "Failed Resources (if any):"
 pcs status | sed -n -e "/Failed Actions:/,/^$/p" | egrep "OCF_|not running|unknown" | awk '{print $2}'|cut -f1 -d_ | sort |uniq
}

function check_resources_process_status {
 if [ "$1" == "pre" ]
  then
   # If the run is for pre we take a snap of the actual resources status
   pcs resource show | egrep "^ (C|[a-Z])" | sed 's/.* \[\(.*\)\]/\1/g' | sed 's/ \(.*\)(.*):.*/\1/g' | sort > $resources_tmp_file
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
        ip a s | grep $ip_addr &> /dev/null
        ;;
   rabbitmq) /usr/sbin/rabbitmqctl cluster_status &> /dev/null
             ;;
   redis) pidof /usr/bin/redis-server &> /dev/null
          ;;
   galera) pidof /usr/libexec/mysqld &> /dev/null
           ;;
   *cleanup*|delay) echo  -n "no need to check if it's "
                  ;;
   *) systemctl is-active $resource &> /dev/null
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
   output=$(pcs status | sed -n -e "/Clone Set: .*\[$resource\]/,/^ [a-Z]/ p" | head -n -1 | tail -n +2 | egrep -v "$status\:")
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
   pcs resource $action $resource
   check_resource_status $resource $resource_status
   if [ $? -ne 0 ]
    then
     check_failed_actions $resource
    else
     echo "Ok"
   fi
  done
}

function recover_environment {
 if [ "x$recover" != "x" ]
  then
   echo "Waiting $recover seconds to recover environment"
   sleep $recover
   echo "Recovering..."
   case $test_sequence in
    "A")
     ;;
    "B")
     ;;
    "C")
     ;;
    "D")
     echo -n "Starting cluster "
     pcs cluster start --all
     recover_status="failure"
     i=1
     while true; do
      [ $i -eq $timeout ] && break

      sudo pcs status | grep Stopped &> /dev/null
      if [ $? -eq 0 ]
       then
        echo -n "."
       else
        echo "Started."
        recover_status="success"
        break
      fi
      sleep 2
     done
     ;;
   esac
 fi

 if [ "$recover_status" == "success" ]
  then
   echo "Recovery complete."
  else
   echo "Problems during recovery!"
 fi
}

resources_tmp_file="/tmp/resources.list"
timeout=60

while :; do
 case $1 in
  -h|-\?|--help)
      usage
      exit
      ;;
  -t|--test)
      test_sequence=$2
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
      ;;
  *)
      break
 esac

 shift
done

case "$test_sequence" in
"A") echo "$(date) * Step 0: getting systemd resource list"
     systemd_resources=$(pcs config show | egrep "Resource:.*systemd"|grep -v "haproxy"|awk '{print $2}')
     core_resources="galera rabbitmq-clone"

     echo "$(date) * Step 1: disable all the systemd resources"
     play_on_resources "disable" "$systemd_resources"

     echo "$(date) - List of cluster's failed actions:"
     show_failed_actions

     echo "$(date) * Step 2: disable galera and rabbitmq core services"
     play_on_resources "disable" "$core_resources"

     echo "$(date) - List of cluster's failed actions:"
     show_failed_actions

     echo "$(date) * Step 3: enable each resource one by one and check the status"
     play_on_resources "enable" "$systemd_resources"

     echo "$(date) - List of cluster's failed actions:"
     show_failed_actions
     ;;
"B") echo "$(date) * Step 0: getting systemd resource list"
     systemd_resources=$(pcs config show | egrep "Resource:.*systemd"|grep -v "haproxy"|awk '{print $2}')
     core_resources="galera rabbitmq-clone"

     echo "$(date) * Step 1: disable galera and rabbitmq core services"
     play_on_resources "disable" "$core_resources"

     echo "$(date) - List of cluster's failed actions:"
     show_failed_actions

     echo "$(date) * Step 2: disable all the systemd resources"
     play_on_resources "disable" "$systemd_resources"

     echo "$(date) - List of cluster's failed actions:"
     show_failed_actions

     echo "$(date) * Step 3: enable all the systemd resources"
     play_on_resources "enable" "$systemd_resources"

     echo "$(date) - List of cluster's failed actions:"
     show_failed_actions
     ;;
"C") echo "$(date) * Step 0: getting systemd resource list"
     systemd_resources=$(pcs config show | egrep "Resource:.*systemd"|grep -v "haproxy"|awk '{print $2}')
     core_resources="galera rabbitmq-clone"

     echo "$(date) * Step 1: disable galera and rabbitmq core services"
     play_on_resources "disable" "$core_resources"

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
"D") echo "$(date) * Step 0: checking actual process status"
     check_resources_process_status "pre"

     echo "$(date) * Step 1: stopping cluster"
     pcs cluster stop --all

     echo "$(date) * Step 0: checking actual process status"
     check_resources_process_status "post"
     ;;
*) usage
   exit 1
   ;;
esac

recover_environment "$test_sequence"

# To cleanup the things:
# pcs resource enable rabbitmq-clone
# pcs resource enable galera
# pcs status | sed -n -e '/Failed Actions:/,/^$/p' | egrep 'OCF_TIMEOUT|not running' | awk '{print $2}' | cut -f1 -d_ | sort | uniq | while read RES; do pcs resource cleanup $RES; done

echo "$(date) - End"
