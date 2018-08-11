#!/bin/bash -e
################################################################################
# This script is developed by Shaik Saddam Hussain
# Any Queries / Suggestion - Please contact at sksaddamhussain@gmail.com
################################################################################
clear;
START_TIME=$(date +%d-%m-%Y_%H:%M:%S)
echo -e "\t-----------------------------------------"
echo -e "\t|    AWX Setup configuration wizard     |"
echo -e "\t-----------------------------------------\n"

if [ $(whoami) != root ]
then 
  echo -e "\nOnly root user can run this tool\n"
  echo -e "####### Program Terminated #######"
  exit 1
fi

echo -e "\nConfiguring SELINUX........\n"
sed "s/SELINUX=/#SELINUX=/g" -i /etc/selinux/config
echo "SELINUX=permissive" >> /etc/selinux/config
setenforce 0
sestatus

echo -e "\nConfiguring Firewall.......\n"
systemctl enable firewalld
systemctl start firewalld
firewall-cmd --add-service=http --permanent;firewall-cmd --add-service=https --permanent
systemctl restart firewalld

echo -e "\nEnabling CentOS EPEL repository.......\n"
yum install -y epel-release

echo -e "\nInitiating OS Patch update.......\n"
yum update -y

echo -e "\nEnabling postgreSQL repository.........\n"
yum install -y https://download.postgresql.org/pub/repos/yum/9.6/redhat/rhel-7-x86_64/pgdg-centos96-9.6-3.noarch.rpm

echo -e "\nInstalling postgreSQL.......\n"
yum install postgresql96-server -y

echo -e "\nInstalling the other necessary rpms.......\n"
yum install -y rabbitmq-server wget memcached nginx ansible

echo -e "\nInstalling Ansible AWX.......\n"
wget -O /etc/yum.repos.d/awx-rpm.repo https://copr.fedorainfracloud.org/coprs/mrmeee/awx/repo/epel-7/mrmeee-awx-epel-7.repo
yum install -y awx
/usr/pgsql-9.6/bin/postgresql96-setup initdb

echo -e "\nInitiating necessary services........\n"
systemctl start rabbitmq-server
systemctl enable rabbitmq-server
systemctl enable postgresql-9.6
systemctl start postgresql-9.6
systemctl enable memcached
systemctl start memcached

echo -e "\nCreating Postgres user and DB........\n"
sudo -u postgres createuser -S awx
sudo -u postgres createdb -O awx awx
sudo -u awx /opt/awx/bin/awx-manage migrate

echo -e "\nInitializing the configuration for AWX.......\n"
echo "from django.contrib.auth.models import User; User.objects.create_superuser('admin', 'root@localhost', 'password')" | sudo -u awx /opt/awx/bin/awx-manage shell
sudo -u awx /opt/awx/bin/awx-manage create_preload_data
sudo -u awx /opt/awx/bin/awx-manage provision_instance --hostname=$(hostname)
sudo -u awx /opt/awx/bin/awx-manage register_queue --queuename=tower --hostnames=$(hostname)

echo -e "\nConfiguring Nginx........\n"
cd /etc/nginx/
cp nginx.conf nginx.conf.bkp
wget -O /etc/nginx/nginx.conf https://raw.githubusercontent.com/sksaddamhussain/nginx/master/nginx.conf
systemctl start nginx
systemctl enable nginx
systemctl start awx-cbreceiver
systemctl start awx-celery-beat
systemctl start awx-celery-worker
systemctl start awx-channels-worker
systemctl start awx-daphne
systemctl start awx-web
systemctl enable awx-cbreceiver
systemctl enable awx-celery-beat
systemctl enable awx-celery-worker
systemctl enable awx-channels-worker
systemctl enable awx-daphne
systemctl enable awx-web

echo -e "\nCongiuring SSH.......\n"
sed "s/PasswordAuthentication /#PasswordAuthentication /g" -i /etc/ssh/sshd_config
echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config
service sshd restart

ANSIBLE_USERNAME="test"
ANSIBLE_PASSWORD="password"
echo -e "\nCreating '$ANSIBLE_USERNAME' user and setting-up user environment.........\n"
useradd $ANSIBLE_USERNAME
echo "$ANSIBLE_PASSWORD" | passwd --stdin $ANSIBLE_USERNAME
echo "$ANSIBLE_USERNAME ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/$ANSIBLE_USERNAME

#ssh $ANSIBLE_USERNAME@localhost 'cd ~;ssh-keygen -t rsa -N "" -q -f ~/.ssh/id_rsa;cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys'


echo -e "\nAWX Setup configuration Completed Successfully\n"

echo -e "\nNote:"
echo -e "-----\n"
echo -e "* Now, you should be able to access AWX dashboard at below mentioned URL(s)"
for i in `ip -4 addr show scope global | grep inet | awk -F " " '{print $2}' | cut -d '/' -f 1`
do
	echo -e "\t\thttp://$i"
done
echo -e "* Try accessing dashboard using below credentials"
echo -e "\t\t USERNAME : admin"
echo -e "\t\t PASSWORD : password"
echo -e "* AWX server needs to be rebooted - Please perform reboot manually for better performance"


STOP_TIME=$(date +%d-%m-%Y_%H:%M:%S)

echo -e "\n\t######################################################"
echo -e "\t########   AWX Setup configuration Summary   #########"
echo -e "\t######################################################\n"
echo -e "\t\t Start Time : $START_TIME\n"
echo -e "\t\t Stop Time  : $STOP_TIME\n"
echo -e "\t######################################################\n"
