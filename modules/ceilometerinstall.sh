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
	echo "Can't access my configuration file. Aborting"
	echo ""
	exit 0
fi

if [ -f /etc/openstack-control-script-config/db-installed ]
then
	echo ""
	echo "Database Process OK. Let's continue"
	echo ""
else
	echo ""
	echo "Database Process not completed. Aborting"
	echo ""
	exit 0
fi

if [ -f /etc/openstack-control-script-config/keystone-installed ]
then
	echo ""
	echo "Keystone Process OK. Let's continue"
	echo ""
else
	echo ""
	echo "Keystone Process not completed. Aborting"
	echo ""
	exit 0
fi

if [ -f /etc/openstack-control-script-config/ceilometer-installed ]
then
	echo ""
	echo "This module was already completed. Exiting"
	echo ""
	exit 0
fi

#
# Here, depending if we want to install a ceilometer controller or a ceilometer
# in a compute node, we install the proper packages for the selection
#

echo ""
echo "Installing Ceilometer Packages"

if [ $ceilometer_in_compute_node == "no" ]
then
	echo ""
	echo "ALL-IN-ONE or Controller Packages"
	echo ""
	yum install -y openstack-ceilometer-central \
		openstack-ceilometer-collector \
		openstack-ceilometer-common \
		openstack-ceilometer-compute \
		openstack-ceilometer-notification \
		python-ceilometerclient \
		python-ceilometer \
		python-ceilometerclient-doc \
		openstack-utils \
		openstack-selinux

	echo ""
	echo "Gnocchi packages (ALL-IN-ONE of Controller Packages)"
	echo ""
	yum install -y openstack-gnocchi-api \
		openstack-gnocchi-common \
		openstack-gnocchi-indexer-sqlalchemy \
		openstack-gnocchi-metricd \
		openstack-gnocchi-statsd \
		python2-gnocchiclient

	yum install -y mod_wsgi memcached python-memcached httpd

	if [ $ceilometeralarms == "yes" ]
	then
		yum install -y openstack-aodh-api \
			openstack-aodh-evaluator \
			openstack-aodh-notifier \
			openstack-aodh-listener \
			openstack-aodh-expirer \
			python-ceilometerclient \
			python2-aodhclient

	fi
else
	echo ""
	echo "Compute Node Packages"
	echo ""
	yum install -y openstack-utils \
		openstack-selinux \
		openstack-ceilometer-compute \
		python-ceilometerclient \
		python-pecan
fi

#
# FIX for ceilometer missing awsauth module - not currently on EPEL or RDO repos
# We proceed to install it using pip
#
yum -y install python-pip
pip install requests-aws

echo "Done"
echo ""

source $keystone_admin_rc_file

#
# Kiss bye bye mongo !. We are now using GNOCCHI !!
#

# if [ $ceilometer_in_compute_node = "no" ]
# then
#	echo ""
#	echo "Installing and Configuring MongoDB Database Backend"
#	echo ""
#
#	yum -y install mongodb-server mongodb
#	sed -i '/--smallfiles/!s/OPTIONS=\"/OPTIONS=\"--smallfiles /' /etc/sysconfig/mongod
#	sed -i "s/127.0.0.1/$mondbhost/g" /etc/mongod.conf
#	sed -i "s/27017/$mondbport/g" /etc/mongod.conf
#
#	service mongod start
#	chkconfig mongod on
#	service mongod status
#	echo ""
#	echo "Waiting 10 seconds...:"
#	sleep 10
#
#	mongo --host $mondbhost --eval "db = db.getSiblingDB(\"$mondbname\");db.createUser({user: \"$mondbuser\",pwd: \"$mondbpass\",roles: [ \"readWrite\", \"dbAdmin\" ]})"
#
#	sync
#	sleep 5
#	sync
#fi

echo ""
echo "Configuring Ceilometer"
echo ""

#
# Using python based tools, we proceed to configure ceilometer
#

echo "#" >> /etc/ceilometer/ceilometer.conf

#
# Using python based tools, we proceed to configure ceilometer
#

