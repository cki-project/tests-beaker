#!/bin/bash
#
# Copyright (c) 2013 Red Hat, Inc. All rights reserved.
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

FILE=$(readlink -f $BASH_SOURCE)
NAME=$(basename $FILE)
CDIR=$(dirname $FILE)
RPATH=${RELATIVE_PATH:-"networking/macsec/sanity_check"}

# Include Beaker environment
source ${CDIR%/$RPATH}/networking/common/include.sh || exit 1

KEY_0=81818181818181818181818181816161
KEY_1=81818181818181818181818181816262
NODE=1
PEER=2
SCI_NODE=0100567${NODE}12005452
SCI_PEER=0100567${PEER}12005452

rlJournalStart
    rlPhaseStartSetup
        rlRun -l "modinfo macsec"
        rlRun "modprobe macsec"
        rlRun -l "ip macsec help" 255
        if (( $? == 0 )); then
                rlLog "Aborting test because 'ip macsec' not found"
                rstrnt-abort --server $RSTRNT_RECIPE_URL/tasks/$TASKID/status
                exit 0
        fi
    rlPhaseEnd

    rlPhaseStartTest "load/unload macsec module"
        # Bug 1354332 - MACsec: kernel panic when removing macsec module
        if [ $(GetDistroRelease) -ge 8 ]; then
                modprobe dummy numdummies=1
        else
                modprobe dummy
        fi
        for i in `seq 50`; do
            ip link add link dummy0 type macsec sci 0100560212005452 encrypt on
            ip macsec add macsec0 tx sa 0 pn 1024 on key 01 81818181818181818181818181818181
            ip macsec add macsec0 rx port 1234 address c6:19:52:8f:e6:a0
            ip macsec add macsec0 rx port 1234 address c6:19:52:8f:e6:a0 sa 0 pn 1 on key 00 82828282828282828282828282828282
            modprobe -r macsec
        done
        modprobe -r dummy
    rlPhaseEnd

    rlPhaseStartTest "ip link add macsec"
        modprobe macsec
        if [ $(GetDistroRelease) -ge 8 ]; then
                modprobe dummy numdummies=1
        else
                modprobe dummy
        fi

        ip link set dummy0 up
        netperf_install
        # macsec name
        rlRun "ip link add link dummy0 type macsec"
        rlRun "ip link del macsec0"
        rlRun "ip link add link dummy0 macsec0 type macsec"
        rlRun "ip link del macsec0"
        rlRun "ip link add link dummy0 name macsec0 type macsec"
        rlRun "ip link del macsec0"
        rlRun "ip link add link dummy0 name macsec1 type macsec"
        rlRun "ip link del macsec1"
        rlRun "ip link add link dummy0 name macsec9999 type macsec"
        rlRun "ip link del macsec9999"
        rlRun "ip link add link dummy0 name ttt type macsec"
        rlRun "ip link set ttt up"
        rlRun -l "ip link show ttt"
        rlRun -l "ip -d link show ttt"
        rlRun -l "ip macsec show ttt"
        rlRun "ip link del ttt"

        # Bug 1354232 - MACsec: kernel panic if setup macsec repeatedly
        # rlRun "ip link add link dummy0 ${DEV}_1 type macsec"
        # rlRun "ip link add link dummy0 ${DEV}_2 type macsec"
        # rlRun "ip link add link dummy0 ${DEV}_3 type macsec"
        # rlRun "modprobe -r macsec"

        # port The "port" setting is just a shortcut to set the SCI using
        #      the address of the underlying device (here, dummy0's MAC
        #      address) and the port.12345 == 0x3039 which shows up as 3930 in the SCI.
        # Bug 1355629 - [RFE] ip-macsec: add port info for ip macsec show
        rlRun "ip link add link dummy0 name macsec0 type macsec port -1" 255
        rlRun "ip link add link dummy0 name macsec0 type macsec port 0" 255
        rlRun "ip link add link dummy0 name macsec0 type macsec port 65536" 255
        rlRun "ip link add link dummy0 name macsec0 type macsec port 12345"
        rlRun "ip link del macsec0"

        # SCI - secure channel identifier, 64 bits
        #       48 bits "system identifier" (MAC address)
        #       16 bits "port number"
        rlRun "ip link add link dummy0 name macsec0 type macsec sci 1"
        rlRun "ip link del macsec0"
        rlRun "ip link add link dummy0 name macsec0 type macsec sci 0100560212005452"
        rlRun "ip link del macsec0"
        # FIXME: check sci range, and verify by ip macsec show
        # FIXME: check make_sci

        # cipher suite: currently just support GCM-AES-128
        # ICV (Message authentication code), icvlen: 8..16
        # Bug 1354408 - ip-macsec: missing input cipher suite check
        #rlRun "ip link add link dummy0 name macsec0 type macsec cipher DES icvlen 16" 255
        rlRun "ip link add link dummy0 name macsec0 type macsec cipher GCM-AES-128 icvlen 0" 255
        rlRun "ip link add link dummy0 name macsec0 type macsec cipher GCM-AES-128 icvlen 16"
        rlAssertEquals "verify icvlen" $(ip macsec show | awk '/ICV length/ {print $NF}') 16
        rlRun "ip link del macsec0"

        # encrypt on or encrypt off - switches between authenticated encryption,
        # or authenticity mode only.
        rlRun "ip link add link dummy0 name macsec0 type macsec encrypt aa" 1
        rlRun "ip link add link dummy0 name macsec0 type macsec"
        rlAssertEquals "default encrypt is off" $(ip macsec show | awk '/macsec0/{match($0,"encrypt ([^ ]+)",M); print M[1]}') off
        rlRun "ip link del macsec0"
        rlRun "ip link add link dummy0 name macsec0 type macsec encrypt on"
        rlAssertEquals "veirfy encrypt is on" $(ip macsec show | awk '/macsec0/{match($0,"encrypt ([^ ]+)",M); print M[1]}') on
        rlRun "ip link del macsec0"

        # send_sci on or send_sci off - specifies whether the SCI is included in
        # every packet, or only when it is necessary.
        rlRun "ip link add link dummy0 name macsec0 type macsec send_sci aa" 1
        rlRun "ip link add link dummy0 name macsec0 type macsec"
        rlAssertEquals "default send_sci is on" $(ip macsec show | awk '/macsec0/{match($0,"send_sci ([^ ]+)",M); print M[1]}') on
        rlRun "ip link del macsec0"
        rlRun "ip link add link dummy0 name macsec0 type macsec send_sci off"
        rlAssertEquals "veirfy send_sci is off" $(ip macsec show | awk '/macsec0/{match($0,"send_sci ([^ ]+)",M); print M[1]}') off
        rlRun "ip link del macsec0"

        # end_station on or off - sets the End Station bit.
        # Bug 1354702 - ip-macsec: cannot set es on or es off
        rlRun "ip link add link dummy0 name macsec0 type macsec end_station aa" 1
        rlRun "ip link add link dummy0 name macsec0 type macsec"
        rlAssertEquals "default end_station is off" $(ip macsec show | awk '/macsec0/{match($0,"end_station ([^ ]+)",M); print M[1]}') off
        rlRun "ip link del macsec0"
        rlRun "ip link add link dummy0 name macsec0 type macsec end_station on"
        rlAssertEquals "veirfy end_station is on" $(ip macsec show | awk '/macsec0/{match($0,"end_station ([^ ]+)",M); print M[1]}') on
        rlRun "ip link del macsec0"

        # scb on or scb off - sets the Single Copy Broadcast bit.
        rlRun "ip link add link dummy0 name macsec0 type macsec scb aa" 1
        rlRun "ip link add link dummy0 name macsec0 type macsec"
        rlAssertEquals "default scb is off" $(ip macsec show | awk '/macsec0/{match($0,"scb ([^ ]+)",M); print M[1]}') off
        rlRun "ip link del macsec0"
        rlRun "ip link add link dummy0 name macsec0 type macsec scb on"
        rlAssertEquals "veirfy scb is on" $(ip macsec show | awk '/macsec0/{match($0,"scb ([^ ]+)",M); print M[1]}') on
        rlRun "ip link del macsec0"

        # protect on or protect off
        rlRun "ip link add link dummy0 name macsec0 type macsec protect aa" 1
        rlRun "ip link add link dummy0 name macsec0 type macsec"
        rlAssertEquals "default protect is on" $(ip macsec show | awk '/macsec0/{match($0,"protect ([^ ]+)",M); print M[1]}') on
        rlRun "ip link del macsec0"
        rlRun "ip link add link dummy0 name macsec0 type macsec protect off"
        rlAssertEquals "veirfy protect is off" $(ip macsec show | awk '/macsec0/{match($0,"protect ([^ ]+)",M); print M[1]}') off
        rlRun "ip link del macsec0"

        # replay on or replay off - enables replay protection on the device.
        #             window SIZE - sets the size of the replay window: 0..2^32-1
        rlRun "ip link add link dummy0 name macsec0 type macsec replay aa" 1
        rlRun "ip link add link dummy0 name macsec0 type macsec"
        rlAssertEquals "default replay is off" $(ip macsec show | awk '/macsec0/{match($0,"replay ([^ ]+)",M); print M[1]}') off
        rlRun "ip link del macsec0"
        rlRun "ip link add link dummy0 name macsec0 type macsec replay on" 1 "should specify window size"
        rlRun "ip link add link dummy0 name macsec0 type macsec window 1024" 1 "should turn replay on"
        rlRun "ip link add link dummy0 name macsec0 type macsec replay on window -1" 255 "out of window size"
        rlRun "ip link add link dummy0 name macsec0 type macsec replay on window 4294967296" 255 "out of window size"
        rlRun "ip link add link dummy0 name macsec0 type macsec replay on window 10240"
        rlAssertEquals "veirfy replay is on" $(ip macsec show | awk '/macsec0/{match($0,"replay ([^ ]+)",M); print M[1]}') on
        rlAssertEquals "veirfy window is 10240" $(ip macsec show | awk '/macsec0/{match($0,"window ([^ ]+)",M); print M[1]}') 10240
        rlRun "ip link del macsec0"

        # validate: strict, check of disabled
        rlRun "ip link add link dummy0 name macsec0 type macsec validate aa" 1
        rlRun "ip link add link dummy0 name macsec0 type macsec"
        rlAssertEquals "default validate is strict" $(ip macsec show | awk '/macsec0/{match($0,"validate ([^ ]+)",M); print M[1]}') strict
        rlRun "ip link del macsec0"
        rlRun "ip link add link dummy0 name macsec0 type macsec validate check"
        rlAssertEquals "veirfy validate is check" $(ip macsec show | awk '/macsec0/{match($0,"validate ([^ ]+)",M); print M[1]}') check
        rlRun "ip link del macsec0"
        rlRun "ip link add link dummy0 name macsec0 type macsec validate disabled"
        rlAssertEquals "veirfy validate is disabled" $(ip macsec show | awk '/macsec0/{match($0,"validate ([^ ]+)",M); print M[1]}') disabled
        rlRun "ip link del macsec0"

        # encoding AN - sets the active secure association for transmission: 0..3
        rlRun "ip link add link dummy0 name macsec0 type macsec encodingsa aa" 255
        rlRun "ip link add link dummy0 name macsec0 type macsec encodingsa -1" 255
        rlRun "ip link add link dummy0 name macsec0 type macsec encodingsa 4" 255
        rlRun "ip link add link dummy0 name macsec0 type macsec"
        rlAssertEquals "default encodingsa is 0" $(ip macsec show | awk '/TXSC/{match($0,"SA ([^ ]+)",M); print M[1]}') 0
        rlRun "ip link del macsec0"
        rlRun "ip link add link dummy0 name macsec0 type macsec encodingsa 2"
        rlAssertEquals "veirfy encodingsa is 2" $(ip macsec show | awk '/TXSC/{match($0,"SA ([^ ]+)",M); print M[1]}') 2
        rlRun "ip link del macsec0"
    rlPhaseEnd

    rlPhaseStartTest "ip macsec"
        modprobe -r macsec
        modprobe -r dummy
        if [ $(GetDistroRelease) -ge 8 ]; then
                modprobe dummy numdummies=1
        else
                modprobe dummy
        fi

        ip link set dummy0 up

        # basic sample
        rlRun "ip link add link dummy0 macsec0 type macsec sci 0100560212005452 encrypt on"
        rlRun "ip macsec add macsec0 rx sci $SCI_PEER"
        rlRun "ip macsec add macsec0 rx sci $SCI_PEER  sa 0 pn 1 on key 00 $KEY_0"
        rlRun "ip macsec add macsec0 tx                sa 0 pn 1 on key 00 $KEY_0"
        rlRun "ip macsec add macsec0 tx                sa 1 pn 1 on key 01 $KEY_1"
        rlRun "ip link set macsec0 up"
        rlRun "ip macsec show ttt" 1
        rlRun "ip macsec show macsec0"

        # set options
        rlRun "ip macsec add macsec0 tx sa 2" 1 "must specify a key"
        rlRun "ip macsec add macsec0 tx sa 2 key 99 123456789123456789" 1 "must specify the pn"

        # key_ID, key_KEY - 128 bits, so 32 hex chars, can use md5 to help generate
        gen_random_hex32()
        {
            head /dev/urandom | md5sum | awk '{print $1}'
        }
        rlRun "ip macsec add macsec0 tx sa 2 pn 100 key 03 123456789123456789" 2 "bad key length"
        hex32_01=$(gen_random_hex32)
        hex32_02=$(gen_random_hex32)
        rlRun "ip macsec add macsec0 tx sa 2 pn 100 key $hex32_01 $hex32_02"
        rlRun "ip macsec show | grep $hex32_01"

        # port number
        rlRun "ip macsec set macsec0 tx sa 2 pn 1024 off"
        rlRun "ip macsec set macsec0 tx sa 2 pn 1024 on"

        # del
        rlRun "ip macsec del macsec0 rx sci $SCI_PEER"
        # Bug 1357349 - MACsec: fail to delete macsec tx/rx sa

    rlPhaseEnd

    rlPhaseStartTest "check MTU"
        # the SecTAG before Secure Data is 16 tytes
        # the ICV after Secure Data is 16 bytes by default, which can be set by icvlen (8..16)
        modprobe -r macsec
        modprobe -r dummy
        if [ $(GetDistroRelease) -ge 8 ]; then
                modprobe dummy numdummies=1
        else
                modprobe dummy
        fi

        rlRun "ip link add link dummy0 macsec0 type macsec"
        rlAssertEquals "default real_dev MTU is 1500" $(cat /sys/class/net/dummy0/mtu) 1500
        rlAssertEquals "default macsec header + tailer is 32" $(cat /sys/class/net/macsec0/mtu) $((1500-32))
        rlRun "ip link del macsec0"
        rlRun "ip link add link dummy0 macsec0 type macsec cipher default icvlen 8"
        rlAssertEquals "set macsec tailer to 8" $(cat /sys/class/net/macsec0/mtu) $((1500-16-8))
        rlRun "ip link del macsec0"
        rlRun "ip link add link dummy0 macsec0 type macsec cipher default icvlen 16"
        rlAssertEquals "set macsec tailer to 16" $(cat /sys/class/net/macsec0/mtu) $((1500-16-16))
        rlRun "ip link del macsec0"

        # macsec MTU value range should less than real_dev's
        rlRun "ip link add link dummy0 macsec0 type macsec"
        rlRun "ip link set dummy0 mtu 9000"
        rlRun "ip link set macsec0 mtu 9000" 2
        rlRun "ip link set macsec0 mtu 100"
        rlRun "ip link set macsec0 mtu 1500"
        rlRun "ip link set macsec0 mtu 3000"
        rlRun "ip link set macsec0 mtu 8968"

        # macsec MTU value should be reduced automatiaclly to adapt to real_dev
        for i in 9000 5000 1500 100; do
            sleep 1
            rlRun "ip link set dummy0 mtu $i"
            rlAssertEquals "macsec should adapt to real_dev" $(cat /sys/class/net/macsec0/mtu) $((i-32))
        done
        rlRun "ip link del macsec0"
    rlPhaseEnd

    rlPhaseStartTest "check promiscuous mode"
        function if_dev_promisc()
        {
            # return 1 for in promisc mode
            # return 0 for in nopromisc mode
            local dev=$1
            local dev_flags=$(cat /sys/class/net/$dev/flags)
            dev_promisc_info="$dev: $dev_flags"
            local ret=$(((dev_flags & 0x100) >> 8))
            return $ret
        }
        modprobe -r macsec
        modprobe -r dummy
        if [ $(GetDistroRelease) -ge 8 ]; then
                modprobe dummy numdummies=1
        else
                modprobe dummy
        fi

        # the real device underneath macsec should enter promiscuous mode automatiaclly
        rlRun "ip link add link dummy0 macsec0 type macsec"
        rlRun "ip link set dummy0 up"
        rlRun "if_dev_promisc dummy0" 0
        rlRun "ip link set macsec0 up"
        rlRun "if_dev_promisc dummy0" 1
        rlRun "ip link del macsec0"
    rlPhaseEnd

    # Workaround: Temporarily disable this case because system panicked due to
    #             bz1745880. For more, please refer to FASTMOVING-1155
