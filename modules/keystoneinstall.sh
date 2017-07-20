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
	echo "This module was already completed. Exiting !"
	echo ""
	exit 0
fi

#
# If we are not going to install Keystone, we proceed to create the environment
# file, declare success of the installation script, and exit this module
#

if [ $keystoneinstall == "no" ]
then
	OS_URL="http://$keystonehost:35357/v3"
	OS_USERNAME=$keystoneadminuser
	OS_TENANT_NAME=$keystoneadminuser
	OS_PROJECT_NAME=$keystoneadminuser
	OS_PASSWORD=$keystoneadminpass
	OS_AUTH_URL="http://$keystonehost:5000/v3"
	OS_VOLUME_API_VERSION=2
	OS_PROJECT_DOMAIN_NAME=$keystonedomain
	OS_USER_DOMAIN_NAME=$keystonedomain
	OS_IDENTITY_API_VERSION=3

	echo "export OS_USERNAME=$OS_USERNAME" >> $keystone_admin_rc_file
	echo "export OS_PASSWORD=$OS_PASSWORD" >> $keystone_admin_rc_file
	echo "export OS_PROJECT_NAME=$OS_TENANT_NAME" >> $keystone_admin_rc_file
	echo "export OS_AUTH_URL=$OS_AUTH_URL" >> $keystone_admin_rc_file
	echo "export OS_VOLUME_API_VERSION=2" >> $keystone_admin_rc_file
	echo "export OS_IDENTITY_API_VERSION=3" >> $keystone_admin_rc_file
	echo "export OS_PROJECT_DOMAIN_NAME=$keystonedomain" >> $keystone_admin_rc_file
	echo "export OS_USER_DOMAIN_NAME=$keystonedomain" >> $keystone_admin_rc_file
	echo "PS1='[\u@\h \W(keystone_admin)]\$ '" >> $keystone_admin_rc_file

	OS_AUTH_URL_FULLADMIN="http://$keystonehost:35357/v3"

	echo "export OS_USERNAME=$OS_USERNAME" >> $keystone_fulladmin_rc_file
	echo "export OS_PASSWORD=$OS_PASSWORD" >> $keystone_fulladmin_rc_file
	echo "export OS_PROJECT_NAME=$OS_TENANT_NAME" >> $keystone_fulladmin_rc_file
	echo "export OS_AUTH_URL=$OS_AUTH_URL_FULLADMIN" >> $keystone_fulladmin_rc_file
	echo "export OS_VOLUME_API_VERSION=2" >> $keystone_fulladmin_rc_file
	echo "export OS_IDENTITY_API_VERSION=3" >> $keystone_fulladmin_rc_file
	echo "export OS_PROJECT_DOMAIN_NAME=$keystonedomain" >> $keystone_fulladmin_rc_file
	echo "export OS_USER_DOMAIN_NAME=$keystonedomain" >> $keystone_fulladmin_rc_file
	echo "PS1='[\u@\h \W(keystone_fulladmin)]\$ '" >> $keystone_fulladmin_rc_file

	mkdir -p /etc/openstack-control-script-config
	date > /etc/openstack-control-script-config/keystone-installed
	date > /etc/openstack-control-script-config/keystone-extra-idents

	echo ""
	exit 0
fi

echo "Installing Keystone Packages"

#
# We proceed to install keystone packages and it's dependencies
#
#

yum -y install openstack-keystone openstack-utils openstack-selinux python-psycopg2
yum -y install mod_wsgi memcached python-memcached httpd
yum -y install python-openstackclient

#
# We also start/enable memcached service
#

cat ./libs/memcached/memcached > /etc/sysconfig/memcached

systemctl enable memcached
systemctl stop memcached
systemctl start memcached

echo "Done"

echo ""
echo "Configuring Keystone"

sync
sleep 5
sync

#
# Using pyhton based "ini" configuration tools, we begin Keystone configuration
#

crudini --set /etc/keystone/keystone.conf DEFAULT compute_port 8774
crudini --set /etc/keystone/keystone.conf DEFAULT debug False
crudini --set /etc/keystone/keystone.conf DEFAULT log_file /var/log/keystone/keystone.log
crudini --set /etc/keystone/keystone.conf DEFAULT use_syslog False
crudini --set /etc/keystone/keystone.conf memcache servers $keystonehost:11211

