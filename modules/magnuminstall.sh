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

if [ -f /etc/openstack-control-script-config/magnum-installed ]
then
	echo ""
	echo "This module was already completed. Exiting !"
	echo ""
	exit 0
fi

#
# We proceed to install MAGNUM Packages
#

echo ""
echo "Installing MAGNUM Packages"

yum install -y openstack-magnum-api \
	openstack-magnum-common \
	openstack-magnum-conductor \
	python2-magnumclient \
	openstack-utils \
	openstack-selinux

echo "Done"
echo ""

#
# Fix for python2-kubernetes not present
#
kubepythonhere=`rpm -qa|grep kubernetes|wc -l`
if [ $kubepythonhere == 0 ]
then
	yum -y install python-pip
	pip install kubernetes
fi


source $keystone_admin_rc_file

echo ""
echo "Configuring MAGNUM"
echo ""

#
# By using python based tools, we proceed to configure magnum.
#


echo "#" >> /etc/magnum/magnum.conf

chown -R magnum.magnum /etc/magnum


case $dbflavor in
"mysql")
	crudini --set /etc/magnum/magnum.conf database connection mysql+pymysql://$magnumdbuser:$magnumdbpass@$dbbackendhost:$mysqldbport/$magnumdbname
	;;
"postgres")
	crudini --set /etc/magnum/magnum.conf database connection postgresql+psycopg2://$magnumdbuser:$magnumdbpass@$dbbackendhost:$psqldbport/$magnumdbname
	;;
esac

crudini --set /etc/magnum/magnum.conf database retry_interval 10
crudini --set /etc/magnum/magnum.conf database idle_timeout 3600
crudini --set /etc/magnum/magnum.conf database min_pool_size 1
crudini --set /etc/magnum/magnum.conf database max_pool_size 10
crudini --set /etc/magnum/magnum.conf database max_retries 100
crudini --set /etc/magnum/magnum.conf database pool_timeout 10
crudini --set /etc/magnum/magnum.conf database backend sqlalchemy
 
crudini --set /etc/magnum/magnum.conf DEFAULT host `hostname`
crudini --set /etc/magnum/magnum.conf DEFAULT debug false
crudini --set /etc/magnum/magnum.conf DEFAULT log_dir /var/log/magnum

crudini --set /etc/magnum/magnum.conf api port 9511
crudini --set /etc/magnum/magnum.conf api host 0.0.0.0
crudini --set /etc/magnum/magnum.conf api api_paste_config "/etc/magnum/api-paste.ini"

#
# Keystone Authentication
#
source $keystone_admin_rc_file
domaindefaultid=`openstack domain show default -f value -c id`
#
crudini --set /etc/magnum/magnum.conf keystone_authtoken project_name $keystoneservicestenant
crudini --set /etc/magnum/magnum.conf keystone_authtoken username $magnumuser
crudini --set /etc/magnum/magnum.conf keystone_authtoken password $magnumpass
crudini --set /etc/magnum/magnum.conf keystone_authtoken auth_url http://$keystonehost:35357
crudini --set /etc/magnum/magnum.conf keystone_authtoken project_domain_name $keystonedomain
crudini --set /etc/magnum/magnum.conf keystone_authtoken project_domain_id $domaindefaultid
crudini --set /etc/magnum/magnum.conf keystone_authtoken user_domain_name $keystonedomain
crudini --set /etc/magnum/magnum.conf keystone_authtoken user_domain_id $domaindefaultid
# crudini --set /etc/magnum/magnum.conf keystone_authtoken signing_dir /tmp/keystone-signing-magnum
crudini --set /etc/magnum/magnum.conf keystone_authtoken auth_type password
crudini --set /etc/magnum/magnum.conf keystone_authtoken auth_version v3
crudini --set /etc/magnum/magnum.conf keystone_authtoken auth_uri http://$keystonehost:5000/v3
crudini --set /etc/magnum/magnum.conf keystone_authtoken memcached_servers $keystonehost:11211
# Due the following bug, admin_user, admin_tenant_name and admin_password are still needed:
# https://bugs.launchpad.net/magnum/+bug/1594888
crudini --set /etc/magnum/magnum.conf keystone_authtoken identity_uri http://$keystonehost:35357
crudini --set /etc/magnum/magnum.conf keystone_authtoken admin_user $magnumuser
crudini --set /etc/magnum/magnum.conf keystone_authtoken admin_tenant_name $keystoneservicestenant
crudini --set /etc/magnum/magnum.conf keystone_authtoken admin_password $magnumpass
#
# Failsafes !
# crudini --del /etc/magnum/magnum.conf keystone_authtoken auth_version
crudini --del /etc/magnum/magnum.conf keystone_authtoken auth_section
# crudini --del /etc/magnum/magnum.conf keystone_authtoken identity_uri
# crudini --del /etc/magnum/magnum.conf keystone_authtoken admin_tenant_name
# crudini --del /etc/magnum/magnum.conf keystone_authtoken admin_user
# crudini --del /etc/magnum/magnum.conf keystone_authtoken admin_password
crudini --del /etc/magnum/magnum.conf keystone_authtoken auth_host
crudini --del /etc/magnum/magnum.conf keystone_authtoken auth_port
crudini --del /etc/magnum/magnum.conf keystone_authtoken auth_protocol
#
crudini --set /etc/magnum/magnum.conf trust trustee_domain_name $magnum_domain_name
crudini --set /etc/magnum/magnum.conf trust trustee_domain_admin_name $magnum_domain_admin
crudini --set /etc/magnum/magnum.conf trust trustee_domain_admin_password $magnum_domain_admin_password 
#
crudini --set /etc/magnum/magnum.conf cinder_client region_name $endpointsregion
crudini --set /etc/magnum/magnum.conf cinder_client endpoint_type internalURL
crudini --set /etc/magnum/magnum.conf glance_client endpoint_type internalURL
crudini --set /etc/magnum/magnum.conf heat_client endpoint_type internalURL
crudini --set /etc/magnum/magnum.conf magnum_client endpoint_type internalURL
crudini --set /etc/magnum/magnum.conf neutron_client endpoint_type internalURL
crudini --set /etc/magnum/magnum.conf nova_clientendpoint_type internalURL
#
# End of Keystone Auth Section
#

