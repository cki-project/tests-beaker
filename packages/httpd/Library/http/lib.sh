#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   lib.sh of /CoreOS/httpd/Library/http
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
#   library-prefix = http
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

true <<'=cut'
=pod

=head1 NAME

httpd/http - Basic library for httpd testing.

=head1 DESCRIPTION

This library provides basic functions for easy testing httpd.
Main goal of this library is to simplify starting
http(s) server in various environments.
In current version, this library doesn't change any configuration files.
When using ssl, library allow only one of {mod_ssl,mod_nss} to be active.
When not using ssl, both modules mod_ssl and mod_nss will be disabled
because of posible problems with certificates.
Deactivating of module is implement by renaming *.conf files
in httpStart or httpSecureStart function and
restore them in httpStop or httpSecureStop function.

When using mod_nss for ssl, there is implicit port 8443 in nss.conf,
so httpSecureStatus try both ports 443 and 8443 and fails only when neither
of them is working.

Library makes sure that no httpd server is running
before starting and after stopping web server.

Library was tested on RHEL{5,6,7} and fedora and on collections.

If you find a bug in library or you want some changes or improvements, please
contact author.

=cut

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#   Variables
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

true <<'=cut'
=pod

=head1 VARIABLES

Below is the list of global variables which affects library's functions.

=over

=item httpROOTDIR

Directory where web pages are stored.

=item httpCONFDIR

Directory where httpd's config files and modules are stored.

=item httpLOGDIR

Path to the directory where httpd logs are stored.

=item httpNSS_DBDIR

Directory where mod_nss batabases with certificates are stored.

=item httpHTTPD

Name of web server's executable file.
This is also name of main rpm package.

=item httpSSL_O

SSL oraganization name.
Default value is server's hostname.

=item httpSSL_CN

SSL common name.
Default value is server's hostname.

=item httpSSL_CRT

Path to server certificate (.crt).
Function httpSecureStart will copy a certificate into this location.

=item httpSSL_KEY

Path to private key to server certificate (.key).
Function httpSecureStart will copy a private key into this location.

=item httpSSL_PEM

Path to pem file with trusted certificates.
Default value is /etc/pki/tls/certs/ca-bundle.crt.
Certificate is available at http://SERVER_HOSTNAME/ca.crt
and function !httpInstallCa can download and install it into httpSSL_PEM. 


=item httpCOLLECTION

This variable indicate (0/1) whether httpd24 collection is enabled.

=item httpCOLLECTION_NAME

Name of apache collection.

=item httpROOTPREFIX

Prefix of web server root directory.
If running in httpd24 collection, it contain prefix of path to root directory,
for example "/opt/rt/httpd24/root".
If not in collection, this variable contain empty string

=back

=cut

httpROOTDIR=${httpROOTDIR:-/var/www/html}
httpROOTPREFIX=${httpROOTPREFIX:-""}
httpCONFDIR=${httpCONFDIR:-/etc/httpd}
httpNSS_DBDIR=${httpNSS_DBDIR:-/etc/httpd/alias}
httpHTTPD=${httpHTTPD:-httpd}
httpSSL_CRT=${httpSSL_CRT:-/etc/pki/tls/certs/localhost.crt}
httpSSL_KEY=${httpSSL_KEY:-/etc/pki/tls/private/localhost.key}
httpSSL_PEM=${httpSSL_PEM:-/etc/pki/tls/cert.pem}
httpSSL_O=${httpSSL_O:-`hostname`}
httpSSL_CN=${httpSSL_CN:-`hostname`}
httpLOGDIR=${httpLOGDIR:-/var/log/httpd}
httpCOLLECTION=0

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#   Functions
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

true <<'=cut'
=pod

=head1 FUNCTIONS

=head2 httpStart

Starts http server and create file $httpROOTDIR/http_tesitfile
containging 'ok' string.

This function disable mod_ssl and mod_nss if available.

=head2 httpStop

Stop http server and delete file $httpROOTDIR/http_testfile.

=head2 httpStatus

Check whether http server is running
by downloading http://SERVER_HOSTNAME/http_tesfile.

Returns 0 when http_testfile is successfully downloaded, 1 otherwise.

=head2 httpSecureStart

This function creates ssl ceertificates and then
starts https server and create file $httpROOTDIR/http_testfile
containging 'ok' string.

    httpSecureStart <mod_nss|nss>

=over

=item mod_nss

Use mod_nss instead of default mod_ssl.


=head2 httpSecureStop

