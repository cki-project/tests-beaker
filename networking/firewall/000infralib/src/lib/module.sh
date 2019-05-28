#!/bin/sh

###########################################################
# modules process (for netfilter.sh & netsched.sh)
###########################################################
modules_list()
{
	local item=""; local modules="";
	for item in $@; do
		if test -d $item; then
			modules=$modules" "$(find $item -type f -name '*ko*' | xargs -I {} basename {} | awk -F . '{print $1}')
		else
			modules=$modules" "$item
		fi
	done
	echo -n $modules
}
modules_show()
{
	local lsmods=$(lsmod | awk '{print $1}'); local module="";
	for module in $@; do
		[[ $lsmods =~ (^|[[:space:]])"$module"($|[[:space:]]) ]] && echo $module
	done
	return 0
}
modules_load()
{
	local result=0; local module="";
	for module in $@; do
		if [ $module == "ebt_ulog" ] || [ $module == "ipt_ULOG" ]; then
			# It is a known issue that ebt_ulog and ipt_ULOG shares some resources,
			# so they can't be loaded at the same time.
			modprobe $module
		else
			modprobe $module || { result=1; }
		fi
	done
	return $result
}
modules_unload()
{
	local result=0; local module="";
	for module in $@; do
		module_unload $module || { result=1; echo "ERROR: Module $module can't be unloaded!"; }
	done
	return $result
}
module_unload()
{
	local module=$1; local holder="";
	lsmod | grep -q $module || { return 0; }
	rmmod $module > /dev/null 2>&1 && { return 0; }
	test -e /sys/module/$module/holders/ || { return 1; }
	for holder in $(ls /sys/module/$module/holders/); do
		module_unload $holder
	done
	rmmod $module > /dev/null 2>&1 || { return 1; }
}

