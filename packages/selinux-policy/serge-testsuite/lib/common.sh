#
# Copyright (c) 2019 Red Hat, Inc. All rights reserved.
#
# This copyrighted material is made available to anyone wishing
# to use, modify, copy, or redistribute it subject to the terms
# and conditions of the GNU General Public License version 2.
#
# This program is distributed in the hope that it will be
# useful, but WITHOUT ANY WARRANTY; without even the implied
# warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
# PURPOSE. See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public
# License along with this program; if not, write to the Free
# Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
# Boston, MA 02110-1301, USA.
#

# this file contain functions that may be handy for SELinux RHTS tests
# if you are including this file into your tests, do it after including beakerlib functions.

# current functions:
#   rlSERunWithContext
#   rlSESearchRule
#   rlSEBooleanOn
#   rlSEBooleanOff
#   rlSEBooleanRestore
#   rlSERunWithPassword
#   rlSEIsMLS
#   rlSEIsTargeted
#   rlSEIsStrict


# execute command with a given context
# there has to be transition allowed from initrc_exec_t to a desired context available
#
# usage:  rlSERunWithContext [-u USER] [-r ROLE] [-t TYPE] cmd
#   e.g.  rlRun "rlSERunWithContext -t smbd_exec_t stat $TmpDir/testmount" 1
# OPTIONS are supposed to be passed to chcon command
function rlSERunWithContext() {

    local TMPDIR
    local OPTIONS
    local COMMAND
    local RETCODE

    #read and store options
    while [ "${1:0:1}" = "-" ]; do
        OPTIONS+=" $1 $2"
        shift 2
    done
    if [ -z "$1" ]; then
        rlLogError "No command passed to rlRunWithSELinuxContext"
        return 99
    else
        COMMAND=$@   # store command with arguments
    fi

    TMPDIR=`mktemp -d`
    chcon -t smbd_tmp_t $TMPDIR

    #prepare launcher scripts - one with initrc_exec_t and other with desired context
    echo -e "#!/bin/bash\n$TMPDIR/launcher2.sh\n" > $TMPDIR/launcher1.sh
    echo -e "#!/bin/bash\n$COMMAND" > $TMPDIR/launcher2.sh
    chcon -t initrc_exec_t $TMPDIR/launcher1.sh
    chcon $OPTIONS $TMPDIR/launcher2.sh
    chmod a+x $TMPDIR/*.sh
    #cat $TMPDIR/launcher1.sh
    #cat $TMPDIR/launcher2.sh

    $TMPDIR/launcher1.sh   # execute the first launcher script
    RETCODE=$?

    rm -rf $TMPDIR
    return $RETCODE

}


# search for given selinux rule
# usage:  rlSESearchRule "dontaudit smbd_t etc_conf_t:dir getattr"
# or      rlSESearchRule "allow ftpd_t public_content_rw_t: dir write [ allow_ftpd_anon_write ]"
# or      rlSESearchRule "allow ftpd_t public_content_rw_t: dir write [ allow_ftpd_anon_write ] [POLICY]"
# can handle expression with one set of {} brackets
function rlSESearchRule() {

    local RULES
    local RULETYPE
    local MULTIVAL
    local SEARCHSTRING
    local NEWSEARCHSTRING
    local BOOL
    local PBOOL
    local DESC
    local I
    local POLICY


    if echo "$1" | grep -q '{'; then        # are there any {} ?
        RULES=( `echo "$1" | sed -e 's/{[^\}]\+}/MULTIVAL/' -e 's/\:/ /g'` )   # replace {...}  with string MULTIVAL plus replace : with space
        MULTIVAL=`echo "$1" | grep -o '{[^\}]\+}' | head -n 1 | sed 's/[\{\}]//g'` # get the {..} content
    else
        RULES=( `echo "$1" | sed 's/\:/ /g'` )              # replace : with space
    fi

    RULETYPE=${RULES[0]}                                # process rule type...
    [ "$RULETYPE" = "dontaudit" ] && rlIsRHEL 4 5 && RULETYPE="audit"   # dontaudit rules are in --audit rule type
    [ "$RULETYPE" = "type_transition" ] && RULETYPE="type"   # type_transition rules are in --type rule type

    # process [ BOOLEAN ] option
    # search for standalone [
    for I in `seq ${#RULES[*]}`; do
      if [ "${RULES[$I]}" = "[" ]; then   # I have found a [
        I=$(( $I + 1 ))
        BOOL="\[ ${RULES[$I]} \]"
        PBOOL="with [ ${RULES[$I]} ]"
      fi
    done

    # replace -t self with source context
    if [ "${RULES[2]}" = "self" ]; then
        RULES[2]="${RULES[1]}"
    fi

    # now search for the POLICY parameter - should be the last one
    I=$(( ${#RULES[*]} - 1 ))
    if [ "${RULES[$I]}" = "minimum" -o "${RULES[$I]}" = "strict" -o "${RULES[$I]}" = "mls" -o "${RULES[$I]}" = "targeted" ]; then
        POLICY=`ls -d /etc/selinux/${RULES[$I]}/policy/policy.*`
    fi

    SEARCHSTRING="sesearch --$RULETYPE -n -C -s ${RULES[1]} -t ${RULES[2]} -c ${RULES[3]} -p ${RULES[4]} $POLICY"

    DESC="$3"

    if [ -z "$MULTIVAL" ]; then  # processing simple rule
        [ -z "$3" ] && DESC="$SEARCHSTRING $PBOOL"
        rlRun "$SEARCHSTRING | egrep '; ($BOOL)?\$' | grep ${RULES[0]}" "$2" "$DESC"
    else  # processing multival rule
        rlLog "Checking rule '$1'"
        for VAL in $MULTIVAL; do
            NEWSEARCHSTRING=`echo "$SEARCHSTRING" | sed "s/MULTIVAL/$VAL/"`
            [ -z "$3" ] && DESC="$NEWSEARCHSTRING $PBOOL"
            rlRun "$NEWSEARCHSTRING | egrep '; ($BOOL)?\$' | grep ${RULES[0]}" "$2" "$DESC"
        done
    fi

}


# functions to switch SELinux booleans on/off. When executed for the first time, it remembers the
# initial status which is restored lateron by rlSEBooleanRestore

# switch the boolean(s) on
# Usage:  slSEBooleanOn boolean1 [bolean2 ...]
function rlSEBooleanOn() {

    local STATUSFILE="$BEAKERLIB_DIR/sebooleans" && touch $STATUSFILE
    rlLog "Setting SELinux boolean(s) $* on"
    while [ -n "$1" ]; do
        # if we didn't save the status yet, save it now
        grep -q "^$1 " $STATUSFILE ||  getsebool $1 >> $STATUSFILE
        # now switch the boolean on
        setsebool -P $1 on
        shift
    done

}


# switch the boolean(s) off
# Usage:  slSEBooleanOff boolean1 [bolean2 ...]
function rlSEBooleanOff() {

    local STATUSFILE="$BEAKERLIB_DIR/sebooleans" && touch $STATUSFILE

    rlLog "Setting SELinux booleans $* off"
    while [ -n "$1" ]; do
        # if we didn't save the status yet, save it now
        grep -q "^$1 " $STATUSFILE || getsebool $1 >> $STATUSFILE
        # now switch the boolean on
        setsebool -P $1 off
        shift
    done

}


# restore original state of SELinux boolean(s) - all used booleans if no specified
# Usage rlSEBooleanRestore [boolean1 ...]
function rlSEBooleanRestore() {

    local STATUSFILE="$BEAKERLIB_DIR/sebooleans"
    local RECORD

    if [ ! -f $STATUSFILE ]; then
        rlLogError "Cannot restore SELinux booleans, saved states are not available"
        return 99
    fi

    if [ -z "$1" ]; then     # no booleans specified, restoring all booleans
        rlLog "Restoring all used SELinux booleans"
        cat $STATUSFILE | while read RECORD; do
            # restore original boolean status saved in a STATUSFILE
            setsebool -P `echo $RECORD | cut -d ' ' -f 1` `echo $RECORD | cut -d ' ' -f 3`
        done
    else      # restoring only specified booleans
        rlLog "Restoring original status of SELinux booleans $*"
        while [ -n "$1" ]; do   # process all passed booleans
            RECORD=`grep "^$1 " $STATUSFILE`
            if [ -z "$RECORD" ]; then
                rlLogError "Cannot restore SELinux boolean $1, original state was not saved"
            else
                # restore original boolean status saved in a STATUSFILE
                setsebool -P `echo $RECORD | cut -d ' ' -f 1` `echo $RECORD | cut -d ' ' -f 3`
            fi
            shift
        done
    fi
}


# execute given command and whenever prompted for password, provides it
# password can be stored in $PASSWORD global variable or specified using -p parameter
# usage: rlSERunWithPassword [ -p PASSWORD ] COMMAND
function rlSERunWithPassword() {

  local PASS="$PASSWORD"
  # read password parameter
  if [ "$1" = "-p" ]; then
      PASS="$2"
      shift 2
  fi

  cat <<EOF | expect -
set timeout 5
spawn $*
expect {
  "*assword:*" { send "$PASS\r"; exp_continue }
}
EOF

}


# tests whether MLS policy is used
function rlSEIsMLS() {
    sestatus | grep -qi mls
}


# tests whether targeted policy is used
function rlSEIsTargeted() {
    sestatus | grep -qi targeted
}


# tests whether strict policy is used
function rlSEIsStrict() {
    sestatus | grep -qi strict
}


# select tool to manage package, which could be "yum" or "dnf"
function select_yum_tool() {
    if [ -x /usr/bin/dnf ]; then
        echo "/usr/bin/dnf"
    elif [ -x /usr/bin/yum ]; then
        echo "/usr/bin/yum"
    else
        return 1
    fi

    return 0
}


# install requires
SE_REQUIRES=setools-console
rlIsRHEL 4 5 && SE_REQUIRES=setools
if ! rpm -q $SE_REQUIRES; then
    yum=$(select_yum_tool)
    if [ $? -ne 0 ]; then
        echo "No tool to download kernel from a repo" >> ${OUTPUTFILE}
        report_result ${TEST} WARN 99
        rhts-abort -t recipe
        exit 0
    fi

    ${yum} install -y $SE_REQUIRES || \
        echo "Error: cannot install $SE_REQUIRES"
fi
