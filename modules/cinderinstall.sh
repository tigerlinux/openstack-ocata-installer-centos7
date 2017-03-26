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
	echo "Can't access my config file. Aborting !."
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

if [ -f /etc/openstack-control-script-config/cinder-installed ]
then
	echo ""
	echo "This module was already completed. Exiting"
	echo ""
	exit 0
fi


echo "Installing Cinder Packages"

#
# We proceed to install the cinder packages and dependencies
#

case $cindernodetype in
"allinone")
	echo "Installing cinder packages for an ALL-IN-ONE Cinder node"
	yum -y install openstack-cinder openstack-utils openstack-selinux
	yum -y install lvm2 targetcli
	yum -y install python-oslo-db python-oslo-log MySQL-python
	systemctl enable lvm2-lvmetad.service
	systemctl start lvm2-lvmetad.service
	;;
"controller")
	echo "Installing cinder packages for a Cinder-Controller node"
	yum -y install openstack-cinder openstack-utils openstack-selinux
	yum -y install python-oslo-db python-oslo-log MySQL-python
	;;
"storage")
	echo "Installing cinder packages for a Cinder storage-only node"
	yum -y install openstack-cinder openstack-utils openstack-selinux
	yum -y install lvm2 targetcli
	yum -y install python-oslo-db python-oslo-log MySQL-python
	systemctl enable lvm2-lvmetad.service
	systemctl start lvm2-lvmetad.service
	;;
esac

source $keystone_admin_rc_file

echo "Done"

echo ""
echo "Configuring Cinder"

sync
sleep 5
sync

#
# Using python based tools, we proceed to configure Cinder Services
#

 
crudini --set /etc/cinder/cinder.conf DEFAULT osapi_volume_listen 0.0.0.0
crudini --set /etc/cinder/cinder.conf DEFAULT api_paste_config /etc/cinder/api-paste.ini
crudini --set /etc/cinder/cinder.conf DEFAULT glance_host $glancehost
crudini --set /etc/cinder/cinder.conf DEFAULT auth_strategy keystone
crudini --set /etc/cinder/cinder.conf DEFAULT debug False
crudini --set /etc/cinder/cinder.conf DEFAULT use_syslog False
crudini --set /etc/cinder/cinder.conf DEFAULT my_ip $cindernodehost

crudini --set /etc/cinder/cinder.conf DEFAULT transport_url rabbit://$brokeruser:$brokerpass@$messagebrokerhost:5672/$brokervhost 
# Deprecated !
# crudini --set /etc/cinder/cinder.conf DEFAULT rpc_backend rabbit
# crudini --set /etc/cinder/cinder.conf oslo_messaging_rabbit rabbit_host $messagebrokerhost
# crudini --set /etc/cinder/cinder.conf oslo_messaging_rabbit rabbit_password $brokerpass
# crudini --set /etc/cinder/cinder.conf oslo_messaging_rabbit rabbit_userid $brokeruser
# crudini --set /etc/cinder/cinder.conf oslo_messaging_rabbit rabbit_port 5672
# crudini --set /etc/cinder/cinder.conf oslo_messaging_rabbit rabbit_use_ssl false
# crudini --set /etc/cinder/cinder.conf oslo_messaging_rabbit rabbit_virtual_host $brokervhost
# crudini --set /etc/cinder/cinder.conf oslo_messaging_rabbit rabbit_max_retries 0
# crudini --set /etc/cinder/cinder.conf oslo_messaging_rabbit rabbit_retry_interval 1
# crudini --set /etc/cinder/cinder.conf oslo_messaging_rabbit rabbit_ha_queues false
 
crudini --set /etc/cinder/cinder.conf DEFAULT log_dir /var/log/cinder
crudini --set /etc/cinder/cinder.conf DEFAULT state_path /var/lib/cinder
crudini --set /etc/cinder/cinder.conf DEFAULT volumes_dir /var/lib/cinder/volumes/
crudini --set /etc/cinder/cinder.conf DEFAULT rootwrap_config /etc/cinder/rootwrap.conf
crudini --set /etc/cinder/cinder.conf DEFAULT default_volume_type $default_volume_type
crudini --set /etc/cinder/cinder.conf DEFAULT glance_api_servers http://$glancehost:9292

