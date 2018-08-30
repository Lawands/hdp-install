#!/bin/bash -x
#1. Create a instance.
#2. Execute the HDP installation script. Ambari version 2.6.2.0
#3. Do manual installations of ambari. do ssh key-gen process for ambari user.  Then select kafka, zk, smartsense, etc. 2-3 services.
#4. After complete installation, Execute below from ambari server. 
#5.  curl -H "X-Requested-By: ambari" -X GET -u admin:admin http://node.scscsext.com:8080/api/v1/clusters/SLv1?format=blueprint
#6. Run above command again to take output in a file.
# curl -H "X-Requested-By: ambari" -X GET -u admin:admin http://node.scscsext.com:8080/api/v1/clusters/SLv1?format=blueprint > cluster_configuration.json
#7. Create a new instance.
#8. Run installation script. Do changes in amabri-agent.ini file for hostname changes. Do reboot.
#   verify ambari-server and agent services are running or not after reboot
#9. Copy cluster_configuration.json and hostmapping.json to the new server.
#10. Do change hostname in cluster_configuration.json and hostmapping.json. This is hostname in this example: node.scscsext.com and  new server hostname is :node1.scscsext.com. New server name need to mention in both json files.
#
#11. hostmapping.json
#
#{
#  "blueprint" : "single-node-hdp-cluster",
#  "default_password" : "admin",
#  "host_groups" :[
#    {
#      "name" : "host_group_1",
#      "hosts" : [
#        {
#          "fqdn" : "node.scscsext.com"
#        }
#      ]
#    }
#  ]
#}
#[root@node1 tmp]# cat cluster_configuration.json | grep -i "node"
#         "server.url" : "http://node.scscsext.com:9000",
#
#
#12. Cluster Name need to mention in below curl command: SLv1
#
#13. Do changes of hostname and cluster name in below url.
#curl -H "X-Requested-By: ambari" -X POST -u admin:admin http://node1.scscsext.com:8080/api/v1/blueprints/single-node-hdp-cluster -d @cluster_configuration.json
#curl -H "X-Requested-By: ambari" -X POST -u admin:admin http://node1.scscsext.com:8080/api/v1/clusters/SLv1 -d @hostmapping.json
#
#Sample output:
#[root@node tmp]# curl -H "X-Requested-By: ambari" -X GET -u admin:admin http://lin-0af8221.scscsext.com:8080/api/v1/clusters/SLv1?format=blueprint > cluster_configuration.json
#  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
#                                 Dload  Upload   Total   Spent    Left  Speed
#100  144k    0  144k    0     0  3982k      0 --:--:-- --:--:-- --:--:-- 4005k
#[root@node tmp]#
#[root@node1 tmp]# curl -H "X-Requested-By: ambari" -X POST -u admin:admin http://node1.scscsext.com:8080/api/v1/clusters/SLv1 -d @hostmapping.json
#{
#  "href" : "http://node1.scscsext.com:8080/api/v1/clusters/SLv1/requests/1",
#  "Requests" : {
#    "id" : 1,
#    "status" : "Accepted"
#  }
#}[root@node1 tmp]#
#
#HDP installation and configuration of Ambari-server, Mysql, Ambari-agent script begins..
useradd ambari
echo "ambari"|passwd --stdin ambari
usermod -aG wheel ambari
#change hostname/ip in /etc/ambari-agent/conf/ambari-agent.ini at line no. 62
sed -i.bak 's/^#\s*\(%wheel\s*ALL=(ALL)\s*NOPASSWD:\s*ALL\)/\1/' /etc/sudoers
sed -i.bak 's/PasswordAuthentication no/PasswordAuthentication yes/g' /etc/ssh/sshd_config
sed -i.bak 's/PermitRootLogin no/PermitRootLogin yes/g' /etc/ssh/sshd_config
sed -i.bak 's/PermitRootLogin  forced-commands-only/PermitRootLogin yes/g' /etc/ssh/sshd_config
systemctl restart sshd
yum install mysql-connector-java* ntp vim lynx lsof wget git -y
systemctl stop firewalld
systemctl disable firewalld
sed -i.bak 's/SELINUX=permissive/SELINUX=disabled/g' /etc/selinux/config
sed -i.bak 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
systemctl start ntpd
systemctl enable ntpd
sestatus
systemctl status firewalld
wget http://repo.mysql.com/mysql-community-release-el7-5.noarch.rpm
rpm -ivh mysql-community-release-el7-5.noarch.rpm
yum install mysql-server -y
systemctl start mysqld
systemctl enable mysqld
echo -e "\nn\ny\nroot\nroot\ny\nn\ny\ny" | /usr/bin/mysql_secure_installation
mysqladmin -u root password root
mysql -uroot -proot -e "create database ambari";
mysql -uroot -proot -e "create database hive";
mysql -uroot -proot -e "create database oozie";
mysql -uroot -proot -e "create user ambari@'%' identified by 'bigdata'";
mysql -uroot -proot -e "create user hive@'%' identified by 'bigdata'";
mysql -uroot -proot -e "create user oozie@'%' identified by 'bigdata'";
mysql -uroot -proot -e "grant all privileges on *.* to ambari@'%' identified by 'bigdata' with grant option";
mysql -uroot -proot -e "grant all privileges on *.* to hive@'%' identified by 'bigdata' with grant option";
mysql -uroot -proot -e "grant all privileges on *.* to oozie@'%' identified by 'bigdata' with grant option";
mysql -uroot -proot -e "grant all privileges on *.* to root@'%' identified by 'root' with grant option";
mysql -uroot -proot -e "commit";
wget -nv http://public-repo-1.hortonworks.com/ambari/centos7/2.x/updates/2.6.2.0/ambari.repo -O /etc/yum.repos.d/ambari.repo
yum install ambari-server -y
yum install ambari-agent -y
echo -e "\nn\n1\ny\ny\n3\n\n\n\n\n\ny" | ambari-server setup
mysql -uroot -proot ambari < /var/lib/ambari-server/resources/Ambari-DDL-MySQL-CREATE.sql
ambari-server start
ambari-server setup --jdbc-db=mysql --jdbc-driver=/usr/share/java/mysql-connector-java.jar
#sed -i.bak 's/localhost/10.248.12.249/g' /etc/ambari-agent/conf/ambari-agent.ini
ambari-server restart
ambari-agent start
echo "Do changes of hostname in /etc/ambari-agent/conf/ambari-agent.ini and reboot"
echo "After reboot verify ambari-server and Ambari-agent services are running fine or not"
#reboot
#sed -i.bak 's/localhost/10.248.12.249/g' /etc/ambari-agent/conf/ambari-agent.ini
#ambari-server status
#ambari-agent status
#
