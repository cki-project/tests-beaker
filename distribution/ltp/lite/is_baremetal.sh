#!/bin/bash -x

# system with shared resources
# any s390x system
(uname -m | grep s390) && exit 1

# any guest system, e.g. ppc64 guests
(hostname | grep guest) && exit 1

# any ppc lpar
(uname -m | grep ppc) && (hostname | grep "\-lp") && exit 1

if command -v virt-what; then
	hv=$(virt-what)
	[ "$hv" != "" ] && exit 1
fi

exit 0
