#!/bin/bash
if [ ! -d "$APACHE_RUN_DIR" ]; then
	mkdir "$APACHE_RUN_DIR"
	chown $APACHE_RUN_USER:$APACHE_RUN_GROUP "$APACHE_RUN_DIR"
fi
if [ -f "$APACHE_PID_FILE" ]; then
	rm "$APACHE_PID_FILE"
fi
su - mysql -c /tmp/ocs/start.sh
sudo setcap 'cap_net_bind_service=+ep' /usr/sbin/apache2
sudo /etc/init.d/apache2 stop
sudo chown -R www-data: /var/{log,run}/apache2/
sudo -u www-data /usr/sbin/apache2ctl -D FOREGROUND