#
# Keystone Cache Config
#

crudini --set /etc/keystone/keystone.conf cache backend dogpile.cache.memcached
crudini --set /etc/keystone/keystone.conf cache enabled True
crudini --set /etc/keystone/keystone.conf cache memcache_servers $keystonehost:11211
 

case $dbflavor in
"mysql")
	crudini --set /etc/keystone/keystone.conf database connection mysql+pymysql://$keystonedbuser:$keystonedbpass@$dbbackendhost:$mysqldbport/$keystonedbname
	;;
"postgres")
	crudini --set /etc/keystone/keystone.conf database connection postgresql+psycopg2://$keystonedbuser:$keystonedbpass@$dbbackendhost:$psqldbport/$keystonedbname
	;;
esac
 
crudini --set /etc/keystone/keystone.conf catalog driver sql
crudini --set /etc/keystone/keystone.conf token expiration 86400
crudini --set /etc/keystone/keystone.conf token driver memcache
crudini --set /etc/keystone/keystone.conf revoke driver sql

crudini --set /etc/keystone/keystone.conf assignment driver sql
crudini --set /etc/keystone/keystone.conf paste_deploy config_file /etc/keystone/keystone-paste.ini

crudini --set /etc/keystone/keystone.conf database retry_interval 10
crudini --set /etc/keystone/keystone.conf database idle_timeout 3600
crudini --set /etc/keystone/keystone.conf database min_pool_size 1
crudini --set /etc/keystone/keystone.conf database max_pool_size 10
crudini --set /etc/keystone/keystone.conf database max_retries 100
crudini --set /etc/keystone/keystone.conf database pool_timeout 10

case $keystonetokenflavor in
"fernet")
	crudini --set /etc/keystone/keystone.conf token provider fernet
	;;
"pki")
	chown -R keystone:keystone /var/log/keystone
	keystone-manage pki_setup --keystone-user keystone --keystone-group keystone
	chown -R keystone:keystone /var/log/keystone /etc/keystone/ssl
	crudini --set /etc/keystone/keystone.conf token provider pki
	;;
"uuid")
	crudini --set /etc/keystone/keystone.conf token provider uuid
	;;
esac

#
# We provision/update Keystone database
#

echo ""
echo "Provisioning Keystone DB"
echo ""
su keystone -s /bin/sh -c "keystone-manage db_sync"

echo "Done"
echo ""

#
# And, if we are using fernet tokens, we initialice them
#

if [ $keystonetokenflavor == "fernet" ]
then
	echo ""
	echo "Creating FERNET Tokens"
	echo ""
	keystone-manage fernet_setup --keystone-user keystone --keystone-group keystone
	keystone-manage credential_setup --keystone-user keystone --keystone-group keystone
fi

#
# With the basic configuration done, and the "admin service token" exported to our environment,
# we proceed to start Keystone in order to create all needed credentials
#

echo "Starting Keystone"

# Keystone nows uses apache and wsgi instead of it's own services

systemctl stop openstack-keystone.service > /dev/null 2>&1
systemctl disable openstack-keystone.service > /dev/null 2>&1

cat ./libs/memcached/memcached > /etc/sysconfig/memcached

systemctl stop memcached
systemctl start memcached
systemctl enable memcached

ln -s /usr/share/keystone/wsgi-keystone.conf /etc/httpd/conf.d/

#
# PATCH !!.. Without this, Keystone on wsgi does not work...
crudini --set /etc/keystone/keystone.conf paste_deploy config_file "/usr/share/keystone/keystone-dist-paste.ini"
cat /etc/keystone/keystone.conf > /usr/share/keystone/keystone-dist.conf
cat /etc/keystone/policy.json > /usr/share/keystone/policy.json
cat /etc/keystone/keystone-paste.ini > /usr/share/keystone/keystone-dist-paste.ini
chown root.keystone /usr/share/keystone/policy.json
# END OF PATCH !!
#

chown -R keystone:keystone /var/log/keystone

if [ -d /etc/keystone/ssl ]
then
	chown -R keystone:keystone /etc/keystone/ssl
	chmod -R o-rwx /etc/keystone/ssl
fi

#
restorecon /var/www/cgi-bin
#
usermod -a -G keystone apache
#
#
systemctl start httpd.service
systemctl restart httpd.service
systemctl enable httpd.service
#

echo "Done"

sync
sleep 5
sync

echo ""

#
# Time to bootstrap Keystone !!
#

echo ""
echo "Bootstraping Keystone"
echo ""

keystone-manage bootstrap \
	--bootstrap-password $keystoneadminpass \
	--bootstrap-admin-url http://$keystonehost:35357/v3/ \
	--bootstrap-internal-url http://$keystonehost:35357/v3/ \
	--bootstrap-public-url http://$keystonehost:5000/v3/ \
	--bootstrap-region-id $endpointsregion \
	--bootstrap-username $keystoneadminuser \
	--bootstrap-project-name $keystoneadminuser \
	--bootstrap-role-name $keystoneadminuser \
	--bootstrap-service-name "keystone"

OS_URL="http://$keystonehost:35357/v3"
OS_USERNAME=$keystoneadminuser
OS_TENANT_NAME=$keystoneadminuser
OS_PROJECT_NAME=$keystoneadminuser
OS_PASSWORD=$keystoneadminpass
OS_AUTH_URL="http://$keystonehost:5000/v3"
OS_VOLUME_API_VERSION=2
OS_PROJECT_DOMAIN_NAME=$keystonedomain
OS_USER_DOMAIN_NAME=$keystonedomain
OS_IDENTITY_API_VERSION=3

echo "export OS_USERNAME=$OS_USERNAME" >> $keystone_admin_rc_file
echo "export OS_PASSWORD=$OS_PASSWORD" >> $keystone_admin_rc_file
echo "export OS_PROJECT_NAME=$OS_TENANT_NAME" >> $keystone_admin_rc_file
echo "export OS_AUTH_URL=$OS_AUTH_URL" >> $keystone_admin_rc_file
echo "export OS_VOLUME_API_VERSION=2" >> $keystone_admin_rc_file
echo "export OS_IDENTITY_API_VERSION=3" >> $keystone_admin_rc_file
echo "export OS_PROJECT_DOMAIN_NAME=$keystonedomain" >> $keystone_admin_rc_file
echo "export OS_USER_DOMAIN_NAME=$keystonedomain" >> $keystone_admin_rc_file
echo "PS1='[\u@\h \W(keystone_admin)]\$ '" >> $keystone_admin_rc_file

OS_AUTH_URL_FULLADMIN="http://$keystonehost:35357/v3"

echo "export OS_USERNAME=$OS_USERNAME" >> $keystone_fulladmin_rc_file
echo "export OS_PASSWORD=$OS_PASSWORD" >> $keystone_fulladmin_rc_file
echo "export OS_PROJECT_NAME=$OS_TENANT_NAME" >> $keystone_fulladmin_rc_file
echo "export OS_AUTH_URL=$OS_AUTH_URL_FULLADMIN" >> $keystone_fulladmin_rc_file
echo "export OS_VOLUME_API_VERSION=2" >> $keystone_fulladmin_rc_file
echo "export OS_IDENTITY_API_VERSION=3" >> $keystone_fulladmin_rc_file
echo "export OS_PROJECT_DOMAIN_NAME=$keystonedomain" >> $keystone_fulladmin_rc_file
echo "export OS_USER_DOMAIN_NAME=$keystonedomain" >> $keystone_fulladmin_rc_file
echo "PS1='[\u@\h \W(keystone_fulladmin)]\$ '" >> $keystone_fulladmin_rc_file

#
# Then we source the file, as we are goint to use it from now on
#

source $keystone_fulladmin_rc_file

echo ""

sync
sleep 5
sync

echo "Creating Services Project: $keystoneservicestenant"
openstack project create --domain $keystonedomain --description "Service Project" $keystoneservicestenant

# Dashboard/Reseller
echo "Creating Member Role: $keystonememberrole"
openstack role create $keystonememberrole

# User role
echo "Creating User Role: $keystoneuserrole"
openstack role create $keystoneuserrole

echo "Adding Member Role $keystonememberrole to Admin User: $keystoneadminuser"
openstack role add --project $keystoneadminuser --user $keystoneadminuser $keystonememberrole

sync
sleep 5
sync

echo "Keystone Main Identities Configured:"

openstack project list
openstack user list
openstack service list
openstack endpoint list
openstack role list


#
# We apply IPTABLES rules and verify if the service was properlly installed. If not, we fail
# and stop further processing.
#

echo ""
echo "Applying IPTABLES rules"

iptables -A INPUT -p tcp -m multiport --dports 5000,11211,35357 -j ACCEPT
service iptables save

keystonetest=`rpm -qi openstack-keystone|grep -ci "is not installed"`
if [ $keystonetest == "1" ]
then
	echo ""
	echo "Keystone Installation FAILED. Aborting !"
	echo ""
	exit 0
else
	date > /etc/openstack-control-script-config/keystone-installed
	date > /etc/openstack-control-script-config/keystone
	date > /etc/openstack-control-script-config/keystone-http-service-installed
fi

checkadmincreate=`openstack user list|awk '{print $4}'|grep -ci ^$keystoneadminuser$`

if [ $checkadmincreate == "0" ]
then
	echo ""
	echo "Admin User Creation FAILED - Aborting !"
	echo ""
	rm -f /etc/openstack-control-script-config/keystone-installed
	rm -f /etc/openstack-control-script-config/keystone
	exit 0
fi

#
# Now, depending if the choose to install specific OpenStack components, we proceed
# to call the keystone sub-script that will create the specific service identities,
# meaning: user, roles, services, and endpoints.
#
# OpenStack Components make use of REST interface trough their Endpoints in order to
# communicate to each other. Without those endpoints, OpenStack will not work at all.
#
# In all and every sub-script the proccess is the same: First we create the user, then
# we assign a role to the user, second: we create the service (or services) identity,
# and finally we create the endpoint (or endpoints) identity.
#

echo ""
echo "Creating OpenStack Services Identities"
echo ""


if [ $swiftinstall == "yes" ]
then
	./modules/keystone-swift.sh
fi

if [ $glanceinstall == "yes" ]
then
	./modules/keystone-glance.sh
fi

if [ $cinderinstall == "yes" ]
then
	./modules/keystone-cinder.sh
fi

if [ $neutroninstall == "yes" ]
then
	./modules/keystone-neutron.sh
fi

if [ $novainstall == "yes" ]
then
	./modules/keystone-nova.sh
fi

if [ $ceilometerinstall == "yes" ]
then
	./modules/keystone-ceilometer.sh
fi

if [ $heatinstall == "yes" ]
then
	./modules/keystone-heat.sh
fi

if [ $troveinstall == "yes" ]
then
	./modules/keystone-trove.sh
fi

if [ $saharainstall == "yes" ]
then
	./modules/keystone-sahara.sh
fi

if [ $manilainstall == "yes" ]
then
	./modules/keystone-manila.sh
fi

if [ $designateinstall == "yes" ]
then
	./modules/keystone-designate.sh
fi

if [ $magnuminstall == "yes" ]
then
	./modules/keystone-magnum.sh
fi

#
# If we define extra tenants in the installer config file, here we proceed to create them
#

./modules/keystone-extratenants.sh

date > /etc/openstack-control-script-config/keystone-extra-idents

#
# Everything done, we proceed to list all identities created by this module
#

echo ""
echo "Ready"

echo ""
echo "Keystone Proccess DONE"
echo ""

echo "Complete list following bellow:"
echo ""
echo "Projects:"
openstack project list
sleep 5
echo "Users:"
openstack user list
sleep 5
echo "Services:"
openstack service list
sleep 5
echo "Roles:"
openstack role list
sleep 5
echo "Endpoints:"
openstack endpoint list
sleep 5

echo ""
echo "Identities Proccess completed"
echo ""


