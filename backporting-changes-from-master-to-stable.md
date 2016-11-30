How to backport a modification from master into stable branch
=============================================================

This document describes how one can backport a modification from a master branch into a stable release.

Fixing the problem
------------------

Everything starts with a [bug](https://bugs.launchpad.net/tripleo/+bug/1642944) for which a [patch review](https://review.openstack.org/#/c/400269/) is created.

Once this review gets the +1 and +2 from the reviewers and passes the gates it gets [merged](https://github.com/openstack/oslo.db/commit/34f9a3ac7a56883f8a2cd2a9a93bc42e5194bc1e).

Problem in our case is that by default it gets merged in the **master** branch, but we found the problem in stable and we need to have this fixed also there (say **newton**), so a backport is needed.

Backporting the patch
---------------------

To backport the patch we need to get the master commit id (in this case *34f9a3ac7a56883f8a2cd2a9a93bc42e5194bc1e*):

    rasca@anomalia-rh [~/oslo.db]> git log

jump into origin/stable/newton and from here create a branch for our fix:

    rasca@anomalia-rh [~/oslo.db]> git checkout origin/stable/newton 
    rasca@anomalia-rh [~/oslo.db]> git checkout -b backport-mariadb-fix

Here we can cherry-pick the master commit, by doing this:

    rasca@anomalia-rh [~/oslo.db]> git cherry-pick 34f9a3ac7a56883f8a2cd2a9a93bc42e5194bc1e

We can then amend the commit comment so that will reflect its backport nature:

    rasca@anomalia-rh [~/oslo.db]> git commit -a --amend

The message will be something like:

    Support MariaDB error 1927
    
    We're observing a MariaDB-specific error code
    "1927 connection was killed", which seems to indicate the condition
    where the client/server connectivity is still up but the mariadb
    server has been restarted.  This error needs to be supported
    as one of the "disconnect" situations so that the ping handler
    knows to force a reconnect.
    
    Change-Id: I484237c28a83783689bb8484152476de33f20e3a
    References: https://bugs.launchpad.net/tripleo/+bug/1642944
    (cherry picked from commit 34f9a3ac7a56883f8a2cd2a9a93bc42e5194bc1e)
 
So it will be almost the same as before, except for the **cherry-picked** part.

At this point we can submit a review to make this patch merged ALSO in newton/stable:

    rasca@anomalia-rh [~/oslo.db]> git review

And then the review process of [this specific review](https://review.openstack.org/#/c/402669/) can start.

After the review is merged we will have the [associated commit](https://github.com/openstack/oslo.db/commit/d94b7e3e3321f2dad7ab5861040b2d91f9036a5d) on the stable/newton branch.

Requesting the release
----------------------

So since we know the id of the commit (*d94b7e3e3321f2dad7ab5861040b2d91f9036a5d*) it's time to request a release. This can be done by cloning the [openstack/releases repo](https://github.com/openstack/releases), and by modifying the file related to the release and to the component, in this case *deliverables/newton/oslo.db.yaml*.

At the end of this file we will add something like:

    ...
    ...
    - version: 4.13.4
      projects:
      - repo: openstack/oslo.db
        hash: d94b7e3e3321f2dad7ab5861040b2d91f9036a5d
      highlights: |-
        * Support MariaDB error 1927
        * Backport fix exc_filters for mysql-python

version is calculated looking at the previous one (in this case *4.13.3*) and by the fact that it is not breaking retro compatibility (this would increase the major release number, in this case *4.14.0*).

In this specific case the last commit built was *13223e459babddd74792699b20b52843a0ff9576* related to the *4.13.3* version, so since 3 new commits were posted into the repo this commit will have the id of the last one and will mention the other modifications inside the highlights field.

More informations around the choice of the version can be found [here](https://github.com/openstack/releases/blob/master/README.rst).

Once all these modifications are made we can commit them so that the title of the commit reflects the release, with this format:

**Release oslo.db 4.13.4 (newton)**

After this the review is [ready](https://review.openstack.org/#/c/404289/) and can start its process to be merged, the man in charge of this package creation is the PTL (*Project Team Lead*), all the PTLs are listed [here](https://wiki.openstack.org/wiki/CrossProjectLiaisons#Release_management).

Looking inside existing packages
--------------------------------

So the project is oslo.db and to see which packages produces we can check the spec file in the associated distgit -> https://github.com/rdo-packages/oslo-db-distgit/blob/rpm-master/python-oslo-db.spec

We can use rdopkg to get info from the package:

    rasca@anomalia-rh [~]> rdopkg info python-oslo-db
    1 packages found:
    
    name: python-oslo-db
    project: oslo-db
    conf: rpmfactory-lib
    upstream: git://git.openstack.org/openstack/oslo.db
    patches: http://review.rdoproject.org/r/p/openstack/oslo-db.git
    distgit: https://github.com/rdo-packages/oslo-db-distgit.git
    master-distgit: https://github.com/rdo-packages/oslo-db-distgit.git
    review-origin: ssh://review.rdoproject.org:29418/openstack/oslo-db-distgit.git
    review-patches: ssh://review.rdoproject.org:29418/openstack/oslo-db.git
    tags:
      liberty: null
      mitaka: null
      newton:
        source-branch: 4.13.3
      ocata: null
      ocata-uc:
        source-branch: 4.14.0
    maintainers: 
    - apevec@redhat.com
    - hguemar@redhat.com
    - lbezdick@redhat.com
    