:<<!
    rlPhaseStartTest "Setup masec between 2 netns, do ping/netperf test"
        netid=100
#        brctl addbr br0
        ip link add br0 type bridge
        ip link set br0 up

        ip link add veth0 type veth peer name veth1
        ip link add veth2 type veth peer name veth3
        ip link set veth1 up
        ip link set veth3 up
       # brctl addif br0 veth1
       # brctl addif br0 veth3
        ip link set veth1 master br0
        ip link set veth3 master br0

        ip netns add ns0
        ip link set veth0 netns ns0
        ip netns exec ns0 ip link set veth0 up
        ip netns exec ns0 ip addr add 192.168.${netid}.11/24 dev veth0
        ip netns exec ns0 ip addr add 2001:db8:${netid}::11/64 dev veth0
        ip netns exec ns0 netserver

        ip netns add ns1
        ip link set veth2 netns ns1
        ip netns exec ns1 ip link set veth2 up
        ip netns exec ns1 ip addr add 192.168.${netid}.21/24 dev veth2
        ip netns exec ns1 ip addr add 2001:db8:${netid}::21/64 dev veth2
        ip netns exec ns1 netserver

       # brctl show br0
        bridge link show
        ip netns exec ns0 ifconfig -a
        ip netns exec ns1 ifconfig -a

        rlRun "ip netns exec ns0 ping 192.168.${netid}.21 -c 5"
        rlRun "ip netns exec ns0 ping6 2001:db8:${netid}::21 -c 5"

        # setup macsec on ns0
        rlRun "ip netns exec ns0 ip link add link veth0 macsec0 type macsec sci $SCI_NODE encrypt on"
        rlRun "ip netns exec ns0 ip macsec add macsec0 rx sci $SCI_PEER"
        rlRun "ip netns exec ns0 ip macsec add macsec0 rx sci $SCI_PEER  sa 0 pn 1 on key 00 $KEY_0"
        rlRun "ip netns exec ns0 ip macsec add macsec0 tx                sa 0 pn 1 on key 00 $KEY_0"
        rlRun "ip netns exec ns0 ip link set macsec0 up"
        rlRun "ip netns exec ns0 ip macsec show macsec0"
        rlRun "ip netns exec ns0 ip addr add 192.168.9.1/24 dev macsec0"
        rlRun "ip netns exec ns0 ip addr add 2009::01/64 dev macsec0"

        # setup macsec on ns1
        rlRun "ip netns exec ns1 ip link add link veth2 macsec0 type macsec sci $SCI_PEER encrypt on"
        rlRun "ip netns exec ns1 ip macsec add macsec0 rx sci $SCI_NODE"
        rlRun "ip netns exec ns1 ip macsec add macsec0 rx sci $SCI_NODE  sa 0 pn 1 on key 00 $KEY_0"
        rlRun "ip netns exec ns1 ip macsec add macsec0 tx                sa 0 pn 1 on key 00 $KEY_0"
        rlRun "ip netns exec ns1 ip link set macsec0 up"
        rlRun "ip netns exec ns1 ip macsec show macsec0"
        rlRun "ip netns exec ns1 ip addr add 192.168.9.2/24 dev macsec0"
        rlRun "ip netns exec ns1 ip addr add 2009::02/64 dev macsec0"

        # network traffic test from ns1 to ns0
        rlRun "ip netns exec ns1 arping 192.168.9.1 -I veth2 -c 5"
        rlRun "ip netns exec ns1 ping 192.168.9.1 -c 5"
        rlRun "ip netns exec ns1 ping6 2009::01 -c 5"

        rlRun "ip netns exec ns1 netperf -H 192.168.9.1 -t TCP_STREAM -l 30"
        rlRun "ip netns exec ns1 netperf -H 2009::01 -t TCP_STREAM -l 30"
        rlRun "ip netns exec ns1 netperf -H 192.168.9.1 -t UDP_STREAM -l 30"
        rlRun "ip netns exec ns1 netperf -H 2009::01 -t UDP_STREAM -l 30"

        ip netns exec ns0 ip link set veth0 netns 1
        ip netns exec ns1 ip link set veth2 netns 1
        ip netns del ns0
        ip netns del ns1

        #brctl delif br0 veth1
       # brctl delif br0 veth3
        ip link set veth1 nomaster
        ip link set veth3 nomaster
        ip link set br0 down
       # brctl delbr br0
        ip link del br0
        ip link del veth0
        ip link del veth2
    rlPhaseEnd
!

    rlPhaseStartTest "fault injection"
        rlRun "CMD_ARRAY=(
            'modprobe -r macsec'
            'modprobe macsec'
            'modprobe -r dummy'
            'modprobe dummy numdummies=1'
            'ip link add link dummy0 type macsec sci 0100560212005452 encrypt on'
            'ip link add link dummy0 name macsec0 type macsec port 12345'
            'ip link add link dummy0 name macsec0 type macsec replay on window 429496729'
            'ip macsec add macsec0 tx sa 0 pn 1024 on key 01 81818181818181818181818181818181'
            'ip macsec add macsec0 rx port 1234 address c6:19:52:8f:e6:a0'
            'ip macsec add macsec0 rx port 1234 address c6:19:52:8f:e6:a0 sa 0 pn 1 on key 00 82828282828282828282828282828282'
            'ip link set dummy0 up'
            'ip link set macsec0 up'
            'ip addr add 192.168.9.1/24 dev macsec0'
            'ip addr add 2009::01/64 dev macsec0'
            'arping 192.168.9.9 -I macsec0 -c 30'
            'ip link set dummy0 mtu 9000'
            'ip link set dummy0 mtu 1500'
            'ip link set macsec0 mtu 8968'
            'ip link set macsec0 mtu 1468'
            'ip link set dummy0 down'
            'ip link set macsec0 down'
            'ip macsec del macsec0 rx sci d204a0e68f5219c6 sa 0'
            'ip link del macsec0'

        )"
        rlRun "CMD_CNT=${#CMD_ARRAY[@]}"

        # run the command in disorder, system should not panic"
        for i in `seq 100`; do
            index=$((RANDOM % CMD_CNT))
            rlRun "${CMD_ARRAY[index]}" 0-100
        done
    rlPhaseEnd

    rlPhaseStartCleanup
        rlRun "reset_network_env"
    rlPhaseEnd
rlJournalPrintText
rlJournalEnd
