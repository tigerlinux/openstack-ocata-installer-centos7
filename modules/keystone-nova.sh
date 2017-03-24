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
	echo "Can't Access my Config file. Aborting !"
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

if [ -f /etc/openstack-control-script-config/keystone-extra-idents-nova ]
then
	echo ""
	echo "This module was already completed. Exiting !"
	echo ""
	exit 0
fi


source $keystone_fulladmin_rc_file

echo ""
echo "Creating NOVA Identities"
echo ""

echo "Nova User:"
openstack user create --domain $keystonedomain --password $novapass --email $novaemail $novauser

echo "Placement User:"
openstack user create --domain $keystonedomain --password $novaplacementuserpass --email $novaplacementemail $novaplacementuser

echo "Nova Role:"
openstack role add --project $keystoneservicestenant --user $novauser $keystoneadminuser

echo "Placement Role:"
openstack role add --project $keystoneservicestenant --user $novaplacementuser $keystoneadminuser

echo "Nova Service:"
openstack service create \
        --name $novasvce \
        --description "OpenStack Compute" \
        compute

echo "Placement Service:"
openstack service create \
        --name $novaplacementsvce \
        --description "Placement API" \
        placement

echo "Nova Endpoints:"

openstack endpoint create --region $endpointsregion \
	compute public http://$novahost:8774/v2.1/%\(tenant_id\)s

openstack endpoint create --region $endpointsregion \
	compute internal http://$novahost:8774/v2.1/%\(tenant_id\)s

openstack endpoint create --region $endpointsregion \
	compute admin http://$novahost:8774/v2.1/%\(tenant_id\)s

openstack endpoint create --region $endpointsregion \
	placement public http://$novahost:8778

openstack endpoint create --region $endpointsregion \
	placement internal http://$novahost:8778

openstack endpoint create --region $endpointsregion \
	placement admin http://$novahost:8778

date > /etc/openstack-control-script-config/keystone-extra-idents-nova

echo "Ready"

echo ""
echo "NOVA Identities Created"
echo ""

