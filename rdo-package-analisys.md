RDO Packages
============

From tar.gz to rpm
------------------

So we have [a commit](http://git.openstack.org/cgit/openstack/oslo.db/commit/?id=d94b7e3e3321f2dad7ab5861040b2d91f9036a5d) which produced a package, named [oslo.db-4.13.4.tar.gz](http://tarballs.openstack.org/oslo.db/oslo.db-4.13.4.tar.gz).

From the RDO side, after the package request, a review related to upper-constraints is automatically created [like this](https://review.rdoproject.org/r/#/c/3962/). This must be merged for the rpm to be created.
Inside this review a [specific file](https://review.rdoproject.org/r/#/c/3962/1/rdo.yml) is modified, for newton we will see:

    ...
    - project: oslo-db
      conf: rpmfactory-lib
      upstream: git://git.openstack.org/openstack/oslo.db
      tags:
        ocata-uc:
          source-branch: 4.15.0
        ocata:
        newton:
          source-branch: 4.13.4
        mitaka:
        liberty:
    ...

This means that the release the original patch was related has been included and next time package will be generated (typically one time per day) our version will be considered.
Now, after the above gets merged, looking inside the [newton report](https://trunk.rdoproject.org/centos7-newton/report.html) we should see, sooner or later, something like this:

2016-12-02 15:37:17 	2016-11-25 20:33:46 	python-oslo-db 	d94b7e3e3321f2dad7ab5861040b2d91f9036a5d SUCCESS  repo 	build log

Looking at the repo link, we can observe it:

https://trunk.rdoproject.org/centos7-newton/d9/4b/d94b7e3e3321f2dad7ab5861040b2d91f9036a5d_fa0ede5e/

The id refers to the last commit which was part of the global merge of the day, and in any case, following the link, the version of our package we find in this list is the right one:

python2-oslo-db-4.13.4-0.20161202153807.d94b7e3.el7.centos.noarch.rpm

All the info around this repo are contained in a specific [delorean.repo file](https://trunk.rdoproject.org/centos7-newton/d9/4b/d94b7e3e3321f2dad7ab5861040b2d91f9036a5d_fa0ede5e/delorean.repo=) which, in case of it passes the gates, is the equivalent of:

[https://trunk.rdoproject.org/centos7-newton/consistent/]

Then all the processes around CI starts, based upon the hash above, which is calculatedby [this job](https://ci.centos.org/job/rdo-promote-get-hash-newton) like in [this example](https://ci.centos.org/job/rdo-promote-get-hash-newton/277/console)

More useful info around the timings of package generation can be found at [this link](https://www.rdoproject.org/blog/2016/11/chasing-the-trunk-but-not-too-fast/)

Looking inside packages
-----------------------

When you want to see the status of a package and how this is created you need to refer to its spec file, which can be seen inside the associated [distgit](https://github.com/rdo-packages/oslo-db-distgit/blob/rpm-master/python-oslo-db.spec) repo.

It is possible to use the [rdopkg util](https://github.com/openstack-packages/rdopkg) look for example at the project oslo.db and see details around versions, maintainers and so on:

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
    
Here we see which version is loaded in each OpenStack release.
