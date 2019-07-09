#!/bin/bash
# THIS SCRIPT IS WRITTEN BY Agus Prasetyo
# Email : agus@jobindo.com
clear
		echo "What do you want to do?"
		echo "   1) Install Direct Admin"
		echo "   2) Install Let's Encrypt"
  		echo "   3) Install Hostname SSL"
		read -p "Select an option [1-3]: " option
		case $option in
    case $option in
			1) 
service firewalld stop;
systemctl disable firewalld;
yum install wget gcc gcc-c++ flex bison make bind bind-libs bind-utils openssl openssl-devel perl quota libaio libcom_err-devel libcurl-devel gd zlib-devel zip unzip libcap-devel cronie bzip2 cyrus-sasl-devel perl-ExtUtils-Embed autoconf automake libtool which patch mailx bzip2-devel lsof glibc-headers kernel-devel expat-devel -y;yum install psmisc net-tools systemd-devel libdb-devel perl-DBI perl-Perl4-CoreLibs xfsprogs rsyslog logrotate crontabs file kernel-headers -y;
wget https://www.directadmin.com/setup.sh;
bash setup.sh;
exit
			;;
			
      2)
            echo 'letsencrypt=1'>>/usr/local/directadmin/conf/directadmin.conf;
            service directadmin restart;
            cd /usr/local/directadmin/custombuild;
            ./build rewrite_confs;
            cd /usr/local/directadmin/custombuild;
            ./build update;
            ./build letsencrypt;
            service directadmin restart;
exit
			;;
			
      3)

echo -ne "Please type your hostname: "
read HOSTNAME
cd /usr/local/directadmin/scripts;./letsencrypt.sh request_single $HOSTNAME 4096;cd /usr/local/directadmin/conf;perl -pi -e 's/SSL=0/SSL=1/' directadmin.conf;echo "carootcert=/usr/local/directadmin/conf/carootcert.pem" >> directadmin.conf;echo "force_hostname=$HOSTNAME" >> directadmin.conf;echo "ssl_redirect_host=$HOSTNAME" >> directadmin.conf;service directadmin restart;
exit;;
		esac
	done
			