#
# Keystone Authentication
#
crudini --set /etc/ceilometer/ceilometer.conf keystone_authtoken admin_tenant_name $keystoneservicestenant
crudini --set /etc/ceilometer/ceilometer.conf keystone_authtoken admin_user $ceilometeruser
crudini --set /etc/ceilometer/ceilometer.conf keystone_authtoken admin_password $ceilometerpass
crudini --set /etc/ceilometer/ceilometer.conf keystone_authtoken auth_type password
crudini --set /etc/ceilometer/ceilometer.conf keystone_authtoken username $ceilometeruser
crudini --set /etc/ceilometer/ceilometer.conf keystone_authtoken password $ceilometerpass
crudini --set /etc/ceilometer/ceilometer.conf keystone_authtoken project_domain_name $keystonedomain
crudini --set /etc/ceilometer/ceilometer.conf keystone_authtoken user_domain_name $keystonedomain
crudini --set /etc/ceilometer/ceilometer.conf keystone_authtoken project_name $keystoneservicestenant
crudini --set /etc/ceilometer/ceilometer.conf keystone_authtoken auth_uri http://$keystonehost:5000
crudini --set /etc/ceilometer/ceilometer.conf keystone_authtoken auth_url http://$keystonehost:35357
crudini --set /etc/ceilometer/ceilometer.conf keystone_authtoken signing_dir "/var/lib/ceilometer/tmp-signing"
crudini --set /etc/ceilometer/ceilometer.conf keystone_authtoken auth_version v3
crudini --set /etc/ceilometer/ceilometer.conf keystone_authtoken memcached_servers $keystonehost:11211
crudini --set /etc/ceilometer/ceilometer.conf service_credentials os_username $ceilometeruser
crudini --set /etc/ceilometer/ceilometer.conf service_credentials os_password $ceilometerpass
crudini --set /etc/ceilometer/ceilometer.conf service_credentials os_tenant_name $keystoneservicestenant
crudini --set /etc/ceilometer/ceilometer.conf service_credentials os_auth_url http://$keystonehost:5000/v3
crudini --set /etc/ceilometer/ceilometer.conf service_credentials os_region_name $endpointsregion
crudini --set /etc/ceilometer/ceilometer.conf service_credentials os_endpoint_type internalURL
crudini --set /etc/ceilometer/ceilometer.conf service_credentials region_name $endpointsregion
crudini --set /etc/ceilometer/ceilometer.conf service_credentials interface internal
crudini --set /etc/ceilometer/ceilometer.conf service_credentials auth_type password
#
crudini --set /etc/ceilometer/ceilometer.conf service_credentials username $ceilometeruser
crudini --set /etc/ceilometer/ceilometer.conf service_credentials password $ceilometerpass
crudini --set /etc/ceilometer/ceilometer.conf service_credentials auth_url http://$keystonehost:5000/v3
crudini --set /etc/ceilometer/ceilometer.conf service_credentials project_domain_name $keystonedomain
crudini --set /etc/ceilometer/ceilometer.conf service_credentials user_domain_name $keystonedomain
crudini --set /etc/ceilometer/ceilometer.conf service_credentials project_name $keystoneservicestenant
#
# End of Keystone Section
#

 
crudini --set /etc/ceilometer/ceilometer.conf DEFAULT metering_api_port 8777
crudini --set /etc/ceilometer/ceilometer.conf DEFAULT auth_strategy keystone
crudini --set /etc/ceilometer/ceilometer.conf DEFAULT log_dir /var/log/ceilometer
crudini --set /etc/ceilometer/ceilometer.conf DEFAULT host `hostname`
crudini --set /etc/ceilometer/ceilometer.conf DEFAULT pipeline_cfg_file pipeline.yaml
crudini --set /etc/ceilometer/ceilometer.conf collector workers 2
crudini --set /etc/ceilometer/ceilometer.conf notification workers 2
crudini --set /etc/ceilometer/ceilometer.conf DEFAULT hypervisor_inspector libvirt
 
crudini --del /etc/ceilometer/ceilometer.conf DEFAULT sql_connection > /dev/null 2>&1
crudini --del /etc/ceilometer/ceilometer.conf DEFAULT sql_connection > /dev/null 2>&1
 
crudini --set /etc/ceilometer/ceilometer.conf DEFAULT nova_control_exchange nova
crudini --set /etc/ceilometer/ceilometer.conf DEFAULT glance_control_exchange glance
crudini --set /etc/ceilometer/ceilometer.conf DEFAULT neutron_control_exchange neutron
crudini --set /etc/ceilometer/ceilometer.conf DEFAULT cinder_control_exchange cinder
 
crudini --set /etc/ceilometer/ceilometer.conf publisher telemetry_secret $metering_secret

kvm_possible=`grep -E 'svm|vmx' /proc/cpuinfo|uniq|wc -l`

if [ $forceqemu == "yes" ]
then
        kvm_possible="0"
fi

if [ $kvm_possible == "0" ]
then
	crudini --set /etc/ceilometer/ceilometer.conf DEFAULT libvirt_type qemu
else
	crudini --set /etc/ceilometer/ceilometer.conf DEFAULT libvirt_type kvm
fi

