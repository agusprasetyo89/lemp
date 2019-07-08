#!/bin/bash
# THIS SCRIPT IS WRITTEN BY Agus Prasetyo
# Email : agus@jobindo.com
service firewalld stop;
systemctl disable firewalld;
yum install wget gcc gcc-c++ flex bison make bind bind-libs bind-utils openssl openssl-devel perl quota libaio libcom_err-devel libcurl-devel gd zlib-devel zip unzip libcap-devel cronie bzip2 cyrus-sasl-devel perl-ExtUtils-Embed autoconf automake libtool which patch mailx bzip2-devel lsof glibc-headers kernel-devel expat-devel -y;yum install psmisc net-tools systemd-devel libdb-devel perl-DBI perl-Perl4-CoreLibs xfsprogs rsyslog logrotate crontabs file kernel-headers -y;wget https://www.directadmin.com/setup.sh;bash setup.sh;

