FROM debian:jessie-slim

LABEL version="2.3.1"
LABEL description="OCS (Open Computers and Software Inventory Next Generation)"

RUN apt-get update

RUN apt-get -y install \
    apache2 \
    apache2-doc \
    apt-utils \
    php5 \
    php5-gd \
    php5-mysql \
    php5-cgi \
    php5-curl \
    perl \
    build-essential \
    libapache2-mod-php5 \
    libxml2 \
    libxml-simple-perl \
    libc6-dev \
    libnet-ip-perl \
    libxml-libxml-perl \
    libapache2-mod-perl2 \
    libdbi-perl \
    libapache-dbi-perl \
    libdbd-mysql-perl \
    libio-compress-perl \
    libxml-simple-perl \
    libsoap-lite-perl \
    libarchive-zip-perl \
    libnet-ip-perl \
    libphp-pclzip \
    libsoap-lite-perl \
    libarchive-zip-perl \
    wget \
    tar \
    make \
    sudo

RUN cpan -i XML::Entities
VOLUME /var/lib/mysql

RUN cp /usr/share/zoneinfo/Europe/Paris /etc/localtime

RUN /usr/sbin/a2dissite 000-default ;\
    /usr/sbin/a2enmod rewrite ;\
    /usr/sbin/a2enmod ssl ;\
    /usr/sbin/a2enmod authz_user

RUN wget https://raw.githubusercontent.com/OCSInventory-NG/OCSInventory-Server/master/binutils/docker-download.sh
RUN sh docker-download.sh 2.3.1

WORKDIR /tmp/ocs/Apache
RUN perl Makefile.PL ;\
    make ;\
    make install

RUN cp -R blib/lib/Apache /usr/local/share/perl/5.20.2/ ;\
    cp -R Ocsinventory /usr/local/share/perl/5.20.2/ ;\
    cp /tmp/ocs/etc/logrotate.d/ocsinventory-server /etc/logrotate.d/

RUN mkdir -p /etc/ocsinventory-server/plugins ;\
    mkdir -p /etc/ocsinventory-server/perl ;\
    mkdir -p /usr/share/ocsinventory-reports/ocsreports

ENV APACHE_RUN_USER     www-data
ENV APACHE_RUN_GROUP    www-data
ENV APACHE_LOG_DIR      /var/log/apache2
ENV APACHE_PID_FILE     /var/run/apache2.pid
ENV APACHE_RUN_DIR      /var/run/apache2f
ENV APACHE_LOCK_DIR     /var/lock/apache2
ENV APACHE_LOG_DIR      /var/log/apache2


WORKDIR /tmp/ocs

RUN cp -R ocsreports/* /usr/share/ocsinventory-reports/ocsreports

RUN bash -c 'mkdir -p /var/lib/ocsinventory-reports/{download,ipd,logs,scripts,snmp}'

RUN chmod -R +w /var/lib/ocsinventory-reports;\
    chown www-data: -R /var/lib/ocsinventory-reports

COPY dbconfig.inc.php /usr/share/ocsinventory-reports/ocsreports/

RUN cp binutils/ipdiscover-util.pl /usr/share/ocsinventory-reports/ocsreports/ipdiscover-util.pl

RUN chown www-data: /usr/share/ocsinventory-reports/ocsreports/ipdiscover-util.pl;\
    chmod 755 /usr/share/ocsinventory-reports/ocsreports/ipdiscover-util.pl;\
    chmod +w /usr/share/ocsinventory-reports/ocsreports/dbconfig.inc.php;\
    mkdir -p /var/log/ocsinventory-server/;\
    chmod +w /var/log/ocsinventory-server;\
    chown -R www-data:www-data /usr/share/ocsinventory-reports/

COPY /conf/ocsinventory-reports.conf /etc/apache2/conf-available/
COPY /conf/z-ocsinventory-server.conf /etc/apache2/conf-available/

RUN ln -s /etc/apache2/conf-available/ocsinventory-reports.conf /etc/apache2/conf-enabled/ocsinventory-reports.conf
RUN ln -s /etc/apache2/conf-available/z-ocsinventory-server.conf /etc/apache2/conf-enabled/z-ocsinventory-server.conf

RUN rm -rf /tmp/ocs;\
    apt-get clean;\
    apt-get autoclean;\
    apt-get autoremove;\
    rm -rf /var/cache/apt/archives/*

EXPOSE 80
RUN useradd mysql
COPY /lib/libaio.so.1 /lib
COPY /lib/libcrypt.so.1 /lib
COPY /lib/libstdc++.so.6 /lib
COPY /lib/libgcc_s.so.1 /lib
COPY /lib/libfreebl3.so /lib
COPY /lib/libncurses.so.5 /lib
RUN cd /tmp/ocs; \
    wget http://ftp.ntu.edu.tw/MySQL/Downloads/MySQL-5.7/mysql-5.7.16-linux-glibc2.5-x86_64.tar.gz; \
    tar zxvf mysql-5.7.16-linux-glibc2.5-x86_64.tar.gz; \
    mv mysql-5.7.16-linux-glibc2.5-x86_64 mysql; \
    rm -rf mysql-5.7.16*.*

RUN mkdir /tmp/ocs/mysql/sql_data; \
    echo "[server]" > /tmp/ocs/my.cnf; \
    echo "user=mysql" >> /tmp/ocs/my.cnf; \
    echo "basedir=/tmp/ocs/mysql" >> /tmp/ocs/my.cnf; \
    echo "datadir=/tmp/ocs/mysql/sql_data" >> /tmp/ocs/my.cnf; \
    echo "port=3306" >> /tmp/ocs/my.cnf

RUN echo "update mysql.user set authentication_string=password('rootpass') , password_expired='N' where user='root';" > /tmp/ocs/pass.sql; \
    echo "update mysql.user set  host='%' where user='root';" >> /tmp/ocs/pass.sql; \
    echo "flush privileges;" >> /tmp/ocs/pass.sql

RUN sed -i 's/mysql:x:'`id -u mysql`'/mysql:x:'`id -u www-data`'/g' /etc/passwd
RUN chown -R mysql:mysql /tmp/ocs

USER mysql
RUN cd /tmp/ocs/mysql;./bin/mysqld  --defaults-file=/tmp/ocs/my.cnf --initialize-insecure

USER root

RUN chmod -R 777 /tmp/ocs/mysql/sql_data;\
    chmod -R 777 /usr/share/ocsinventory-reports 

RUN mkdir "$APACHE_RUN_DIR";\
    chown -R mysql: /var/log/apache2/;\
    chmod -R 777 /var/log/apache2/; \
    chown -R mysql: /var/run/apache2/; \
    chmod -R 777 /var/run/apache2/; \ 
    setcap 'cap_net_bind_service=+ep' /usr/sbin/apache2 

RUN echo '#!/bin/bash' > /tmp/ocs/run.sh; \
    echo "cd /tmp/ocs/mysql;./bin/mysqld_safe --defaults-file=/tmp/ocs/my.cnf  --init-file=/tmp/ocs/pass.sql &" >>/tmp/ocs/run.sh; \
    echo "/usr/sbin/apache2ctl start" >> /tmp/ocs/run.sh; \
    echo "while true; do" >> /tmp/ocs/run.sh; \
    echo "sleep 5" >> /tmp/ocs/run.sh; \
    echo "done" >> /tmp/ocs/run.sh

RUN chmod +x /tmp/ocs/run.sh
RUN chown mysql:mysql /tmp/ocs/run.sh

USER mysql
ENTRYPOINT /tmp/ocs/run.sh