Stop http server and delete file $httpROOTDIR/http_testfile.
Also restore ssl certificate to state before httpSecureStart
was executed.

=head2 httpSecureStatus

Check whether https server is running
by downloading https://SERVER_HOSTNAME/http_tesfile.
Function try to download from port 443 first and if that fails,
try also port 8443 (defauld in mod_nss).

=head2 httpSetMPM <worker|prefork|event>

Set Multi-Processing Module.<<BR>>
Some tests require specific MPM to be set. Since rhel-8, default MPM changed
from prefork to event based. Don't forget to switch MPM back in cleanup phase.

=head2 httpInstallCa

Install certificate downloaded from server_url/ca.crt into local file with trusted ca's.

    httpInstallCa server_url

=over

=item server_url

Adress of running https server.

=back

Returns 0 when http_testfile is successfully downloaded, 1 otherwise.

=head2 httpRemoveCa

Remove ca from local system by restoring httpSSL_PEM file

=head2 httpDisableMod

Disable loading one or more Apache modules.

=over 4

B<!httpDisableMod> I<mod_name> [I<mod_name ...>]

=back

Options:

=over

=item mod_name

Name of the module to be disabled without the {{{mod_}}} prefix. To disable e.g.
mod_ssl, mod_nss and mod_security, run the following:

    httpDisableMod ssl nss security

=back

Note that the server has to be restarted for the new configuration to take
effect.

=head2 httpRestoreMod

Re-enable one or more Apache modules.

=over 4

B<!httpRestoreMod> [I<mod_name ...>]

=over

=item mod_name

Name of the module to be re-enabled without the {{{mod_}}} prefix. If no module
is specified, all currently disabled modules are re-enabled.

=back

=cut

__httpKillAllApaches() {
    local httpd_proc='(^|/)httpd$'
    local httpd_worker='(^|/)httpd\.worker$'
    local httpd_any='(^|/)httpd(\.worker)?$'

    # make sure that no httpd or httpd24 is running
    rlServiceStop $httpHTTPD
    if ! pgrep "$httpd_any" > /dev/null; then
        return 0;
    fi
    if pgrep "$httpd_worker" > /dev/null; then
        rlLogWarning "httpd.worker still running"
        rlLogInfo "`pgrep $httpd_worker`"
        pkill "$httpd_worker"
        sleep 5
    fi
    if pgrep $httpd_proc > /dev/null; then
        rlLogWarning "httpd still running"
        rlLogInfo "`pgrep $httpd_proc`"
        pkill "$httpd_proc"
        sleep 5
    fi
    if pgrep "$httpd_worker" > /dev/null; then
        pkill -9 "$httpd_worker"
        sleep 5
    fi
    if pgrep "$httpd_proc" > /dev/null; then
        pkill -9 "$httpd_proc"
        sleep 5
    fi
    for i in {1..10}; do
        if pgrep "$httpd_any" > /dev/null; then
           sleep 5
       else
           rlLog "no httpd or httpd.worker is running now"
           break  # no httpd running, OK
        fi
    done
    if pgrep "$httpd_any" > /dev/null; then
        rlFail "apache killing failed"
        rlLogInfo "`pgrep httpd`"
        return 1
    fi
}

