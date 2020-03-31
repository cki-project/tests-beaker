#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /CoreOS/httpd/Sanity/httpd-php-mysql-sanity-test
#   Description: test fetching data from mysqldb/mariadb through php
#   Author: Karel Srot <ksrot@redhat.com>
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
. ../../../cki_lib/libcki.sh || exit 1
. /usr/share/beakerlib/beakerlib.sh || exit 1

PACKAGES="${PACKAGES:-httpd}"
REQUIRES="${REQUIRES:-php $DB}"

rlJournalStart
    rlPhaseStartSetup
        rlRun "rlImport httpd/http" 0 "Import httpd library"
        if rlIsRHEL 5 6 && [ $httpCOLLECTION = 0 ]; then
            DEF_RUN_ON_DB='mysql'
            # not nice but simplest solution [BZ#1577237]
            rlRun "yum install -y mysql-server"
        else
            DEF_RUN_ON_DB='mariadb'
        fi
        RUN_ON_DB=${RUN_ON_DB:-$DEF_RUN_ON_DB}
        if echo "$RUN_ON_DB" | grep -q mysql ; then
            DB="mysql-server"
            rlRun "rlImport mysql/basic" 0 "Import mysqld library"
            SERVICE=${mysqlServiceName}
        else
            DB="mariadb-server"
            rlRun "rlImport mariadb55/basic" 0 "Import mariadb library"
            SERVICE=${mariadbServiceName}
        fi
	# install also php-mysql on rhel-6 (instead of php-mysqlnd on rhel-7)
        rlRun "rlImport php/utils"
        phpPdoPhpMysqlSetup
        rlAssertRpm --all
        rlRun "rlServiceStart $SERVICE" 0
        rlRun "echo DROP DATABASE php_mysql_test | mysql -u root" 0,1
        rlRun "mysql --verbose -u root < php_mysql_test.sql"
        rlRun "httpStop" 0 "Stop httpd if running"
        rlRun "> $httpLOGDIR/error_log"
        rlRun "rm -rvf $httpROOTDIR/php_mysql_test"
        rlRun "mkdir -v $httpROOTDIR/php_mysql_test"
        rlRun "cp -v php_mysql_test.conf $httpCONFDIR/conf.d/"
        rlRun "cp -v mysql.php $httpROOTDIR/php_mysql_test"
        rlRun "sed -i 's|/var/www|$httpROOTDIR|' $httpCONFDIR/conf.d/php_mysql_test.conf"
        rlRun "chown -R apache:  $httpROOTDIR/php_mysql_test"
        #rlRun "restorecon  $httpROOTDIR/php_mysql_test"
        selinuxenabled && rlRun "chcon -Rv -t httpd_sys_content_t $httpROOTDIR/php_mysql_test"
        rlRun "httpStart" 0 "Start httpd"
    rlPhaseEnd

    rlPhaseStartTest
        URL="http://localhost/php_mysql_test/"
        RETVAL=0
        tries=`seq 1 10`

        for n in ${tries}; do
            output=`curl -s $URL/mysql.php`
            rv=$?
            echo "PHP output ${n}: ${rv} x${output}y"
            [ ${rv} -ne 0 -o "x${output}y" != "xfish is 42y" ] && RETVAL=66
        done

        if [ $RETVAL -ne 0 ]; then
            rlFail
        else
            rlPass
        fi
    rlPhaseEnd

    rlPhaseStartCleanup
        rlRun "rm -f $httpCONFDIR/conf.d/php_mysql_test.conf"
        rlRun "rm -rf $httpROOTDIR/php_mysql_test"
        rlRun "echo DROP DATABASE php_mysql_test | mysql -u root"
        rlRun "rlServiceRestore ${SERVICE}" 0
        rlRun "httpStop" 0 "Stop httpd if running"
	# uninstall php-mysql on rhel-6 if it was installed during setup
        phpPdoPhpMysqlCleanup
        rlRun "rm -fr /var/lib/mysql/" 0 "Removing mysql logs"
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd
