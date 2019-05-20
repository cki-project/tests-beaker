#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   runtest.sh of /kernel/networking/socket/socket_fuzz
#   Description: socket/socket_fuzz
#   Author: Hangbin Liu <haliu@redhat.com>
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
. ../../common/include.sh || exit 1

disable_avc_check
# install sctp header file
lksctp_install
# load can module
modprobe can
if [ ! -x socket ];then
	gcc -Wall socket.c help.c func.c udp.c tcp.c sctp.c common.c setopt.c \
	-o socket -pthread -lrt
fi
TEST_TIME=${TEST_TIME:-1000}
REMOTE_ADDR4=${REMOTE_ADDR4:-"127.0.0.1"}
REMOTE_ADDR6=${REMOTE_ADDR6:-"::1"}

sed -i '/remote_host/d' /etc/hosts
echo "$REMOTE_ADDR4	remote_host" >> /etc/hosts
echo "$REMOTE_ADDR6	remote_host" >> /etc/hosts

./socket -H remote_host &

sleep $TEST_TIME

pkill socket
pkill socket

test_pass "Socket_fuzz"
