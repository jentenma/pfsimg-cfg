#!/bin/bash

#
# Install latest Mellanox
#
echo "Updating Mellanox Driver" >> /var/log/firstboot
/bin/tar xzvf  /root/mlnx/mlnx-en-4.1-1.0.2.0-rhel7.3-x86_64.tgz -C /root/mlnx >> /var/log/firstboot 2>&1
/root/mlnx/mlnx-en-4.1-1.0.2.0-rhel7.3-x86_64/install --force >> /var/log/firstboot 2>&1
/etc/init.d/mlnx-en.d restart >> /var/log/firstboot 2>&1
mlogs=`ls /tmp/mlnx*`
echo "Mellanox logs are in $mlogs" >> /var/log/firstboot

#
# Install latest ipmitool
#
echo "Updating to latest ipmitool" >> /var/log/firstboot
/bin/tar jxvf  /root/ipmitool/ipmitool-1.8.18.tar.bz2 -C /root/ipmitool >> /var/log/firstboot 2>&1
cd /root/ipmitool/ipmitool-ipmitool-1.8.18;./configure;make;make install;cd

#/bin/cd /root/mlnx
#/usr/sbin/modprobe bonding mode=4 xmit_hash_policy=2
#echo +fbond > /sys/class/net/bonding_masters

fabname=`hostname`-fab
fabip=`cat /etc/hosts | grep $fabname | awk '{print $1}'`
#cat /etc/sysconfig/network-scripts/ifcfg-fbond | sed "s/INSERT_FAB_ADDRESS_HERE/$fabip/g" > /tmp/fbond.tmp
#cp /tmp/fbond.tmp /etc/sysconfig/network-scripts/ifcfg-fbond

mgtname=`hostname`-mgt
mgtip=`cat /etc/hosts | grep $mgtname | awk '{print $1}'`
#cat /etc/sysconfig/network-scripts/ifcfg-mgt0 | sed "s/INSERT_MGT0_ADDRESS_HERE/$mgtip/g" > /tmp/mgt0.tmp
#cp /tmp/mgt0.tmp /etc/sysconfig/network-scripts/ifcfg-mgt0

echo "Configuring mgt0 interface" >> /var/log/firstboot
cat <<EOF > /etc/sysconfig/network-scripts/ifcfg-mgt0
TYPE="Ethernet"
BOOTPROTO="static"
DEFROUTE="no"
PEERDNS="yes"
PEERROUTE="yes"
IPV4_FAILURE_FATAL="no"
IPV6INIT="yes"
IPV6_AUTOCONF="yes"
IPV6_DEFROUTE="yes"
IPV6_PEERDNS="yes"
IPV6_PEERROUTES="yes"
IPV6_FAILURE_FATAL="no"
NAME="mgt0"
DEVICE="mgt0"
IPADDR=$mgtip
NETMASK="255.255.254.0"
EOF
echo "Done Configuring mgt0 interface" >> /var/log/firstboot

echo "Configuring Fabric interface" >> /var/log/firstboot
cat <<EOF > /etc/sysconfig/network-scripts/ifcfg-fab0
NAME=fab0
DEVICE=fab0
BOOTPROTO=none
ONBOOT=yes
NETBOOT=no
IPV6INIT=yes
TYPE=Ethernet
TXQUEUELEN=100000
MASTER=fbond
SLAVE=yes
NM_CONTROLLED=no
EOF

cat <<EOF > /etc/sysconfig/network-scripts/ifcfg-fab1
NAME=fab1
DEVICE=fab1
BOOTPROTO=none
ONBOOT=yes
NETBOOT=no
IPV6INIT=yes
TYPE=Ethernet
TXQUEUELEN=100000
MASTER=fbond
SLAVE=yes
NM_CONTROLLED=no
EOF

cat <<EOF > /etc/sysconfig/network-scripts/ifcfg-fbond
DEVICE=fbond
NAME=fbond
TYPE=Bond
BONDING_MASTER=YES
ONBOOT=yes
BOOTPROTO=none
NM_CONTROLLED=no
USERCTL=no
IPV6INIT=no
BONDING_OPTS="mode=4 miimon=200 xmit_hash_policy=1 updelay=2000"
MTU=9000
TXQUEUELEN=100000
IPADDR=$fabip
NETMASK=255.255.254.0
EOF

echo "Done Configuring Fabric interface" >> /var/log/firstboot

cat <<EOF > /tmp/fbvars.log
$mgtname
$mgtip
$fabname
$fabip
EOF

/sbin/ifdown mgt0
/sbin/ifup mgt0

/sbin/ifdown fab0
/sbin/ifdown fab1
/sbin/ifdown fbond
/sbin/ifup fab0
/sbin/ifup fab1
/sbin/ifup fbond


#
# dhcpd.conf
#
echo "Configuring dhcpd.conf" >> /var/log/firstboot
cat <<EOF > /etc/dhcp/dhcpd.conf

# DHCP Server Configuration file
# This file is auto generated by installer
# must be owned by dhcpd:dhcpd
lease-file-name "/var/lib/dhcpd/dhcpd.leases";

allow bootp;
allow booting;

DHCPDARGS=eth1;

log-facility local7;

option conf-file code 209 = text;
option path-file code 210 = text;
option client-architecture code 93 = unsigned integer 16;

option space isan;
option isan-encap-opts code 43 = encapsulate isan;
option isan.iqn code 203 = string;
option isan.root-path code 201 = string;
option space gpxe;
option gpxe-encap-opts code 175 = encapsulate gpxe;
option gpxe.bus-id code 177 = string;
option user-class-identifier code 77 = string;
option gpxe.no-pxedhcp code 176 = unsigned integer 8;
option tcode code 101 = text;
option iscsi-initiator-iqn code 203 = string;
ignore client-updates;
option tcode "US/Eastern";
option gpxe.no-pxedhcp 1;

# filename "pxelinux.0"

shared-network eth1 {
 subnet 9.0.224.0 netmask 255.255.254.0 {
 option routers 9.0.224.2;
 #option subnet-mask 255.255.255.192;
 option domain-search "private.dns.zone";
 option domain-name-servers 9.0.224.2;
 option time-offset -18000;  # EST
 #range dynamic-bootp 9.0.224.51 9.0.224.83;
 range dynamic-bootp 9.0.225.27 9.0.225.82;
 zone private.dns.zone {
    primary 9.0.224.2;
    }
  }
}
EOF
echo "Done onfiguring dhcpd.conf" >> /var/log/firstboot
#
# Always at the end
#
echo "Cleaning up" >> /var/log/firstboot
/bin/cat /etc/crontab | /bin/grep -v firstboot > /etc/crontab.tmp
/bin/cp /etc/crontab /tmp/crontab.fb
/bin/rm -f /etc/crontab
/bin/mv /etc/crontab.tmp /etc/crontab
/bin/cp $0 /tmp/$0.fb
rm -f $0