#
# Certificate control - by the moment only x509keypair. When we include barbican, we'll
# add it as a config-controllable option
#
crudini --set /etc/magnum/magnum.conf certificates cert_manager_type x509keypair

#
# Oslo concurrencty
mkdir -p /var/oslock/magnum
chown -R magnum.magnum /var/oslock/magnum
crudini --set /etc/magnum/magnum.conf oslo_concurrency lock_path "/var/oslock/magnum"

#
# Profiler
crudini --set /etc/magnum/magnum.conf profiler enabled true

#
# Notification/messaging
#
crudini --set /etc/magnum/magnum.conf DEFAULT control_exchange openstack
#
crudini --set /etc/magnum/magnum.conf DEFAULT transport_url rabbit://$brokeruser:$brokerpass@$messagebrokerhost:5672/$brokervhost
crudini --set /etc/magnum/magnum.conf DEFAULT rpc_backend rabbit
crudini --set /etc/magnum/magnum.conf oslo_messaging_rabbit rabbit_host $messagebrokerhost
crudini --set /etc/magnum/magnum.conf oslo_messaging_rabbit rabbit_password $brokerpass
crudini --set /etc/magnum/magnum.conf oslo_messaging_rabbit rabbit_userid $brokeruser
crudini --set /etc/magnum/magnum.conf oslo_messaging_rabbit rabbit_port 5672
crudini --set /etc/magnum/magnum.conf oslo_messaging_rabbit rabbit_use_ssl false
crudini --set /etc/magnum/magnum.conf oslo_messaging_rabbit rabbit_virtual_host $brokervhost
crudini --set /etc/magnum/magnum.conf oslo_messaging_rabbit rabbit_max_retries 0
crudini --set /etc/magnum/magnum.conf oslo_messaging_rabbit rabbit_retry_interval 1
crudini --set /etc/magnum/magnum.conf oslo_messaging_rabbit rabbit_ha_queues false
#
crudini --set /etc/magnum/magnum.conf oslo_messaging_notifications driver messagingv2
#

echo ""
echo "Magnum Configured"
echo ""

#
# We proceed to provision/update MAGNUM Database
#

echo ""
echo "Provisioning MAGNUM Database"
echo ""

chown -R magnum.magnum /var/log/magnum /etc/magnum
su -s /bin/sh -c "magnum-db-manage upgrade" magnum
chown -R magnum.magnum /etc/magnum /var/log/magnum

echo ""
echo "Done"
echo ""

#
# We proceed to apply IPTABLES rules and start/enable Magnum services
#

echo ""
echo "Applying IPTABLES Rules"

iptables -A INPUT -p tcp -m multiport --dports 9511 -j ACCEPT
service iptables save

echo "Done"

echo ""
echo "Cleaning UP App logs"
 
for mylog in `ls /var/log/magnum/*.log`; do echo "" > $mylog;done
 
echo "Done"
echo ""

echo ""
echo "Starting MAGNUM"
echo ""

servicelist='
	openstack-magnum-api
	openstack-magnum-conductor
'

for myservice in $servicelist
do
	echo "Starting and Enabling Service: $myservice"
	systemctl start $myservice
	systemctl enable $myservice
	systemctl status $myservice
done


#
# Finally, we proceed to verify if MAGNUM was properlly installed. If not, we stop further procedings.
#

testmagnum=`rpm -qi openstack-magnum-common|grep -ci "is not installed"`
if [ $testmagnum == "1" ]
then
	echo ""
	echo "MAGNUM Installation FAILED. Aborting !"
	echo ""
	exit 0
else
	date > /etc/openstack-control-script-config/magnum-installed
	date > /etc/openstack-control-script-config/magnum
fi


echo ""
echo "Magnum Installed and Configured"
echo ""