crudini --set /etc/ceilometer/ceilometer.conf DEFAULT debug false
# Gnocchi instead of MongoDB
# crudini --set /etc/ceilometer/ceilometer.conf database connection "mongodb://$mondbuser:$mondbpass@$mondbhost:$mondbport/$mondbname"
crudini --set /etc/ceilometer/ceilometer.conf database metering_time_to_live $mongodbttl
crudini --set /etc/ceilometer/ceilometer.conf database time_to_live $mongodbttl
crudini --set /etc/ceilometer/ceilometer.conf database event_time_to_live $mongodbttl

crudini --set /etc/ceilometer/ceilometer.conf DEFAULT notification_topics notifications

# Goodbye MongoDB
# crudini --set /etc/ceilometer/ceilometer.conf DEFAULT dispatcher database
# crudini --set /etc/ceilometer/ceilometer.conf DEFAULT meter_dispatchers database
# crudini --set /etc/ceilometer/ceilometer.conf DEFAULT event_dispatchers database
#
# Hello Gnocchi !!
# crudini --set /etc/ceilometer/ceilometer.conf DEFAULT dispatcher gnocchi
crudini --set /etc/ceilometer/ceilometer.conf DEFAULT meter_dispatchers gnocchi
crudini --set /etc/ceilometer/ceilometer.conf DEFAULT event_dispatchers gnocchi
#

crudini --set /etc/ceilometer/ceilometer.conf DEFAULT transport_url rabbit://$brokeruser:$brokerpass@$messagebrokerhost:5672/$brokervhost 
# crudini --set /etc/ceilometer/ceilometer.conf DEFAULT rpc_backend rabbit
# crudini --set /etc/ceilometer/ceilometer.conf oslo_messaging_rabbit rabbit_host $messagebrokerhost
# crudini --set /etc/ceilometer/ceilometer.conf oslo_messaging_rabbit rabbit_password $brokerpass
# crudini --set /etc/ceilometer/ceilometer.conf oslo_messaging_rabbit rabbit_userid $brokeruser
# crudini --set /etc/ceilometer/ceilometer.conf oslo_messaging_rabbit rabbit_port 5672
# crudini --set /etc/ceilometer/ceilometer.conf oslo_messaging_rabbit rabbit_use_ssl false
# crudini --set /etc/ceilometer/ceilometer.conf oslo_messaging_rabbit rabbit_virtual_host $brokervhost
# crudini --set /etc/ceilometer/ceilometer.conf oslo_messaging_rabbit rabbit_max_retries 0
# crudini --set /etc/ceilometer/ceilometer.conf oslo_messaging_rabbit rabbit_retry_interval 1
# crudini --set /etc/ceilometer/ceilometer.conf oslo_messaging_rabbit rabbit_ha_queues false

crudini --set /etc/ceilometer/ceilometer.conf notification messaging_urls rabbit://$brokeruser:$brokerpass@$messagebrokerhost:5672/$brokervhost
 
crudini --set /etc/ceilometer/ceilometer.conf alarm evaluation_service ceilometer.alarm.service.SingletonAlarmService
crudini --set /etc/ceilometer/ceilometer.conf alarm partition_rpc_topic alarm_partition_coordination

crudini --set /etc/ceilometer/ceilometer.conf api port 8777
crudini --set /etc/ceilometer/ceilometer.conf api host 0.0.0.0
 
crudini --set /etc/ceilometer/ceilometer.conf DEFAULT heat_control_exchange heat
crudini --set /etc/ceilometer/ceilometer.conf DEFAULT control_exchange ceilometer
crudini --set /etc/ceilometer/ceilometer.conf DEFAULT http_control_exchanges nova
sed -r -i 's/http_control_exchanges\ =\ nova/http_control_exchanges\ =\ nova\nhttp_control_exchanges\ =\ glance\nhttp_control_exchanges\ =\ cinder\nhttp_control_exchanges\ =\ neutron\n/' /etc/ceilometer/ceilometer.conf
 
crudini --set /etc/ceilometer/ceilometer.conf DEFAULT instance_name_template $instance_name_template
crudini --set /etc/ceilometer/ceilometer.conf service_types neutron network
crudini --set /etc/ceilometer/ceilometer.conf service_types nova compute
crudini --set /etc/ceilometer/ceilometer.conf service_types swift object-store
crudini --set /etc/ceilometer/ceilometer.conf service_types glance image
crudini --del /etc/ceilometer/ceilometer.conf service_types kwapi
crudini --set /etc/ceilometer/ceilometer.conf service_types neutron_lbaas_version v2

