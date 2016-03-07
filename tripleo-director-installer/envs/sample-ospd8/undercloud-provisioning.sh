#!/bin/bash

# Working dir
WORKINGDIR=$(dirname $0)

echo -n "Setting host to be rebuilt: "
echo $(date)
# Here the commands to rebuild the host

echo -n "Waiting for $UNDERCLOUD to go down: "
echo $(date)
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
