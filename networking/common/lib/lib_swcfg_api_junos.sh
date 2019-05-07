#!/bin/sh
#

# JUNOS

# Different switch will have different way to setup
# The file is for Juniper JUNOS
#
# For cmd_setup_global and cmd_setup_for_each_port is mainly
# used to setup configuration before test
#
# The test will require features below
# 1. enable lacp feature
# 2. enable jumbo frame receiving
# 3. set the tested port to vlan trunk mode
#    and set the native-vlan-id
#
# For other cmd_*, please see the comment below
#
# PLEASE NOTE that the command name cannot be changed,
# and currently only the commands below are used in the script
#
# Parameters are defined in the test script, the name cannot be changed also
#


# Setup global before test
# 1. create vlan and allow vlan 3-100
# 2. create groups
#    enable receiving jumbo
#    set vlan mode to trunk
#    set native vlan
# 3. set aggregate ethernet device-count to 100
#
# @PARAMETERS
#    NONE
#
cmd_setup_global='
configure private
edit vlans default
set vlan-id 1
top
edit vlans net-test
set vlan-range 3-100
top
edit groups test-ports interfaces <*>
set mtu 9216
set unit 0 family ethernet-switching port-mode trunk
set unit 0 family ethernet-switching vlan members net-test
set unit 0 family ethernet-switching native-vlan-id 1
top
edit chassis
set aggregated-devices ethernet device-count 100
top
show | diff
commit
exit
show configuration groups test-ports
'

# Setup on each port before test
#
# enable trunk mode and allow vlan 1-100
# native vlan is mandatory
#
# @PARAMETERS
#   $VAR_IFACE
#
cmd_setup_for_each_port='
configure private
set interfaces $VAR_IFACE apply-groups test-ports
show | diff
commit
exit
show configuration interfaces $VAR_IFACE
'

# enable interface
#
# @PARAMETERS
#   $VAR_IFACE
#
cmd_port_up='
configure private
delete interfaces $VAR_IFACE disable
top
show | diff
commit
exit
show interface $VAR_IFACE terse
'

# disable interface
#
# @PARAMETERS
#   $VAR_IFACE
#
cmd_port_down='
configure private
set interfaces $VAR_IFACE disable
top
show | diff
commit
exit
show interface $VAR_IFACE terse
'

# create bonding master interface
# set vlan mode to trunk
# allow tagged vlan 1-100
# native vlan is mandatory
#
# @PARAMETERS
#   $VAR_BONDING_ID
#
cmd_new_bonding_iface='
configure private
set interfaces ae${VAR_BONDING_ID} apply-groups test-ports
set interfaces ae${VAR_BONDING_ID} aggregated-ether-options lacp ${VAR_LACP_MODE}
set interfaces ae${VAR_BONDING_ID} aggregated-ether-options lacp periodic fast
show | diff
commit
exit
show lacp interfaces
'

# add slave interface to bonding
# enable LACP
#
# @PARAMETERS
#   $VAR_IFACE
#   $VAR_BONDING_ID
#   $VAR_LACP_MODE
#
cmd_add_slave_to_bonding='
configure private
delete interfaces $VAR_IFACE apply-groups test-ports
set interfaces $VAR_IFACE ether-options 802.3ad ae${VAR_BONDING_ID}
show | diff
commit
exit
show interface $VAR_IFACE terse
show lacp interfaces
'

# check bonding status
# @PARAMETERS
#
cmd_check_bonding_status='
show interface $VAR_IFACE terse
show lacp interfaces
'

# remove a slave from bonding
#
# @PARAMETERS
#   $VAR_IFACE
#
cmd_remove_slave_from_bonding='
configure private
delete interfaces $VAR_IFACE ether-options 802.3ad ae${VAR_BONDING_ID}
set interfaces $VAR_IFACE apply-groups test-ports
show | diff
commit
exit
show interface $VAR_IFACE terse
show lacp interfaces
'

# remove bonding master interface
#
# @PARAMETERS
#   $VAR_BONDING_ID
#
cmd_remove_bonding_interface='
configure private
delete interfaces ae${VAR_BONDING_ID}
show | diff
commit
exit
show interface $VAR_IFACE terse
show lacp interfaces
'