crudini --set /etc/ceilometer/ceilometer.conf oslo_messaging_notifications topics notifications
crudini --set /etc/ceilometer/ceilometer.conf oslo_messaging_notifications driver messagingv2
crudini --set /etc/ceilometer/ceilometer.conf exchange_control heat_control_exchange heat
crudini --set /etc/ceilometer/ceilometer.conf exchange_control glance_control_exchange glance
crudini --set /etc/ceilometer/ceilometer.conf exchange_control keystone_control_exchange keystone
crudini --set /etc/ceilometer/ceilometer.conf exchange_control cinder_control_exchange cinder
crudini --set /etc/ceilometer/ceilometer.conf exchange_control sahara_control_exchange sahara
crudini --set /etc/ceilometer/ceilometer.conf exchange_control swift_control_exchange swift
crudini --set /etc/ceilometer/ceilometer.conf exchange_control magnum_control_exchange magnum
crudini --set /etc/ceilometer/ceilometer.conf exchange_control trove_control_exchange trove
crudini --set /etc/ceilometer/ceilometer.conf exchange_control nova_control_exchange nova
crudini --set /etc/ceilometer/ceilometer.conf exchange_control neutron_control_exchange neutron
crudini --set /etc/ceilometer/ceilometer.conf publisher_notifier telemetry_driver messagingv2
crudini --set /etc/ceilometer/ceilometer.conf publisher_notifier metering_topic metering
crudini --set /etc/ceilometer/ceilometer.conf publisher_notifier event_topic event

#
# If this is NOT a compute node, and we are installing swift, then we reconfigure it
# so it can report to ceilometer too
#

if [ $ceilometer_in_compute_node == "no" ]
then
	if [ $swiftinstall == "yes" ] && [ $swiftmetrics == "yes" ]
	then
		yum -y install python-ceilometermiddleware
                crudini --set /etc/swift/proxy-server.conf filter:keystoneauth operator_roles "$keystoneadmintenant,$keystoneuserrole,$keystonereselleradminrole"
                crudini --set /etc/swift/proxy-server.conf pipeline:main pipeline "ceilometer catch_errors gatekeeper healthcheck proxy-logging cache container_sync bulk ratelimit authtoken keystoneauth container-quotas account-quotas slo dlo versioned_writes proxy-logging proxy-server"
                crudini --set /etc/swift/proxy-server.conf filter:ceilometer paste.filter_factory ceilometermiddleware.swift:filter_factory
                crudini --set /etc/swift/proxy-server.conf filter:ceilometer control_exchange swift
                crudini --set /etc/swift/proxy-server.conf filter:ceilometer driver messagingv2
                crudini --set /etc/swift/proxy-server.conf filter:ceilometer topic notifications
                crudini --set /etc/swift/proxy-server.conf filter:ceilometer log_level WARN
		crudini --set /etc/swift/proxy-server.conf filter:ceilometer url rabbit://$brokeruser:$brokerpass@$messagebrokerhost:5672/$brokervhost
	        touch /var/log/ceilometer/swift-proxy-server.log
	        chown swift.swift /var/log/ceilometer/swift-proxy-server.log
	        usermod -a -G ceilometer swift

		service openstack-swift-proxy stop
		service openstack-swift-proxy start
	fi
fi

if [ $ceilometer_in_compute_node == "no" ]
then
	# yum -y install memcached python-memcached
	yum -y install mod_wsgi memcached python-memcached httpd
	# cp -v ./libs/ceilometer/wsgi-ceilometer.conf /etc/httpd/conf.d/
	# mkdir -p /var/www/cgi-bin/ceilometer
	# cp -v ./libs/ceilometer/app.wsgi /var/www/cgi-bin/ceilometer/app.wsgi
	cat ./libs/memcached/memcached > /etc/sysconfig/memcached
	systemctl stop memcached
	systemctl start memcached
	systemctl enable memcached
	systemctl enable httpd
	systemctl stop httpd
	sleep 5
	systemctl start httpd
	sleep 5
fi

#
# Customized api_paste for Ocata
#

if [ $ceilometer_in_compute_node == "no" ]
then
	cat ./libs/ceilometer/api_paste.ini > /etc/ceilometer/api_paste.ini
fi

#
# Ceilometer User need to be part of nova and qemu/kvm/libvirt groups
#

usermod -a -G libvirt,nova,kvm,qemu ceilometer > /dev/null 2>&1

mkdir -p /var/lib/ceilometer/tmp-signing
chown ceilometer.ceilometer /var/lib/ceilometer/tmp-signing
chmod 700 /var/lib/ceilometer/tmp-signing

#if [ $ceilometer_in_compute_node == "no" ]
#then
#	ceilometer-dbsync --config-dir /etc/ceilometer/
#fi

