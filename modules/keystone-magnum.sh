#!/bin/bash
#
# Unattended/SemiAutomatted OpenStack Installer
# Reynaldo R. Martinez P.
# E-Mail: TigerLinux@Gmail.com
# OpenStack OCATA for Centos 7
#
#

PATH=$PATH:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin

if [ -f ./configs/main-config.rc ]
then
	source ./configs/main-config.rc
	mkdir -p /etc/openstack-control-script-config
else
	echo "Can't Access my config file. Aborting !"
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

if [ -f /etc/openstack-control-script-config/keystone-extra-idents-magnum ]
then
	echo ""
	echo "This module was already completed. Exiting !"
	echo ""
	exit 0
fi

source $keystone_fulladmin_rc_file

echo ""
echo "Creating MAGNUM Identities"
echo ""

echo "Magnum User:"
openstack user create --domain $keystonedomain --password $magnumpass --email $magnumemail $magnumuser

echo "Magnum Role:"
openstack role add --project $keystoneservicestenant --user $magnumuser $keystoneadminuser


echo "Magnum Services:"

openstack service create \
        --name $magnumsvce \
        --description "OpenStack Container Infrastructure Management Service" \
        container-infra


echo "Magnum Domain:"

openstack domain create --description "Owns users and projects created by magnum" $magnum_domain_name

echo "Magnum Domain User:"

openstack user create --domain $magnum_domain_name --password $magnum_domain_admin_password $magnum_domain_admin

echo "Assigning Role:"

openstack role add --domain $magnum_domain_name --user $magnum_domain_admin $keystoneadminuser

echo "Magnum Endpoints:"


openstack endpoint create --region $endpointsregion \
	container-infra public http://$magnumhost:9511/v1

openstack endpoint create --region $endpointsregion \
	container-infra internal http://$magnumhost:9511/v1

openstack endpoint create --region $endpointsregion \
	container-infra admin http://$magnumhost:9511/v1



date > /etc/openstack-control-script-config/keystone-extra-idents-magnum

echo "Ready"

echo ""
echo "Magnum Identities Ready"
echo ""

