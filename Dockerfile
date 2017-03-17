FROM debian:jessie-slim

LABEL maintainer="contact@ocsinventory-ng.org"
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

RUN chmod -R +w /var/lib/ocsinventory-reports ;\
    chown www-data: -R /var/lib/ocsinventory-reports

COPY dbconfig.inc.php /usr/share/ocsinventory-reports/ocsreports/

RUN cp binutils/ipdiscover-util.pl /usr/share/ocsinventory-reports/ocsreports/ipdiscover-util.pl

RUN chown www-data: /usr/share/ocsinventory-reports/ocsreports/ipdiscover-util.pl ;\
    chmod 755 /usr/share/ocsinventory-reports/ocsreports/ipdiscover-util.pl ;\
    chmod +w /usr/share/ocsinventory-reports/ocsreports/dbconfig.inc.php ;\
    mkdir -p /var/log/ocsinventory-server/ ;\
    chmod +w /var/log/ocsinventory-server ;\
    chown -R www-data: /usr/share/ocsinventory-reports/

COPY /conf/ocsinventory-reports.conf /etc/apache2/conf-available/
COPY /conf/z-ocsinventory-server.conf /etc/apache2/conf-available/


COPY ./scripts/run.sh /root/run.sh
RUN chmod +x /root/run.sh


RUN ln -s /etc/apache2/conf-available/ocsinventory-reports.conf /etc/apache2/conf-enabled/ocsinventory-reports.conf
RUN ln -s /etc/apache2/conf-available/z-ocsinventory-server.conf /etc/apache2/conf-enabled/z-ocsinventory-server.conf

RUN rm /usr/share/ocsinventory-reports/ocsreports/install.php ;\
    rm -rf /tmp/ocs ;\
    apt-get clean ;\
    apt-get autoclean ;\
    apt-get autoremove ;\
    rm -rf /var/cache/apt/archives/* ;

EXPOSE 80
RUN useradd mysql
COPY /lib/libaio.so.1 /lib
COPY /lib/libcrypt.so.1 /lib
COPY /lib/libstdc++.so.6 /lib
COPY /lib/libgcc_s.so.1 /lib
COPY /lib/libfreebl3.so /lib
COPY /lib/libncurses.so.5 /lib
RUN cd /tmp/ocs
RUN wget http://ftp.ntu.edu.tw/MySQL/Downloads/MySQL-5.7/mysql-5.7.16-linux-glibc2.5-x86_64.tar.gz
RUN tar zxvf mysql-5.7.16-linux-glibc2.5-x86_64.tar.gz
RUN mv mysql-5.7.16-linux-glibc2.5-x86_64 mysql
RUN rm -rf mysql-5.7.16*.*
RUN mkdir /tmp/ocs/mysql/sql_data
RUN echo "[server]" > /tmp/ocs/my.cnf
RUN echo "user=mysql" >> /tmp/ocs/my.cnf
RUN echo "basedir=/tmp/ocs/mysql" >> /tmp/ocs/my.cnf
RUN echo "datadir=/tmp/ocs/mysql/sql_data" >> /tmp/ocs/my.cnf
RUN echo "port=3306" >> /tmp/ocs/my.cnf
RUN echo "update mysql.user set authentication_string=password('rootpass') , password_expired='N' where user='root';" > /tmp/ocs/pass.sql
RUN echo "update mysql.user set  host='%' where user='root';" >> /tmp/ocs/pass.sql
RUN echo "flush privileges;" >> /tmp/ocs/pass.sql
RUN echo '#!/bin/sh' > /tmp/ocs/start.sh
RUN echo "cd /tmp/ocs/mysql;./bin/mysqld  --defaults-file=/tmp/ocs/my.cnf --initialize-insecure" >> /tmp/ocs/start.sh
RUN echo "cd /tmp/ocs/mysql;./bin/mysqld_safe --defaults-file=/tmp/ocs/my.cnf  --init-file=/tmp/ocs/pass.sql &" >>/tmp/ocs/start.sh
RUN chmod +x /tmp/ocs/start.sh
RUN chown -R mysql:mysql /tmp/ocs
CMD ["/bin/bash", "/root/run.sh"]
