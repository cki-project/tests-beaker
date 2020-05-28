#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/httpd/Sanity/mod_ssl-smoke
#   Description: try to reinstall mod_ssl and run httpd with mod_ssl
#   Author: Ondrej Ptak <optak@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2014 Red Hat, Inc.
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
. ../../../cki_lib/libcki.sh || exit 1
. /usr/share/beakerlib/beakerlib.sh || exit 1

PACKAGES=${PACKAGES:-"httpd"}
FIPS=${FIPS:-"false"}
PYTHON=${PYTHON:-python}
if [[ -x /usr/bin/python ]]; then
        PYTHON=/usr/bin/python
elif [[ -x /usr/bin/python2 ]]; then
        PYTHON=/usr/bin/python2
elif [[ -x /usr/bin/python3 ]]; then
        PYTHON=/usr/bin/python3
elif [[ -x /usr/libexec/platform-python ]]; then
        PYTHON=/usr/libexec/platform-python
fi


rlJournalStart
    rlPhaseStartSetup
        if [[ $FIPS == "true" ]]; then
	    if [ -e "/etc/system-fips" ] && grep -q 1 /proc/sys/crypto/fips_enabled; then
                rlPass "fips mode enabled"
	    else
                echo "fips mode disabled. Test requires fips mode! Skipping." | tee -a $OUTPUTFILE
                rstrnt-report-result $TEST SKIP $OUTPUTFILE
                exit
	    fi
        fi
        rlAssertRpm --all
        rlRun "TmpDir=\$(mktemp -d)" 0 "Creating tmp directory"
        rlRun "rlImport httpd/http"
        rlFileBackup --namespace mod_ssl_smoke $httpSSL_CRT
        rlFileBackup --namespace mod_ssl_smoke $httpSSL_KEY
        rlFileBackup --namespace mod_ssl_smoke $httpLOGDIR/error_log
        rlRun "rm -f $httpLOGDIR/error_log"
        rlRun "rm -f $httpSSL_CRT"
        rlRun "rm -f $httpSSL_KEY"
        rlRun "cp run_postinstall_script.py $TmpDir"
        rlRun "chmod +x $TmpDir/run_postinstall_script.py"
        rlRun "pushd $TmpDir"
    rlPhaseEnd

    rlPhaseStartTest
        MOD_SSL_RPM=mod_ssl
        if [ "$httpHTTPD" != httpd ];then
            MOD_SSL_RPM=`echo $httpHTTPD| sed -e "s|-httpd|-mod_ssl|"`
        fi

        # this test used reinstalling of rpm, but sometimes
        #   test failed because the package for reinstall was
        #   not available. So now test runs just postinstall script

        #rlRun "yum reinstall -y $MOD_SSL_RPM 2>&1 | tee reinstall_log"
        #rlAssertNotGrep "scriptlet failure" reinstall_log
        #rlAssertNotGrep "Nothing to do" reinstall_log

        rlRun "rpm -q $MOD_SSL_RPM" && \
        rlRun "rpm -q --scripts $MOD_SSL_RPM| $PYTHON run_postinstall_script.py"
        rlRun "rlServiceStart $httpHTTPD" && rlRun "rlServiceStop $httpHTTPD" ||\
            (
            cat $httpLOGDIR/error_log
            rlFileSubmit $httpLOGDIR/error_log
            )
    rlPhaseEnd

    rlPhaseStartCleanup
        rlFileRestore --namespace mod_ssl_smoke
        rlRun "popd"
        rlRun "rm -r $TmpDir" 0 "Removing tmp directory"
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd
