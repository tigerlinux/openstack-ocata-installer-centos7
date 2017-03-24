#!/bin/bash
#
# Unattended installer for OpenStack
# Reynaldo R. Martinez P.
# E-Mail: TigerLinux@Gmail.com
#
# Instance CPU Metric report Script
#

PATH=$PATH:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin

mykeystonefile="/root/keystonerc_admin"

source $mykeystonefile

defvalue="86400"

if [ ! -z $1 ]
then
	case $1 in
	"hour")
		echo ""
		echo "Resampling to one hour intervals"
		defvalue="3600"
		;;
	"minute")
		echo ""
		echo "Resampling to one minute intervals"
		defvalue="60"
		;;
	"day")
		echo ""
		echo "Resampling to one day intervals"
		defvalue="86400"
		;;
	"--help"|"-h"|"help")
		echo ""
		echo "Optional arguments:"
		echo "hour: Resamples to one hour intervals"
		echo "minute: Resamples to one minute intervals"
		echo "day: Resamples to one day intervals"
		echo ""
		exit 0
		;;
	*)
		echo ""
		echo "Resampling to one day intervals"
		defvalue="86400"
		;;
	esac
else
	echo ""
	echo "Resampling to one day intervals"
fi

echo ""

for uuid in `openstack server list --format=csv --all-projects 2>/dev/null|grep -v ID|cut -d\" -f2`
do
	instancename=`openstack server show $uuid -c name -f value`
	echo "Instance name: $instancename (id: $uuid)"
	openstack metric measures show --resource-id $uuid cpu_util --granularity 300 --resample $defvalue -c timestamp -c value
	echo ""
done

echo ""