crudini --set /etc/cinder/cinder.conf DEFAULT enabled_backends ""

#
# The following section sets the possible cinder backends actually supported by this installer
# By the moment, we can configure lvm, glusterfs and nfs
#
# Note that, because you can have multiple storage nodes with the same storage backends, our
# installe appends to both the configs and backend names the IP of the host (variable
# "cindernodehost") so you can have multiple lvm's, multiple nfs's and multiple glusterfs's
# in your storage network.
# Also, you can just not enable any storage backend in our installer if you prefer to manually
# configure them later.
#

#
# Cinder GlusterFS support was available up to Newton (but in deprecated state)
# It has been removed competelly from Ocata
#

if [ $cindernodetype == "allinone" ] || [ $cindernodetype == "storage" ]
then
	if [ $cinderconfiglvm == "yes" ]
	then
		crudini --set /etc/cinder/cinder.conf DEFAULT enabled_backends lvm-$cindernodehost
		crudini --set /etc/cinder/cinder.conf lvm-$cindernodehost volume_group $cinderlvmname
		crudini --set /etc/cinder/cinder.conf lvm-$cindernodehost volume_driver "cinder.volume.drivers.lvm.LVMVolumeDriver"
		crudini --set /etc/cinder/cinder.conf lvm-$cindernodehost iscsi_protocol iscsi
		crudini --set /etc/cinder/cinder.conf lvm-$cindernodehost iscsi_helper tgtadm
		crudini --set /etc/cinder/cinder.conf lvm-$cindernodehost iscsi_ip_address $cinder_iscsi_ip_address
		crudini --set /etc/cinder/cinder.conf lvm-$cindernodehost volume_backend_name LVM_iSCSI-$cindernodehost
	fi

	#if [ $cinderconfigglusterfs == "yes" ]
	#then
	#	# crudini --set /etc/cinder/cinder.conf glusterfs-$cindernodehost volume_driver "cinder.volume.drivers.glusterfs.GlusterfsDriver"
	#	# crudini --set /etc/cinder/cinder.conf glusterfs-$cindernodehost glusterfs_shares_config "/etc/cinder/glusterfs_shares"
	#	# crudini --set /etc/cinder/cinder.conf glusterfs-$cindernodehost glusterfs_mount_point_base "/var/lib/cinder/glusterfs"
	#	# crudini --set /etc/cinder/cinder.conf glusterfs-$cindernodehost nas_volume_prov_type thin
	#	# crudini --set /etc/cinder/cinder.conf glusterfs-$cindernodehost glusterfs_disk_util df
	#	# crudini --set /etc/cinder/cinder.conf glusterfs-$cindernodehost glusterfs_qcow2_volumes True
	#	# crudini --set /etc/cinder/cinder.conf glusterfs-$cindernodehost volume_backend_name GLUSTERFS-$cindernodehost
	#	# echo $glusterfsresource > /etc/cinder/glusterfs_shares
	#	# chown cinder.cinder /etc/cinder/glusterfs_shares
	#fi

	if [ $cinderconfignfs == "yes" ]
	then
		crudini --set /etc/cinder/cinder.conf nfs-$cindernodehost volume_driver "cinder.volume.drivers.nfs.NfsDriver"
		crudini --set /etc/cinder/cinder.conf nfs-$cindernodehost nfs_shares_config "/etc/cinder/nfs_shares"
		crudini --set /etc/cinder/cinder.conf nfs-$cindernodehost nfs_mount_point_base "/var/lib/cinder/nfs"
		crudini --set /etc/cinder/cinder.conf nfs-$cindernodehost nsf_disk_util df
		crudini --set /etc/cinder/cinder.conf nfs-$cindernodehost nfs_sparsed_volumes True
		crudini --set /etc/cinder/cinder.conf nfs-$cindernodehost nfs_mount_options $nfs_mount_options
		crudini --set /etc/cinder/cinder.conf nfs-$cindernodehost volume_backend_name NFS-$cindernodehost
		crudini --set /etc/cinder/cinder.conf nfs-$cindernodehost nfs_qcow2_volumes True
		crudini --set /etc/cinder/cinder.conf nfs-$cindernodehost nfs_snapshot_support True
		crudini --set /etc/cinder/cinder.conf nfs-$cindernodehost nas_secure_file_operations false
		crudini --set /etc/cinder/cinder.conf DEFAULT nas_secure_file_operations false
		echo $nfsresource > /etc/cinder/nfs_shares
		chown cinder.cinder /etc/cinder/nfs_shares
	fi

	backend=""
	prevgluster=""

	crudini --set /etc/cinder/cinder.conf DEFAULT enabled_backends ""

	if [ $cinderconfiglvm == "yes" ]
	then
		prevlvm="lvm-$cindernodehost"
		backend="lvm-$cindernodehost"
		seplvm=","
	else
		seplvm=""
		prevlvm=""
	fi

	if [ $cinderconfignfs == "yes" ]
	then
		prevnfs="nfs-$cindernodehost"
		sepnfs=","
		backend="$prevlvm$seplvm$prevnfs"
	else
		sepnfs=""
		prenfs=""
	fi

	#if [ $cinderconfigglusterfs == "yes" ]
	#then
	#	# prevgluster="glusterfs-$cindernodehost"
	#	# backend="$prevlvm$seplvm$prevnfs$sepnfs$prevgluster"
	#	prevgluster=""
	#else
	#	prevgluster=""
	#fi

	crudini --set /etc/cinder/cinder.conf DEFAULT enabled_backends "$backend"
