#!/bin/sh
#

# NXOS

# Different switch will have different way to setup
# This file is for Cisco NXOS
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
# 1. disable igmp snooping
#    enable feature lacp
# 2. enable receiving jubmo frame
#
# @PARAMETERS
#   NONE
#
cmd_setup_global='
conf t
no ip igmp snooping
feature lacp
policy-map type network-qos jumbo
  class type network-qos class-default
    mtu 9216
    end
conf t
system qos
  service-policy type network-qos jumbo
  end
show run
'

# Setup on each port before test
#
# enable trunk mode and allow vlan 1-100
# nxos will have vlan1 as native vlan
# native vlan is mandatory
#
# @PARAMETERS
#   $VAR_IFACE
#
cmd_setup_for_each_port='
conf t
interface $VAR_IFACE
  switchport mode trunk
  switchport trunk allowed vlan 1-100
  end
show run
'

# enable interface
#
# @PARAMETERS
#   $VAR_IFACE
#
cmd_port_up='
configure t
interface $VAR_IFACE
  no shutdown
  end
sleep 15
show run interface $VAR_IFACE
show interface $VAR_IFACE status
'

# disable interface
#
# @PARAMETERS
#   $VAR_IFACE
#
cmd_port_down='
configure t
interface $VAR_IFACE
  shutdown
  end
show run interface $VAR_IFACE
show interface $VAR_IFACE status
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
configure t
interface port-channel$VAR_BONDING_ID
  switchport mode trunk
  switchport trunk allowed vlan 1-100
  end
show run interface port-channel$VAR_BONDING_ID
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
configure t
interface $VAR_IFACE
  no channel-group
  channel-group $VAR_BONDING_ID mode $VAR_LACP_MODE
  lacp rate fast
  end
show run int $VAR_IFACE
'

# check bonding status
# @PARAMETERS
#
cmd_check_bonding_status='
show port-channel summary
'

# remove a slave from bonding
#
# @PARAMETERS
#   $VAR_IFACE
#
cmd_remove_slave_from_bonding='
config t
  interface $VAR_IFACE
    no lacp rate fast
    no channel-group
    end
show run int $VAR_IFACE
'

# remove bonding master interface
# 
# @PARAMETERS
#   $VAR_BONDING_ID
#
cmd_remove_bonding_interface='
config t
  no interface port-channel$VAR_BONDING_ID
  end
show run
'

