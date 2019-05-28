#!/bin/sh

###########################################################
# socket client/server
###########################################################
sock()
{
	if [ $1 == "client" ]; then
		##############################
		# socket client
		##############################
		sleep 1
		python3 ${BASH_SOURCE/%sock.sh/sock.py} $@
	else
		##############################
		# socket server
		##############################
		python3 ${BASH_SOURCE/%sock.sh/sock.py} $@
	fi
}