fi
 
case $dbflavor in
"mysql")
	crudini --set /etc/cinder/cinder.conf database connection mysql+pymysql://$cinderdbuser:$cinderdbpass@$dbbackendhost:$mysqldbport/$cinderdbname
	;;
"postgres")
	crudini --set /etc/cinder/cinder.conf database connection postgresql+psycopg2://$cinderdbuser:$cinderdbpass@$dbbackendhost:$psqldbport/$cinderdbname
	;;
esac
 
crudini --set /etc/cinder/cinder.conf database retry_interval 10
crudini --set /etc/cinder/cinder.conf database idle_timeout 3600
crudini --set /etc/cinder/cinder.conf database min_pool_size 1
crudini --set /etc/cinder/cinder.conf database max_pool_size 10
crudini --set /etc/cinder/cinder.conf database max_retries 100
crudini --set /etc/cinder/cinder.conf database pool_timeout 10 
 
crudini --set /etc/cinder/cinder.conf keystone_authtoken auth_uri http://$keystonehost:5000
crudini --set /etc/cinder/cinder.conf keystone_authtoken auth_url http://$keystonehost:35357
crudini --set /etc/cinder/cinder.conf keystone_authtoken auth_type password
crudini --set /etc/cinder/cinder.conf keystone_authtoken memcached_servers $keystonehost:11211
crudini --set /etc/cinder/cinder.conf keystone_authtoken project_domain_name $keystonedomain
crudini --set /etc/cinder/cinder.conf keystone_authtoken user_domain_name $keystonedomain
crudini --set /etc/cinder/cinder.conf keystone_authtoken project_name $keystoneservicestenant
crudini --set /etc/cinder/cinder.conf keystone_authtoken username $cinderuser
crudini --set /etc/cinder/cinder.conf keystone_authtoken password $cinderpass
crudini --set /etc/cinder/cinder.conf oslo_concurrency lock_path "/var/oslock/cinder"
 
 
if [ $ceilometerinstall == "yes" ]
then
	crudini --set /etc/cinder/cinder.conf DEFAULT notification_driver messagingv2
	crudini --set /etc/cinder/cinder.conf DEFAULT control_exchange cinder
	crudini --set /etc/cinder/cinder.conf oslo_messaging_notifications driver messagingv2
fi


sync
sleep 2

