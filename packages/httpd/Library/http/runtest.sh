#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/httpd/Library/http
#   Description: Basic library for httpd testing.
#   Author: Ondrej Ptak <optak@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2013 Red Hat, Inc. All rights reserved.
#
#   This copyrighted material is made available to anyone wishing
#   to use, modify, copy, or redistribute it subject to the terms
#   and conditions of the GNU General Public License version 2.
#
#   This program is distributed in the hope that it will be
#   useful, but WITHOUT ANY WARRANTY; without even the implied
#   warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
#   PURPOSE. See the GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public
#   License along with this program; if not, write to the Free
#   Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
#   Boston, MA 02110-1301, USA.
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# Include Beaker environment
. /usr/share/beakerlib/beakerlib.sh || exit 1

PACKAGES="httpd"
PHASE=${PHASE:-Test}

rlJournalStart
    rlPhaseStartSetup
        rlAssertRpm --all
        rlRun "rlImport httpd/http"
        rlRun "TmpDir=\$(mktemp -d)" 0 "Creating tmp directory"
        rlRun "pushd $TmpDir"
    rlPhaseEnd

    # Self test
    if [[ "$PHASE" =~ "Test" ]]; then
        rlPhaseStartTest "Test http"
            rlRun "httpStart" 0 "starting http server"
            rlRun "httpStatus" 0 "httpStatus"
            rlRun "httpStop" 0 "stoping http server"
        rlPhaseEnd

        if ( [ $httpCOLLECTION -eq 0 ] &&\
            (rpm -q --quiet mod_ssl || rpm -q --quiet mod_nss))\
            || ( [ $httpCOLLECTION -eq 1 ] &&
            (rpm -q --quiet httpd24-mod_ssl || rpm -q --quiet httpd24-mod_nss))
        then
            # run only if there is some mod for ssl
            rlPhaseStartTest "Test https"
                rlRun "httpSecureStart" 0 "starting https server"
                rlRun "httpInstallCa `hostname`" 0 "installing ca"
                rlRun "httpSecureStatus" 0 "httpStatus"
                rlRun "httpRemoveCa" 0 "removing ca"
                rlRun "httpSecureStop" 0 "stoping https server"
            rlPhaseEnd
        fi
        if ( [ $httpCOLLECTION -eq 0 ] &&\
            (rpm -q --quiet mod_ssl && rpm -q --quiet mod_nss))\
            || ( [ $httpCOLLECTION -eq 1 ] &&
            (rpm -q --quiet httpd24-mod_ssl && rpm -q --quiet httpd24-mod_nss))
        then
            # test explicitly mod_nss when both mod_{ssl,nss} are installed
            rlPhaseStartTest "Test https with mod_nss"
                rlRun "httpSecureStart mod_nss" 0\
                    "starting https server with mod_nss explicitly"
                rlRun "httpInstallCa `hostname`" 0 "installing ca"
                rlRun "httpSecureStatus" 0 "httpStatus"
                rlRun "httpRemoveCa" 0 "removing ca"
                rlRun "httpSecureStop" 0 "stoping https server"
            rlPhaseEnd
        fi

    fi

    rlPhaseStartCleanup
        rlRun "popd"
        rlRun "rm -r $TmpDir" 0 "Removing tmp directory"
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd
