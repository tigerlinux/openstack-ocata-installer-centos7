#!/bin/bash
#
# Unattended/SemiAutomatted OpenStack Installer
# Reynaldo R. Martinez P.
# E-Mail: TigerLinux@Gmail.com
# General Firewall Config Script
# ALERT: DO NOT USE THIS SCRIPT WITH OPENSTACK SERVICES ACTIVE
# Shutdown your openstack services first with "openstack-control.sh stop" !.
#

PATH=$PATH:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin

#
# First, we source our config file and verify that some important proccess are
# already completed.
#

if [ -f ./configs/main-config.rc ]
then
        source ./configs/main-config.rc
else
        echo "Can't access my config file. Aborting !"
        echo ""
        exit 0
fi

if [ ! $osprivatenetwork ]
then
	export osprivatenetwork=`ip route get 1 | awk '{print $NF;exit}'`
fi

if [ ! $keystoneclientnetwork ]
then
	export keystoneclientnetwork=`ip route get 1 | awk '{print $NF;exit}'`
fi

if [ ! $manilaclientnetwork ]
then
	export manilaclientnetwork="0.0.0.0/0"
fi

if [ ! $designateclientnetwork ]
then
	export designateclientnetwork="0.0.0.0/0"
fi

if [ ! $horizonclientnetwork ]
then
	export horizonclientnetwork="0.0.0.0/0"
fi

if [ ! $nova_computehost ]
then
	export nova_computehost=`ip route get 1 | awk '{print $NF;exit}'`
fi

# echo "$osprivatenetwork, $manilaclientnetwork, $designateclientnetwork, $horizonclientnetwork"

if [ -f /etc/centos-release ]
then
	service iptables restart
	iptables -F
	iptables -P INPUT ACCEPT
	iptables -P FORWARD ACCEPT
	iptables -P OUTPUT ACCEPT
	iptables -t nat -F
	iptables -t mangle -F
	iptables -F
	iptables -X
	service iptables save
	systemctl enable iptables
fi

if [ -f /etc/debian_version ]
then
	/etc/init.d/netfilter-persistent restart
	/etc/init.d/netfilter-persistent flush
	iptables -F
	iptables -P INPUT ACCEPT
	iptables -P FORWARD ACCEPT
	iptables -P OUTPUT ACCEPT
	iptables -t nat -F
	iptables -t mangle -F
	iptables -F
	iptables -X
	/etc/init.d/netfilter-persistent save
	update-rc.d netfilter-persistent enable
	systemctl enable netfilter-persistent
	/etc/init.d/netfilter-persistent save
fi

# Basic ports: ssh, dns and ntp
iptables -A INPUT -p tcp -m multiport --sports 123,53 -j ACCEPT
iptables -A INPUT -p udp -m multiport --sports 123,53 -j ACCEPT
iptables -A INPUT -m state --state NEW -m tcp -p tcp --dport 22 -j ACCEPT

# And internal connections too:
for myip in `ip -4 -o addr| awk '{gsub(/\/.*/,"",$4); print $4}'`
do
	iptables -A INPUT -s $myip -p tcp -m tcp -j ACCEPT
	iptables -A INPUT -s $myip -p udp -m udp -j ACCEPT
done

# Full localhost too
iptables -A INPUT -s 127.0.0.0/8 -p tcp -m tcp -j ACCEPT
iptables -A INPUT -s 127.0.0.0/8 -p udp -m udp -j ACCEPT

# Message broker
if [ $messagebrokerinstall == "yes" ]
then
	iptables -I INPUT -s $osprivatenetwork -m state --state NEW -m tcp -p tcp --dport 5672 -j ACCEPT
fi

# Database
if [ $dbinstall == "yes" ]
then
	iptables -A INPUT -s $osprivatenetwork -p tcp -m multiport --dports $mysqldbport,$psqldbport -j ACCEPT
fi

# Keystone
if [ $keystoneinstall == "yes" ]
then
	iptables -A INPUT -s $osprivatenetwork -p tcp -m multiport --dports 5000,11211,35357 -j ACCEPT
	iptables -A INPUT -s $keystoneclientnetwork -p tcp -m multiport --dports 5000,35357 -j ACCEPT
fi

#Swift
if [ $swiftinstall == "yes" ]
then
	iptables -A INPUT -s $osprivatenetwork -p tcp -m multiport --dports 6000,6001,6002,873 -j ACCEPT
	iptables -A INPUT -s $osprivatenetwork -p tcp -m multiport --dports 8080,11211 -j ACCEPT
fi

#Glance
if [ $glanceinstall == "yes" ]
then
	iptables -A INPUT -s $osprivatenetwork -m state --state NEW -m tcp -p tcp --dport 9292 -j ACCEPT
fi

#Cinder
if [ $cinderinstall == "yes" ]
then
	iptables -A INPUT -s $osprivatenetwork -p tcp -m multiport --dports 3260,8776 -j ACCEPT
fi

#Neutron
if [ $neutroninstall == "yes" ]
then
	iptables -A INPUT -s $osprivatenetwork -p udp -m state --state NEW -m udp --dport 4789 -j ACCEPT
	iptables -A INPUT -s $osprivatenetwork -m state --state NEW -m tcp -p tcp --dport 9696 -j ACCEPT
fi

#Nova
if [ $novainstall == "yes" ]
then
	iptables -A INPUT -s $osprivatenetwork -m state --state NEW -m tcp -p tcp --dport 6080 -j ACCEPT
	iptables -A INPUT -s $osprivatenetwork -m state --state NEW -m tcp -p tcp --dport 6081 -j ACCEPT
	iptables -A INPUT -s $osprivatenetwork -m state --state NEW -m tcp -p tcp --dport 6082 -j ACCEPT
	iptables -A INPUT -s $nova_computehost -p tcp -m multiport --dports 5900:5999 -j ACCEPT
	iptables -A INPUT -s $osprivatenetwork -p tcp -m multiport --dports 8773,8774,8775,8778 -j ACCEPT
	iptables -A INPUT -s $osprivatenetwork -m state --state NEW -m tcp -p tcp --dport 16509 -j ACCEPT
fi

#Ceilometer/aodh/gnocchi
if [ $ceilometerinstall == "yes" ]
then
	iptables -A INPUT -s $osprivatenetwork -p tcp -m multiport --dports 8777,8041,8042 -j ACCEPT
fi

#Heat
if [ $heatinstall == "yes" ]
then
	iptables -A INPUT -s $osprivatenetwork -p tcp -m multiport --dports 8000,8003,8004 -j ACCEPT
fi

#Trove
if [ $troveinstall == "yes" ]
then
	iptables -A INPUT -s $osprivatenetwork -m state --state NEW -m tcp -p tcp --dport 8779 -j ACCEPT
fi

#Sahara
if [ $saharainstall == "yes" ]
then
	iptables -A INPUT -s $osprivatenetwork -m state --state NEW -m tcp -p tcp --dport 8386 -j ACCEPT
fi

#Manila
if [ $manilainstall == "yes" ]
then
	iptables -A INPUT -s $osprivatenetwork -m state --state NEW -m tcp -p tcp --dport 8786 -j ACCEPT
	iptables -A INPUT -s $osprivatenetwork -p tcp -m multiport --dports 111,2049,445,139 -j ACCEPT
	iptables -A INPUT -s $manilaclientnetwork -p tcp -m multiport --dports 111,2049,445,139 -j ACCEPT
fi

#Designate
if [ $designateinstall == "yes" ]
then
	iptables -A INPUT -s $osprivatenetwork -p tcp -m multiport --dports 5354,53,9001 -j ACCEPT
	iptables -A INPUT -s $osprivatenetwork -p udp -m multiport --dports 5354,53 -j ACCEPT
	iptables -A INPUT -s $designateclientnetwork -p tcp -m multiport --dports 5354,53 -j ACCEPT
	iptables -A INPUT -s $designateclientnetwork -p udp -m multiport --dports 5354,53 -j ACCEPT
fi

#Magnum
if [ $magnuminstall == "yes" ]
then
	iptables -A INPUT -s $osprivatenetwork -m state --state NEW -m tcp -p tcp --dport 9511 -j ACCEPT
fi

#Horizon
if [ $horizoninstall == "yes" ]
then
	iptables -A INPUT -s $osprivatenetwork -m state --state NEW -m tcp -p tcp --dport 11211 -j ACCEPT
	iptables -A INPUT -s $horizonclientnetwork -p tcp -m multiport --dports 80,443 -j ACCEPT
fi

#Monitoring - both snmp and zabbix:
if [ $snmpinstall == "yes" ]
then
	iptables -A INPUT -s $osprivatenetwork -p udp -m multiport --dports 161 -j ACCEPT
	iptables -A INPUT -d $osprivatenetwork -p udp -m multiport --sports 161 -j ACCEPT
	iptables -A INPUT -s $osprivatenetwork -m state --state NEW -m tcp -p tcp --dport 10050 -j ACCEPT
fi

# Block everything else:
iptables -t filter -A INPUT -s 0.0.0.0/0 -d 0.0.0.0/0 -p tcp -m tcp --syn -j REJECT --reject-with icmp-host-prohibited
iptables -t filter -A INPUT -s 0.0.0.0/0 -d 0.0.0.0/0 -p udp -m udp -j REJECT --reject-with icmp-host-prohibited

# And save all rules:
if [ -f /etc/centos-release ]
then
	service iptables save
fi

if [ -f /etc/debian_version ]
then
	/etc/init.d/netfilter-persistent save
fi

# END