chown ceilometer.ceilometer /var/log/ceilometer/*

#
# With Ceilometer ready, now we proceed to configure aodh
#

if [ $ceilometer_in_compute_node == "no" ]
then
	if [ $ceilometeralarms == "yes" ]
	then
		echo "#" >> /etc/aodh/aodh.conf
		echo "#" >> /etc/aodh/api_paste.ini
		crudini --set /etc/aodh/aodh.conf DEFAULT debug false
		case $dbflavor in
		"mysql")
			crudini --set /etc/aodh/aodh.conf database connection mysql+pymysql://$aodhdbuser:$aodhdbpass@$dbbackendhost:$mysqldbport/$aodhdbname
			;;
		"postgres")
			crudini --set /etc/aodh/aodh.conf database connection postgresql://$aodhdbuser:$aodhdbpass@$dbbackendhost:$psqldbport/$aodhdbname
			;;
		esac
		#
		cat ./libs/aodh/api_paste.ini > /etc/aodh/api_paste.ini
		crudini --set /etc/aodh/aodh.conf DEFAULT auth_strategy keystone
		crudini --set /etc/aodh/aodh.conf DEFAULT host `hostname`
		crudini --set /etc/aodh/aodh.conf DEFAULT memcached_servers $keystonehost:11211
		crudini --set /etc/aodh/api_paste.ini "filter:authtoken" oslo_config_project aodh
		crudini --set /etc/aodh/aodh.conf keystone_authtoken admin_tenant_name $keystoneservicestenant
		crudini --set /etc/aodh/aodh.conf keystone_authtoken admin_user $aodhuser
		crudini --set /etc/aodh/aodh.conf keystone_authtoken admin_password $aodhpass
		crudini --set /etc/aodh/aodh.conf keystone_authtoken auth_type password
		crudini --set /etc/aodh/aodh.conf keystone_authtoken username $aodhuser
		crudini --set /etc/aodh/aodh.conf keystone_authtoken password $aodhpass
		crudini --set /etc/aodh/aodh.conf keystone_authtoken project_domain_name $keystonedomain
		crudini --set /etc/aodh/aodh.conf keystone_authtoken user_domain_name $keystonedomain
		crudini --set /etc/aodh/aodh.conf keystone_authtoken project_name $keystoneservicestenant
		crudini --set /etc/aodh/aodh.conf keystone_authtoken auth_uri http://$keystonehost:5000
		crudini --set /etc/aodh/aodh.conf keystone_authtoken auth_url http://$keystonehost:35357
		crudini --set /etc/aodh/aodh.conf keystone_authtoken signing_dir "/var/lib/aodh/tmp-signing"
		crudini --set /etc/aodh/aodh.conf keystone_authtoken auth_version v3
		crudini --set /etc/aodh/aodh.conf keystone_authtoken memcached_servers $keystonehost:11211
		crudini --set /etc/aodh/aodh.conf service_credentials region_name $endpointsregion
		crudini --set /etc/aodh/aodh.conf service_credentials interface internal
		crudini --set /etc/aodh/aodh.conf service_credentials auth_type password
		crudini --set /etc/aodh/aodh.conf service_credentials username $aodhuser
		crudini --set /etc/aodh/aodh.conf service_credentials password $aodhpass
		crudini --set /etc/aodh/aodh.conf service_credentials auth_url http://$keystonehost:5000/v3
		crudini --set /etc/aodh/aodh.conf service_credentials project_domain_name $keystonedomain
		crudini --set /etc/aodh/aodh.conf service_credentials user_domain_name $keystonedomain
		crudini --set /etc/aodh/aodh.conf service_credentials project_name $keystoneservicestenant
		crudini --set /etc/aodh/aodh.conf api port 8042
		crudini --set /etc/aodh/aodh.conf api host 0.0.0.0
		crudini --set /etc/aodh/aodh.conf api paste_config api_paste.ini
		crudini --set /etc/aodh/aodh.conf DEFAULT transport_url rabbit://$brokeruser:$brokerpass@$messagebrokerhost:5672/$brokervhost
		crudini --set /etc/aodh/aodh.conf DEFAULT rpc_backend rabbit
		crudini --set /etc/aodh/aodh.conf oslo_messaging_rabbit rabbit_host $messagebrokerhost
		crudini --set /etc/aodh/aodh.conf oslo_messaging_rabbit rabbit_password $brokerpass
		crudini --set /etc/aodh/aodh.conf oslo_messaging_rabbit rabbit_userid $brokeruser
		crudini --set /etc/aodh/aodh.conf oslo_messaging_rabbit rabbit_port 5672
		crudini --set /etc/aodh/aodh.conf oslo_messaging_rabbit rabbit_use_ssl false
		crudini --set /etc/aodh/aodh.conf oslo_messaging_rabbit rabbit_virtual_host $brokervhost
		crudini --set /etc/aodh/aodh.conf oslo_messaging_rabbit rabbit_max_retries 0
		crudini --set /etc/aodh/aodh.conf oslo_messaging_rabbit rabbit_retry_interval 1
		crudini --set /etc/aodh/aodh.conf oslo_messaging_rabbit rabbit_ha_queues false
		crudini --set /etc/aodh/aodh.conf oslo_messaging_notifications driver messagingv2
		crudini --set /etc/aodh/aodh.conf oslo_messaging_notifications topics notifications


                mkdir -p /var/lib/aodh/tmp-signing
                chown aodh.aodh /var/lib/aodh/tmp-signing
                chmod 0700 /var/lib/aodh/tmp-signing

                aodh-dbsync --config-dir /etc/aodh/
                chown aodh.aodh /var/log/aodh/*

		yum -y install mod_wsgi memcached python-memcached httpd
		cp -v ./libs/aodh/wsgi-aodh.conf /etc/httpd/conf.d/
		mkdir -p /var/www/cgi-bin/aodh
		cp -v ./libs/aodh/app.wsgi /var/www/cgi-bin/aodh/app.wsgi
		cat ./libs/memcached/memcached > /etc/sysconfig/memcached
		systemctl enable httpd
		systemctl stop memcached
		systemctl start memcached
		systemctl enable memcached
		systemctl stop httpd
		sleep 5
		systemctl start httpd
		sleep 5

	fi	
fi

#
# With all configuration done, we proceed to make IPTABLES changes and start ceilometer services
#

mkdir -p /var/lib/ceilometer/tmp
chown ceilometer.ceilometer /var/lib/ceilometer/tmp

cat ./libs/ceilometer/polling.yaml > /etc/ceilometer/polling.yaml
sed -r -i "s/METRICINTERVAL/$ceilointerval/g" /etc/ceilometer/polling.yaml

# With ceilometer ready, it's time to configure gnocchi

if [ $ceilometer_in_compute_node == "no" ]
then
	if [ ! -f /etc/gnocchi/gnocchi.conf ]
	then
		mkdir -p /etc/gnocchi
		cat ./libs/gnocchi/gnocchi.conf > /etc/gnocchi/gnocchi.conf
		chown gnocchi.gnocchi /etc/gnocchi /etc/gnocchi/*
	fi
	if [ ! -f /etc/gnocchi/policy.json ]
	then
		mkdir -p /etc/gnocchi
		cat ./libs/gnocchi/policy.json > /etc/gnocchi/policy.json
		chown gnocchi.gnocchi /etc/gnocchi /etc/gnocchi/*
	fi
	if [ ! -f /etc/gnocchi/api-paste.ini ]
	then
		mkdir -p /etc/gnocchi
		cat ./libs/gnocchi/api-paste.ini > /etc/gnocchi/api-paste.ini
		chown gnocchi.gnocchi /etc/gnocchi /etc/gnocchi/*
	fi
	if [ ! -f /etc/ceilometer/gnocchi_resources.yaml ]
	then
		cat ./libs/gnocchi/gnocchi_resources.yaml > /etc/ceilometer/gnocchi_resources.yaml
		chown ceilometer.ceilometer /etc/ceilometer/gnocchi_resources.yaml
	fi	
	if [ ! -d /var/log/gnocchi ]
	then
		mkdir -p /var/log/gnocchi
		chown gnocchi.gnocchi /var/log/gnocchi
	fi

	crudini --set /etc/gnocchi/gnocchi.conf DEFAULT debug false
	# crudini --set /etc/gnocchi/gnocchi.conf DEFAULT verbose false
	crudini --set /etc/gnocchi/gnocchi.conf DEFAULT log_file /var/log/gnocchi/gnocchi.log

	crudini --set /etc/gnocchi/gnocchi.conf api host 0.0.0.0
	crudini --set /etc/gnocchi/gnocchi.conf api port 8041
	crudini --set /etc/gnocchi/gnocchi.conf api paste_config /etc/gnocchi/api-paste.ini
	crudini --set /etc/gnocchi/gnocchi.conf api auth_mode keystone

	case $dbflavor in
	"mysql")
		crudini --set /etc/gnocchi/gnocchi.conf database connection "mysql+pymysql://$gnocchidbuser:$gnocchidbpass@$dbbackendhost:$mysqldbport/$gnocchidbname"
		crudini --set /etc/gnocchi/gnocchi.conf indexer url "mysql+pymysql://$gnocchidbuser:$gnocchidbpass@$dbbackendhost:$mysqldbport/$gnocchidbname?charset=utf8"
		;;
	"postgres")
		crudini --set /etc/gnocchi/gnocchi.conf database connection "postgresql+psycopg2://$gnocchidbuser:$gnocchidbpass@$dbbackendhost:$mysqldbport/$gnocchidbname"
		crudini --set /etc/gnocchi/gnocchi.conf indexer url "postgresql+psycopg2://$gnocchidbuser:$gnocchidbpass@$dbbackendhost:$mysqldbport/$gnocchidbname?charset=utf8"
		;;
	esac

	crudini --set /etc/gnocchi/gnocchi.conf keystone_authtoken auth_uri http://$keystonehost:5000/v3
	crudini --set /etc/gnocchi/gnocchi.conf keystone_authtoken auth_url http://$keystonehost:35357/v3
	crudini --set /etc/gnocchi/gnocchi.conf keystone_authtoken auth_type password
	crudini --set /etc/gnocchi/gnocchi.conf keystone_authtoken memcached_servers $keystonehost:11211
	crudini --set /etc/gnocchi/gnocchi.conf keystone_authtoken project_domain_name $keystonedomain
	crudini --set /etc/gnocchi/gnocchi.conf keystone_authtoken user_domain_name $keystonedomain
	crudini --set /etc/gnocchi/gnocchi.conf keystone_authtoken project_name $keystoneservicestenant
	crudini --set /etc/gnocchi/gnocchi.conf keystone_authtoken username $gnocchiuser
	crudini --set /etc/gnocchi/gnocchi.conf keystone_authtoken password $gnocchipass
	crudini --set /etc/gnocchi/gnocchi.conf keystone_authtoken interface internalURL
	crudini --set /etc/gnocchi/gnocchi.conf keystone_authtoken region_name $endpointsregion
	crudini --set /etc/gnocchi/gnocchi.conf service_credentials auth_uri http://$keystonehost:5000/v3
	crudini --set /etc/gnocchi/gnocchi.conf service_credentials auth_url http://$keystonehost:35357/v3
	crudini --set /etc/gnocchi/gnocchi.conf service_credentials auth_type password
	crudini --set /etc/gnocchi/gnocchi.conf service_credentials memcached_servers $keystonehost:11211
	crudini --set /etc/gnocchi/gnocchi.conf service_credentials project_domain_name $keystonedomain
	crudini --set /etc/gnocchi/gnocchi.conf service_credentials user_domain_name $keystonedomain
	crudini --set /etc/gnocchi/gnocchi.conf service_credentials project_name $keystoneservicestenant
	crudini --set /etc/gnocchi/gnocchi.conf service_credentials username $gnocchiuser
	crudini --set /etc/gnocchi/gnocchi.conf service_credentials password $gnocchipass
	crudini --set /etc/gnocchi/gnocchi.conf service_credentials interface internalURL
	crudini --set /etc/gnocchi/gnocchi.conf service_credentials region_name $endpointsregion

	crudini --set /etc/gnocchi/gnocchi.conf storage driver file
	crudini --set /etc/gnocchi/gnocchi.conf storage file_basepath "/var/lib/gnocchi"
	crudini --set /etc/gnocchi/gnocchi.conf storage coordination_url "file:///var/lib/gnocchi/locks"

	crudini --set /etc/gnocchi/gnocchi.conf indexer driver sqlalchemy
	crudini --set /etc/gnocchi/gnocchi.conf archive_policy default_aggregation_methods "mean,min,max,sum,std,median,count,last,95pct"

	# crudini --set /etc/gnocchi/api-paste.ini "pipeline:main" pipeline "gnocchi+auth"

	su gnocchi -s /bin/sh -c "gnocchi-upgrade --config-file /etc/gnocchi/gnocchi.conf --create-legacy-resource-types"

	systemctl stop openstack-gnocchi-api
	systemctl disable openstack-gnocchi-api

	cp -v ./libs/gnocchi/wsgi-gnocchi.conf /etc/httpd/conf.d/
	mkdir -p /var/www/cgi-bin/gnocchi
	cp -v ./libs/gnocchi/app.wsgi /var/www/cgi-bin/gnocchi/app.wsgi
	systemctl enable httpd
	systemctl stop httpd
	sleep 5
	systemctl start httpd
	sleep 5

	systemctl start openstack-gnocchi-metricd
	systemctl enable openstack-gnocchi-metricd

	sleep 5

	source $keystone_fulladmin_rc_file

	# gnocchi archive-policy create -d granularity:5m,points:12 -d granularity:1h,points:24 -d granularity:1d,points:30 low
	# gnocchi archive-policy create -d granularity:60s,points:60 -d granularity:1h,points:168 -d granularity:1d,points:365 medium
	# gnocchi archive-policy create -d granularity:1s,points:86400 -d granularity:1m,points:43200 -d granularity:1h,points:8760 high
	# gnocchi archive-policy-rule create -a low -m "*" default

	cat /etc/ceilometer/ceilometer.conf |grep -v _dispatchers > /etc/ceilometer/ceilometer.conf.TEMP
	cat /etc/ceilometer/ceilometer.conf.TEMP > /etc/ceilometer/ceilometer.conf
	rm -f /etc/ceilometer/ceilometer.conf.TEMP

	crudini --set /etc/ceilometer/ceilometer.conf DEFAULT dispatcher gnocchi
	crudini --set /etc/ceilometer/ceilometer.conf DEFAULT meter_dispatchers gnocchi
	crudini --set /etc/ceilometer/ceilometer.conf DEFAULT event_dispatchers gnocchi
	crudini --set /etc/ceilometer/ceilometer.conf dispatcher_gnocchi url http://$gnocchihost:8041
	crudini --set /etc/ceilometer/ceilometer.conf dispatcher_gnocchi filter_service_activity False
	crudini --set /etc/ceilometer/ceilometer.conf dispatcher_gnocchi archive_policy low
	crudini --set /etc/ceilometer/ceilometer.conf dispatcher_gnocchi resources_definition_file gnocchi_resources.yaml
	# crudini --set /etc/ceilometer/ceilometer.conf notification store_events false
fi

# Time to add ceilometer resources to gnocchi
if [ $ceilometer_in_compute_node == "no" ]
then
	ceilometer-upgrade --skip-metering-database
fi

echo ""
echo "Applying IPTABLES Rules"

iptables -A INPUT -p tcp -m multiport --dports 8777,8041,8042,$mondbport -j ACCEPT
service iptables save

echo "Ready..."

echo ""
echo "Cleaning UP App logs"
 
for mylog in `ls /var/log/ceilometer/*.log`; do echo "" > $mylog;done
 
echo "Done"
echo ""

echo "Starting Ceilometer Services"
echo ""

if [ $ceilometer_in_compute_node == "no" ]
then
	if [ $ceilometer_without_compute == "no" ]
	then
		systemctl start openstack-ceilometer-compute
		systemctl enable openstack-ceilometer-compute
	else
		systemctl stop openstack-ceilometer-compute
		systemctl disable openstack-ceilometer-compute
	fi

	# systemctl start openstack-gnocchi-api
	systemctl start openstack-gnocchi-metricd
	# systemctl enable openstack-gnocchi-api
	systemctl enable openstack-gnocchi-metricd

	systemctl start openstack-ceilometer-central
	systemctl enable openstack-ceilometer-central

	systemctl disable openstack-ceilometer-api
	systemctl stop openstack-ceilometer-api

	systemctl start openstack-ceilometer-collector
	systemctl enable openstack-ceilometer-collector

	systemctl start openstack-ceilometer-notification
	systemctl enable openstack-ceilometer-notification

	systemctl disable openstack-ceilometer-polling > /dev/null 2>&1
	# systemctl start openstack-ceilometer-polling
	# systemctl enable openstack-ceilometer-polling

	if [ $ceilometeralarms == "yes" ]
	then
		systemctl enable \
			openstack-aodh-evaluator.service \
			openstack-aodh-notifier.service \
			openstack-aodh-listener.service

		systemctl start \
			openstack-aodh-evaluator.service \
			openstack-aodh-notifier.service \
			openstack-aodh-listener.service
	fi

	cp ./libs/ceilometer-expirer.crontab /etc/cron.d/

	systemctl restart crond

	sync
	sleep 2
	sync

else
	systemctl start openstack-ceilometer-compute
	systemctl enable openstack-ceilometer-compute
	# systemctl start openstack-ceilometer-polling
	# systemctl enable openstack-ceilometer-polling
	systemctl disable openstack-ceilometer-polling > /dev/null 2>&1
fi

#
# Finally, we test if our packages are correctly installed, and if not, we set a fail
# variable that makes the installer to stop further processing
#

testceilometer=`rpm -qi openstack-ceilometer-compute|grep -ci "is not installed"`
if [ $testceilometer == "1" ]
then
	echo ""
	echo "Ceilometer Installation FAILED. Aborting !"
	echo ""
	exit 0
else
	date > /etc/openstack-control-script-config/ceilometer-installed
	date > /etc/openstack-control-script-config/ceilometer
	if [ $ceilometeralarms == "yes" ]
	then
		date > /etc/openstack-control-script-config/ceilometer-installed-alarms
	fi
	if [ $ceilometer_in_compute_node == "no" ]
	then
		date > /etc/openstack-control-script-config/ceilometer-full-installed
	fi
	if [ $ceilometer_without_compute == "yes" ]
	then
		if [ $ceilometer_in_compute_node == "no" ]
		then
			date > /etc/openstack-control-script-config/ceilometer-without-compute
		fi
	fi
fi


echo ""
echo "Ceilometer Installed and Configured"
echo ""

