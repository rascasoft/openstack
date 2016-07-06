#!/bin/bash

set -eux

source $1/environment &> /dev/null
WORKINGDIR=$(dirname $0)
: ${PROVISION_SCRIPT:=""}
: ${INTROSPECTION_PRE_SCRIPT:=""}
: ${INTROSPECTION_POST_SCRIPT:=""}
: ${SSL_ENABLE:=""}

if [ $? -eq 0 ]
 then
  export ENVIRONMENTDIR=$1
  if [ "$OPENSTACK_VERSION" != "osp8" -a "$OPENSTACK_VERSION" != "osp7" -a "$OPENSTACK_VERSION" != "osp9" -a "$OPENSTACK_VERSION" != "mitaka" ]
   then
    echo "OPENSTACK_VERSION must be 'osp7', 'osp8', 'osp9' or 'mitaka'."
    exit 1
  fi
 else
  echo "A file named 'environment' must exists under $1"
  exit 1
fi

cd $WORKINGDIR

# If provisioning is declared, then we provide the undercloud
if [ "x$PROVISION_SCRIPT" != "x" ]
 then
  echo "###############################################"
  echo "$(date) Provisioning $UNDERCLOUD (root)"
  $ENVIRONMENTDIR/$PROVISION_SCRIPT
fi

echo "###############################################"
echo "$(date) Uploading undercloud preparation scripts $UNDERCLOUD (root)"
$SCP -r scripts/undercloud-{preparation,repos-$OPENSTACK_VERSION}.sh root@$UNDERCLOUDIP:

echo "###############################################"
echo "$(date) Starting undercloud preparation in $UNDERCLOUD"
$SSH root@$UNDERCLOUDIP ./undercloud-preparation.sh $UNDERCLOUD

echo "###############################################"
echo "$(date) Configuring undercloud repositories in $UNDERCLOUD"
$SSH root@$UNDERCLOUDIP ./undercloud-repos-$OPENSTACK_VERSION\.sh

echo "###############################################"
echo "$(date) Uploading undercloud scripts $UNDERCLOUD (stack)"
$SCP -r tests scripts/undercloud-install.sh scripts/overcloud-{images-$OPENSTACK_VERSION,introspection,deploy,post}.sh scripts/{opensink,follow-events.py} $ENVIRONMENTDIR/{environment,undercloud.conf,instackenv.json,network-environment.yaml,nic-configs} stack@$UNDERCLOUDIP:

# If SSL is enabled copy files
if [ "x$SSL_ENABLE" != "x" ]
 then
  echo "###############################################"
  echo "$(date) Uploading SSL configuration $UNDERCLOUD (stack)"
  $SCP scripts/undercloud-ssl.sh $ENVIRONMENTDIR/undercloud.pem stack@$UNDERCLOUDIP:
  $SSH stack@$UNDERCLOUDIP ./undercloud-ssl.sh
fi

echo "###############################################"
echo "$(date) Starting undercloud installation in $UNDERCLOUD (user stack)"
$SSH stack@$UNDERCLOUDIP ./undercloud-install.sh

echo "###############################################"
echo "$(date) Starting overcloud image generation (user stack)"
$SSH stack@$UNDERCLOUDIP ./overcloud-images-$OPENSTACK_VERSION\.sh

# If introspectin pre script is declared, we execute it now
if [ "x$INTROSPECTION_PRE_SCRIPT" != "x" ]
 then
  echo "###############################################"
  echo "$(date) Executing $INTROSPECTION_PRE_SCRIPT (stack)"
  $SCP $ENVIRONMENTDIR/$INTROSPECTION_PRE_SCRIPT stack@$UNDERCLOUDIP:
  $SSH stack@$UNDERCLOUDIP ./$INTROSPECTION_PRE_SCRIPT
fi

echo "###############################################"
echo "$(date) Starting overcloud introspection (user stack)"
$SSH stack@$UNDERCLOUDIP ./overcloud-introspection.sh

# If introspectin post script is declared, we execute it now
if [ "x$INTROSPECTION_POST_SCRIPT" != "x" ]
 then
  echo "###############################################"
  echo "$(date) Executing $INTROSPECTION_POST_SCRIPT (stack)"
  $SCP $ENVIRONMENTDIR/$INTROSPECTION_POST_SCRIPT stack@$UNDERCLOUDIP:
  $SSH stack@$UNDERCLOUDIP ./$INTROSPECTION_POST_SCRIPT
fi

# If SSL is enabled copy files for the overcloud and perform configuration
if [ "x$SSL_ENABLE" != "x" ]
 then
  echo "###############################################"
  echo "$(date) Uploading SSL configuration $UNDERCLOUD (stack)"
  $SCP scripts/overcloud-ssl.sh $ENVIRONMENTDIR/{cloudname,enable-tls,inject-trust-anchor}.yaml $ENVIRONMENTDIR/overcloud-cacert.pem stack@$UNDERCLOUDIP:
  $SSH stack@$UNDERCLOUDIP ./overcloud-ssl.sh
fi

echo "###############################################"
echo "$(date) Starting overcloud deploy (user stack)"
$SSH stack@$UNDERCLOUDIP ./overcloud-deploy.sh

echo "###############################################"
echo "$(date) Starting overcloud post operations"
$SSH stack@$UNDERCLOUDIP ./overcloud-post.sh