mkdir -p /var/oslock/cinder
chown -R cinder.cinder /var/oslock/cinder
mkdir -p /var/lib/cinder/volumes
chown -R cinder.cinder /var/lib/cinder/volumes

#
# Some iscsi configuration
#

if [ $cindernodetype == "allinone" ] || [ $cindernodetype == "storage" ]
then
	echo "default-driver iscsi" > /etc/tgt/targets.conf
	echo "include /etc/tgt/conf.d/cinder_tgt.conf" >> /etc/tgt/targets.conf
	echo "include /var/lib/cinder/volumes/*" > /etc/tgt/conf.d/cinder_tgt.conf
	echo "include /etc/cinder/volumes/*" >> /etc/tgt/targets.conf
fi

#
# We proceed to provision/update Cinder Database
#

if [ $cindernodetype == "allinone" ] || [ $cindernodetype == "controller" ]
then
	su cinder -s /bin/sh -c "cinder-manage db sync"
fi

echo ""
echo "Cleaning UP App logs"
 
for mylog in `ls /var/log/cinder/*.log`; do echo "" > $mylog;done
 
echo "Done"
echo ""

echo ""
echo "Starting Cinder"


#
# Then we proceed to start and enable Cinder Services and apply IPTABLES rules.
#

servicelist='
	openstack-cinder-api
	openstack-cinder-scheduler
	openstack-cinder-volume	
'

for myservice in $servicelist
do
	systemctl stop $myservice
	systemctl disable $myservice
done

case $cindernodetype in
"allinone")
	servicelist='
		tgtd
		target
		iscsid
		rpcbind
		openstack-cinder-api
		openstack-cinder-scheduler
		openstack-cinder-volume
	'
	;;
"controller")
	servicelist='
		openstack-cinder-api
		openstack-cinder-scheduler
	'
	;;
"storage")
	servicelist='
		tgtd
		target
		iscsid
		rpcbind
		openstack-cinder-volume	
	'
	;;
esac

for myservice in $servicelist
do
	echo "Starting and Enabling Service: $myservice"
	systemctl start $myservice
	systemctl enable $myservice
	systemctl status $myservice
done


yum -y install python-cinderclient

echo "Ready"

echo ""
echo "Applying IPTABLES rules"

iptables -A INPUT -p tcp -m multiport --dports 3260,8776 -j ACCEPT
service iptables save

#
# Finally, we proceed to verify if Cinder was installed and if not we set a fail so the
# main installer stop further processing.
#
#
# But before that, we setup our backend or backends for this specific nodes
#
if [ $cindernodetype == "allinone" ] || [ $cindernodetype == "storage" ]
then
	if [ $cinderconfiglvm == "yes" ]
	then
		source $keystone_admin_rc_file
		openstack volume type create \
			--property volume_backend_name=LVM_iSCSI-$cindernodehost \
			--description "LVM iSCSI Backend at node $cindernodehost" lvm-$cindernodehost
	fi

	# if [ $cinderconfigglusterfs == "yes" ]
	#then
	#	source $keystone_admin_rc_file
	#	#openstack volume type create \
	#	#	--property volume_backend_name=GLUSTERFS-$cindernodehost \
	#	#	--description "GlusterFS Backend at node $cindernodehost" glusterfs-$cindernodehost
	#fi

	if [ $cinderconfignfs == "yes" ]
	then
		source $keystone_admin_rc_file
		openstack volume type create \
			--property volume_backend_name=NFS-$cindernodehost \
			--description "NFS V3 Backend at node $cindernodehost" nfs-$cindernodehost
	fi
fi


testcinder=`rpm -qi openstack-cinder|grep -ci "is not installed"`
if [ $testcinder == "1" ]
then
	echo ""
	echo "Cinder installation failed. Aborting !"
	echo ""
	exit 0
else
	date > /etc/openstack-control-script-config/cinder-installed
	date > /etc/openstack-control-script-config/cinder
	echo $cindernodetype > /etc/openstack-control-script-config/cinder-nodetype
fi

echo "Ready"

echo ""
echo "Cinder Installed and Configured"
echo ""

