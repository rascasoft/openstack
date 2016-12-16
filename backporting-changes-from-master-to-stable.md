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

How to backport patch is [addressed here](http://docs.openstack.org/project-team-guide/stable-branches.html#proposing-fixes). In our case we need to get the master commit id (in this case *34f9a3ac7a56883f8a2cd2a9a93bc42e5194bc1e*):

    rasca@anomalia-rh [~/oslo.db]> git log

jump into origin/stable/newton, creating a branch for our fix:

    rasca@anomalia-rh [~/oslo.db]> git checkout -b backport-mariadb-fix origin/stable/newton 

Here we can cherry-pick the master commit, by doing this:

    rasca@anomalia-rh [~/oslo.db]> git cherry-pick -x 34f9a3ac7a56883f8a2cd2a9a93bc42e5194bc1e

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
 
So it will be almost the same as before, except for the **cherry-picked** part, but the Change-id will maintain the same id.

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

After this the review is [ready](https://review.openstack.org/#/c/404289/) it walks through the review process, which depends mostly on the man in charge of this package creation, the PTL (*Project Team Lead*, all the PTLs are listed [here](https://wiki.openstack.org/wiki/CrossProjectLiaisons#Release_management)).

Once the review receives two **+2** and passes checks and gates from Jenkins it gets merged and the package can be generated. Depending on the package we're working on there are different ways to check this process.

First of all, a bot creates a [new review](https://review.openstack.org/#/c/405284/) inside the [openstack/requirements](https://github.com/openstack/requirements) project that basically adds the new version inside the *upper-constraints.txt* file. The format of this review will be something like this:

    update constraint for oslo.db to new release 4.13.4 
    
    oslo.db 4.13.4 release
    
    Change-Id: I8683ef4349b46c06acce08995c99996d0a0c93df
    meta:version: 4.13.4
    meta:diff-start: -
    meta:series: newton 
    meta:release-type: release
    meta:pypi: yes
    meta:first: no
    meta:release:Author: Raoul Scarazzini <rscarazz@redhat.com>
    meta:release:Commit: Raoul Scarazzini <rscarazz@redhat.com>
    meta:release:Change-Id: I8137bb92b23ff5d2707a96b2a3222433e2554c04
    meta:release:Code-Review+1: Victor Stinner <vstinner@redhat.com>
    meta:release:Code-Review+2: Doug Hellmann <doug@doughellmann.com>
    meta:release:Code-Review+1: Roman Podoliaka <rpodolyaka@mirantis.com>
    meta:release:Code-Review+1: Joshua Harlow <jxharlow@godaddy.com>
    meta:release:Code-Review+1: Alan Pevec <alan.pevec@redhat.com>
    meta:release:Code-Review+2: Thierry Carrez <thierry@openstack.org>
    meta:release:Workflow+1: Thierry Carrez <thierry@openstack.org>

This review needs to receive **+2** from core reviewers and also to pass all the gates. It could happen to see gates failing quickly, because of messages like this:

    2016-12-01 11:32:23.950267 | No matching distribution found for oslo.db===4.13.4 (from -r /home/jenkins/workspace/gate-requirements-tox-py27-check-uc-ubuntu-xenial/upper-constraints.txt (line 215))

In this specific case this means that our package is *not yet* available on the mirror used by the gates. To make some verifications:

1. We can check first inside http://tarballs.openstack.org/oslo.db/?C=M;O=D to check if the tar.gz was created (and in this case it is).

2. Then we can check the main pypi (*Python Package Index*) repo, looking for a url like https://pypi.python.org/pypi/oslo.db/4.13.4 (and also in this case package is here).

3. Finally we can check directly on the mirror, looking first at which mirror is used inside the logs:

    2016-12-01 11:32:23.950068 |   Downloading http://mirror.regionone.osic-cloud1.openstack.org/pypi/packages/ff/ef/711041714d381502e85ffd97acbe6c52e5611961eb4571e4d9885f8c225b/oslo.context-2.9.0-py2.py3-none-any.whl

   so the mirror of the url is http://mirror.regionone.osic-cloud1.openstack.org/pypi/packages. To identify the second part for oslo.db, the one with the hash, we can check the download link at https://pypi.python.org/pypi/oslo.db/4.13.4, discovering that the link is:

   https://pypi.python.org/packages/ed/a8/1edd8a21372c205b9a76dfbfa6cd87207ff4b6528a50b98410ffc27b3a05/oslo.db-4.13.4.tar.gz

   So the mirror url will be:

   http://mirror.regionone.osic-cloud1.openstack.org/pypi/packages/ed/a8/1edd8a21372c205b9a76dfbfa6cd87207ff4b6528a50b98410ffc27b3a05/oslo.db-4.13.4.tar.gz

   If the package is available here, then it is safe to put a recheck inside the review, and this time it should succeed.

So basically the problem was just a matter of time. Once this last modification gets merged, we can consider the process complete.
