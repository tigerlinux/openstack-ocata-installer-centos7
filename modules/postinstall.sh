#!/bin/bash
#
# Unattended/SemiAutomatted OpenStack Installer
# Reynaldo R. Martinez P.
# E-Mail: TigerLinux@Gmail.com
# OpenStack OCATA for Centos 7
#
#

PATH=$PATH:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin

#
# First, we source our config file and verify that some important proccess are 
# already completed.
#

if [ -f ./configs/main-config.rc ]
then
	source ./configs/main-config.rc
	mkdir -p /etc/openstack-control-script-config
else
	echo "Can't access my config file. Aborting !"
	echo ""
	exit 0
fi

if [ -f /etc/openstack-control-script-config/db-installed ]
then
	echo ""
	echo "DB Proccess OK. Let's continue"
	echo ""
else
	echo ""
	echo "DB Proccess not completed. Aborting !"
	echo ""
	exit 0
fi

if [ -f /etc/openstack-control-script-config/keystone-installed ]
then
	echo ""
	echo "Keystone Proccess OK. Let's continue"
	echo ""
else
	echo ""
	echo "Keystone Proccess not completed. Aborting !"
	echo ""
	exit 0
fi

if [ -f /etc/openstack-control-script-config/postinstall-done ]
then
	echo ""
	echo "This module was already completed. Exiting !"
	echo ""
	exit 0
fi

#
# We copy our scripts and crontabs
#

cp -v ./libs/openstack-control.sh /usr/local/bin/
cp -v ./libs/openstack-log-cleaner.sh /usr/local/bin/
cp -v ./libs/openstack-vm-boot-start.sh /usr/local/bin/
cp -v ./libs/compute-and-instances-full-report.sh /usr/local/bin/
cp -v ./libs/instance-cpu-metrics-report.sh /usr/local/bin/
if [ $keystoneinstall == "yes" ]
then
	case $keystonetokenflavor in
	"fernet")
		cp -v ./libs/keystone-rotate.crontab /etc/cron.d/
		;;
	"pki"|"uuid")
		cp -v ./libs/openstack-keystone-tokenflush.sh /usr/local/bin/
		chmod 755 /usr/local/bin/openstack-keystone-tokenflush.sh
		cp -v ./libs/keystone-flush.crontab /etc/cron.d/
		;;
	esac
fi
cp -v ./libs/nova-start-vms.conf /etc/openstack-control-script-config/

chmod 755 /usr/local/bin/openstack-control.sh
chmod 755 /usr/local/bin/openstack-log-cleaner.sh
chmod 755 /usr/local/bin/compute-and-instances-full-report.sh
chmod 755 /usr/local/bin/openstack-vm-boot-start.sh

systemctl restart crond

#
# Then we clean all OpenStack related logs and restarts all OpenStack related services
#

echo ""
echo "Restarting all OpenStack services and cleaning up all logs"
echo ""

/usr/local/bin/openstack-control.sh stop
case $brokerflavor in
"rabbitmq")
	service rabbitmq-server stop
	;;
"qpid")
	service qpidd stop
	;;
esac
sleep 1
sync
sleep 1
case $brokerflavor in
"rabbitmq")
	service rabbitmq-server start
	;;
"qpid")
	service qpidd start
	;;
esac
sync
sleep 1
/usr/local/bin/openstack-log-cleaner.sh auto
sync
sleep 1
/usr/local/bin/openstack-control.sh enable
/usr/local/bin/openstack-control.sh start

#
# And we are DONE !!!
#

echo ""
echo "Post Install Done"
echo ""
/usr/local/bin/openstack-control.sh status
echo ""

date > /etc/openstack-control-script-config/postinstall-done

echo ""
echo "REMEMBER !!!"
echo "For any additional COMPUTE NODE you add in your OpenStack deployment, please"
echo "run the following command IN YOUR NOVA CONTROLLER NODE:"
echo "su -s /bin/sh -c \"nova-manage cell_v2 discover_hosts --verbose\" nova"
echo ""
echo "You can use the script /usr/local/bin/openstack-control.sh for administration tasks"
echo "Your administrative userid is: $keystoneadminuser, password: $keystoneadminpass"
echo "Use your web-based dashboard at: http://$horizonhost"
echo ""
echo "Thanks you very much for using this automated tool"
echo ""