__httpDetectProblems() {
    rlLog "function __detectProblems() started"
    echo
    echo "####################################################################"
    echo "################# possible problem detection start #################"
    echo "####################################################################"
    echo
    date

    for p in 80 81 443 8080 8443; do
        echo "checking for processes which listen on port $p:"
        echo "==================================================="
        lsof -i :$p
    done
    echo -e "===============================================================\n"

    echo "listing all processes:"
    echo "==================================================="
    ps aux -Z |grep httpd
    ps aux -Z > httpd_log_processes
    rlFileSubmit httpd_log_processes
    echo -e "===============================================================\n"


    echo "list all httpd configuration files"
    echo "==================================================="
    ls -1 $httpCONFDIR/conf.d/*.conf
    ls -1Za $httpCONFDIR/conf*/*.conf > httpd_log_configs
    rlFileSubmit httpd_log_configs
    rlBundleLogs configs $httpCONFDIR/conf* /var/log/messages
    echo -e "===============================================================\n"

    # TODO: pid/lock file check

    echo "check for semaphores used by apache user"
    echo "==================================================="
    local semcnt=`ipcs -s | egrep "0x[0-9a-f]+ [0-9]+" | grep apache|wc -l`
    local semmax=`cat /proc/sys/kernel/sem|awk '{print $4}'`
    rlAssertGreater "apache uses less semaphores than maximum allowed" "$semmax" "$semcnt"
    echo -e "===============================================================\n"

    if [ "$PACKAGES" != "" ] || [ "$REQUIRES" != "" ];then
        echo "check for changes in rpms: $PACKAGES $REQUIRES"
        echo "==================================================="
        rpm -Va $PACKAGES $REQUIRES|sort|uniq
        echo -e "===============================================================\n"
    fi

    echo "reporting relevant logs"
    rlBundleLogs logs $httpLOGDIR/*_log /var/log/messages
    echo
    echo "####################################################################"
    echo "################# possible problem detection end #################"
    echo "####################################################################"
    echo
    date
    rlLog "function __detectProblems() finished"

}

httpStart() {
    __httpKillAllApaches

    rlRun "httpDisableMod ssl nss" 0 "Disabling mod_ssl and mod_nss"

    # start server
    ret=0
    rlRun "rlServiceStart $httpHTTPD" 0 "starting httpd service"|| ret=1
    # create testfile
    rlRun "echo 'ok' > $httpROOTDIR/http_testfile" 0 "Creating test file"
    if [ "$ret" = 1 ];then
        __httpDetectProblems
    fi
    return $ret
}

httpStop() {
    rlRun "httpRestoreMod ssl nss" 0 "Restoring mod_ssl and mod_nss"

    #remove testfile
    rlRun "rm -f $httpROOTDIR/http_testfile" 0 "Deleting test file"

    # stop server
    ret=0
    rlRun "rlServiceStop $httpHTTPD" 0 "stoping httpd service" || ret=1
    rlGetTestState || __httpDetectProblems
    __httpKillAllApaches
    return $ret
}

httpStatus() {
    # try to download a testfile from running server
    local tmpdir
    local ret=0
    rlRun "tmpdir=`mktemp -d`" 0 "create tmp dir" || return 1
    rlRun "pushd $tmpdir"
    rlRun "wget --timeout=10 -t 2 -q http://`hostname`/http_testfile" 0-255 "download test file" || ret=1
    grep ok http_testfile || ret=1
    rlRun "popd"
    rlRun "rm -rf $tmpdir" 0 "remove tmp dir"
    return $ret
}


httpsStart() {
    rlLogInfo "httpsStart function is deprecated. Use httpSecureStart instead."
    httpSecureStart $1
}

httpSecureStart() {
    # select one of mod_{ssl,nss} and disable conf files
    # if there are both of them, so only one mod will be active.

    __httpKillAllApaches
    local httpMOD="none"

    if [ "$httpCOLLECTION" = "0" ]; then
        # collection off
        if ( [ "$1" = "mod_nss" ] || [ "$1" = "nss" ] ) && rpm -q mod_nss;then
            httpMOD="mod_nss"
        elif rpm -q mod_ssl;then
            httpMOD="mod_ssl"
        elif rpm -q mod_nss;then
            httpMOD="mod_nss"
        fi
    else
        # collection on
        if ( [ "$1" = "mod_nss" ] || [ "$1" = "nss" ] ) && rpm -q httpd24-mod_nss;then
            httpMOD="mod_nss"
        elif rpm -q httpd24-mod_ssl;then
            httpMOD="mod_ssl"
        elif rpm -q httpd24-mod_nss;then
            httpMOD="mod_nss"
        fi
    fi

    if [ $httpMOD = "none" ];then
        # no mod for ssl found
        rlFail "There was no mod for ssl detected"
        return 1  # no need to continue without any mod for ssl
    fi
    rlLogInfo "httpd will use $httpMOD for ssl"

    # disabling conf files for other mod
    if [ $httpMOD = "mod_ssl" ];then
        rlRun "httpDisableMod nss" 0 "Disabling mod_nss"
    else
        rlRun "httpDisableMod ssl" 0 "Disabling mod_ssl"
    fi

    # check if module and it's conf files are in right places
    if [ $httpMOD = "mod_ssl" ];then
            if [ ! -e $httpCONFDIR/modules/mod_ssl.so ];then
                rlLogError "file modules/mod_ssl.so is not in supposed place";fi
            if [ ! -e $httpCONFDIR/conf.d/ssl.conf ];then
                rlLogError "file  conf.d/ssl.conf is not in supposed place";fi
            #if [ ! -e $httpCONFDIR/conf.modules.d/*ssl.conf ];then
            #    rlLogError "file  conf.modules.d/*.ssl.conf is not in supposed places";fi
    elif [ $httpMOD = "mod_nss" ];then
            if [ ! -e $httpCONFDIR/modules/libmodnss.so ];then
                rlLogError "files for modules/libmodnss.so is not in supposed place";fi
            if [ ! -e $httpCONFDIR/conf.d/nss.conf ];then
                rlLogError "file  conf.d/nss.conf is not in supposed place";fi
            #if [ ! -e $httpCONFDIR/conf.modules.d/*nss.conf ];then
            #    rlLogError "file  conf.modules.d/*nss.conf is not in supposed place";fi
    fi

    local tmpdir
    rlRun "tmpdir=\$(mktemp -d)"
    echo "pushd $tmpdir"
    rlRun "pushd $tmpdir"

    # prepare certificates
    rlRun "x509KeyGen ca" 0 "Creating CA key & certificate"
    rlRun "x509KeyGen server" 0 "Creating server key & certificate"
    rlRun "x509SelfSign ca --DN 'CN=test' --DN 'O=test'" \
        0 "Self-signing CA certificate"
    rlRun "x509CertSign --CA ca server --DN 'CN=$httpSSL_CN' --DN 'O=$httpSSL_O'" \
        0 "Signing server certificate"

    if [ $httpMOD = "mod_ssl" ];then
        # backup certificates
        rlFileBackup --missing-ok --namespace httpd $httpSSL_CRT
        rlFileBackup --missing-ok --namespace httpd $httpSSL_KEY

        # copy certificates
        rlRun "cp -f $(x509Cert server) $httpSSL_CRT"
        rlRun "cp -f $(x509Key server) $httpSSL_KEY"

    elif [ $httpMOD = "mod_nss" ];then
        # backup certificates
        if [ -f $httpNSS_DBDIR/cert8.db ];then
            rlFileBackup --namespace httpd $httpNSS_DBDIR/cert8.db
        fi
        if [ -f $httpNSS_DBDIR/key3.db ];then
            rlFileBackup --namespace httpd $httpNSS_DBDIR/key3.db
        fi
        if [ -f $httpNSS_DBDIR/secmod.db ];then
            rlFileBackup --namespace httpd $httpNSS_DBDIR/secmod.db
        fi
        if [ -f $httpNSS_DBDIR/install.log ];then
            rlFileBackup --namespace httpd $httpNSS_DBDIR/install.log
        fi
        # clean certificates db
        rlRun "rm -f $httpNSS_DBDIR/cert8.db"
        rlRun "rm -f $httpNSS_DBDIR/key3.db"
        rlRun "rm -f $httpNSS_DBDIR/secmod.db"
        rlRun "rm -f $httpNSS_DBDIR/install.log"

        # install certificates into db
        echo > passw
        rlRun "certutil -N -d $httpNSS_DBDIR -f passw" 0 "inicializing nss databases"
        rlRun "pk12util -i $(x509Key --pkcs12 --with-cert server) -d $httpNSS_DBDIR -w passw" \
            0 "importing certificate"
        rlRun "certutil -A -n \"myca\" -t \"CT,,\" -d $httpNSS_DBDIR -a -i $(x509Cert ca)" \
            0 "importing ca"

        # modify mod_nss configuration to use 'server' certificate
        rlFileBackup --namespace httpd $httpCONFDIR/conf.d/nss.conf
        rlRun "sed -i 's/^NSSNickname .*$/NSSNickname server/' $httpCONFDIR/conf.d/nss.conf" \
            0 "Configuring NSSNickname in nss.conf"

        # change permisions so apache can acces db
        rlRun "chown root:apache $httpNSS_DBDIR/*.db"
        rlRun "chmod 640 $httpNSS_DBDIR/*.db"
    fi
    # copy ca into httpd rootdir
    rlRun "cp -f $(x509Cert ca) $httpROOTDIR/ca.crt" 0 "copy ca.crt into #httpROOTDIR"

    # create a test file
    rlRun "echo 'ok' > $httpROOTDIR/http_testfile" 0 "Creating test file"

    #start server
    ret=0
    rlRun "popd"
    rlRun "rm -rf $tmpdir"
    rlRun "rlServiceStart $httpHTTPD" 0 "starting httpd service" || ret=1
    if [ "$ret" = 1 ];then
        __httpDetectProblems
    fi
    return $ret
}

httpsStop() {
    rlLogInfo "httpsStop function is deprecated. Use httpSecureStop instead."
    httpSecureStop
}

httpSecureStop() {
    rlRun "rlServiceStop $httpHTTPD" 0 "stoping httpd service"
    rlRun "httpRestoreMod ssl nss" 0 "Restoring mod_ssl and mod_nss"

    # remove created files
    rlRun "rm -f $httpROOTDIR/http_testfile"
    rlRun "rm -f $httpROOTDIR/ca.crt"

    # restore certificates
    rlRun "rlFileRestore --namespace httpd" 0,16 "restoring certificates files"

    rlGetTestState || __httpDetectProblems

    __httpKillAllApaches
}

httpsStatus() {
    rlLogInfo "httpsStatus function is deprecated. Use httpSecureStatus instead."
    httpSecureStatus
}

httpSecureStatus() {
    # try to download a testfile from running server
    local tmpdir
    local ret=0
    rlRun "tmpdir=`mktemp -d`" 0 "create tmp dir" || return 1
    rlRun "pushd $tmpdir"
    rlRun "wget --timeout=10 -t 2  https://`hostname`/http_testfile ||\
           wget --timeout=10 -t 2  https://`hostname`:8443/http_testfile"\
           0-255 "download test file" || ret=1
    grep ok http_testfile || ret=1
    rlRun "popd"
    rlRun "rm -rf $tmpdir" 0 "remove tmp dir"
    return $ret
}

httpInstallCa() {
    # download ca.crt from server and add it into local file with trusted ca's
    local tmpdir
    local ret=0
    rlRun "tmpdir=`mktemp -d`" 0 "create tmp dir" || return 1
    rlRun "pushd $tmpdir"
    if [ -z $1 ];then
        rlFail "httpInstallCa: no server url as argument"
        ret=1
    fi
    rlRun "wget --timeout=10 -t 2 $1/ca.crt" 0 "download certificate" || ret=1
    rlAssertExists ca.crt || ret=1
    rlRun "rlFileBackup --namespace http_ca $httpSSL_PEM" 0 "creating backup of $httpSSL_PEM"
    rlRun "rlFileBackup --clean --namespace http_ca /etc/pki/ca-trust/"
    rlRun "cat ca.crt >> $httpSSL_PEM" 0\
        "adding certificate to file with trusted ca's" || ret=1
    # installing ca as trusted
    rlRun "cp ca.crt /etc/pki/ca-trust/source/anchors/" || ret=1
    rlRun "update-ca-trust" || ret=1

    rlRun "popd"
    rlRun "rm -rf $tmpdir" 0 "remove tmp dir"
    return $ret
}

httpRemoveCa() {
    # remove installed ca by restoring $httpSSL_PEM file
    rlRun "rlFileRestore --namespace http_ca"
}

httpDisableMod() {
    if [[ $# = 0 ]]; then
        rlLogError "No module specified to be disabled"
        return 1
    fi

    ret=0

    # This iterates over all module names passed as httpDisableMod arguments
    for mod; do
        for conf in $httpCONFDIR/conf{,.modules}.d/*${mod}.conf; do
            if [[ -e $conf ]]; then
                rlRun "mv ${conf} ${conf}.disabled" 0 "Disabling ${conf}" || ret=1
            fi
        done
        pattern="^\(LoadModule.*mod_${mod}.so\)"
        httpCONF="${httpCONFDIR}/conf/httpd.conf"
        if grep -q "${pattern}" "${httpCONF}"; then
            rlRun "sed -i.disabled 's/${pattern}/#\1/g' ${httpCONF}" 0 \
                "Disabling mod_${mod} loading in httpd.conf" || ret=1
        fi
    done

    return $ret
}

httpRestoreMod() {
    ret=0

    for mod in ${@:-''}; do
        for conf_disabled in ${httpCONFDIR}/conf{,.modules}.d/*${mod}.conf.disabled; do
            if [[ -e $conf_disabled ]]; then
                # ${conf_disabled%.disabled} is expanded to the value of
                # $conf_disabled in which the '.disabled' extension has been
                # deleted
                conf="${conf_disabled%.disabled}"
                rlRun "mv -f ${conf_disabled} ${conf}" 0 "Restoring ${conf}" || ret=1
            fi
        done
    done

    return $ret
}

httpSetMPM() {
    if [[ $# = 0 ]]; then
        rlLogError "No Multi-Processing Module specified"
        return 1
    fi
    ret=0
    module=$1
    mpmconf=${httpCONFDIR}/conf.modules.d/00-mpm.conf

    # disable all modules
    sed -i 's/^LoadModule/#LoadModule/' $mpmconf || ret=1
    # enable chosen one
    sed -i "s/#LoadModule mpm_${module}/LoadModule mpm_${module}/" $mpmconf || ret=1

    [[ $ret -eq 0 ]] && rlLogInfo "MPM module has been set to $module."

    return $ret
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#   Execution
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

true <<'=cut'
=pod

=head1 EXECUTION

This library supports direct execution. When run as a task, phases
provided in the PHASE environment variable will be executed.
Supported phases are:

=over

=item Test

Run the self test suite.

=back

=cut

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#   Verification
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   This is a verification callback which will be called by
#   rlImport after sourcing the library to make sure everything is
#   all right.
#   In this case there is a test whether it is posible to start and stop httpd.

httpLibraryLoaded() {
    rlRun "rlImport openssl/certgen" 0 "httpd/http: importing openssl library"

    # setup path variables if running in collection
    if echo $COLLECTIONS|grep "httpd24";then
        # TODO: parametrize to detect any collection name
        httpCOLLECTION=1
        httpCOLLECTION_NAME=httpd24
        httpHTTPD=httpd24-httpd
        httpCONFDIR=/opt/rh/httpd24/root$httpCONFDIR
        httpLOGDIR=/var/log/httpd24
        #httpSSL_CRT=/opt/rh/httpd24/root$httpSSL_CRT
        #httpSSL_KEY=/opt/rh/httpd24/root$httpSSL_KEY
    fi
    rlRun "rpm -q $httpHTTPD" 0 "checking $httpHTTPD rpm"

    # setup path variables from configuration files
    rlRun "httpROOTDIR=\$(grep '^DocumentRoot' ${httpCONFDIR}/conf/httpd.conf|\
        awk '{print \$2}'|sed -e 's/\"//g')" 0 "setup httpROOTDIR"
    rlRun "httpROOTPREFIX=\$(echo $httpROOTDIR|sed -e 's/\/var.*//')" 0 "parsing prefix from httpROOTDIR"

    rlAssertExists $httpROOTDIR
    # TODO: read paths to ssl certificates vrom config files?

    if ! rlIsRHEL 4; then # /etc/pki/tls/ not present on RHEL-4
        # follow symlinks to certificates
        rlRun "httpSSL_CRT=\$(readlink -f $httpSSL_CRT)" 0 "following posible symlink of $httpSSL_CRT"
        rlRun "httpSSL_KEY=\$(readlink -f $httpSSL_KEY)" 0 "following posible symlink of $httpSSL_KEY"
        rlRun "httpSSL_PEM=\$(readlink -f $httpSSL_PEM)" 0 "following posible symlink of $httpSSL_PEM"
    fi

    # print variables
    #rlLogInfo "PACKAGES=$PACKAGES"
    #rlLogInfo "REQUIRES=$REQUIRES"
    rlLogInfo "COLLECTIONS=$COLLECTIONS"
    rlLogInfo "httpCOLLECTION=$httpCOLLECTION"
    rlLogInfo "httpCOLLECTION_NAME=$httpCOLLECTION_NAME"
    rlLogInfo "httpHTTPD=$httpHTTPD"
    rlLogInfo "httpROOTDIR=$httpROOTDIR"
    rlLogInfo "httpROOTPREFIX=$httpROOTPREFIX"
    rlLogInfo "httpCONFDIR=$httpCONFDIR"
    rlLogInfo "httpLOGDIR=$httpLOGDIR"
    rlLogInfo "httpSSL_CRT=$httpSSL_CRT"
    rlLogInfo "httpSSL_KEY=$httpSSL_KEY"
    rlLogInfo "httpSSL_PEM=$httpSSL_PEM"
    rlLogInfo "httpSSL_O=$httpSSL_O"
    rlLogInfo "httpSSL_CN=$httpSSL_CN"

    # check if mod_ssl and mod_nss are installed
    if rpm -q mod_ssl; then
        rlLogDebug "mod_ssl installed"
    else 
        rlLogDebug "mod_ssl not installed"
    fi
    if rpm -q mod_nss; then
        rlLogDebug "mod_nss installed"
    else 
        rlLogDebug "mod_nss not installed"
    fi
    rlAssertRpm $httpHTTPD || return 1
    return 0
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#   Authors
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

true <<'=cut'
=pod

=head1 AUTHORS

=over

=item *

Ondrej Ptak <optak@redhat.com>

=back

=cut
