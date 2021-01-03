#!/bin/bash
echo "server {
	listen 80 default_server;
	listen [::]:80 default_server;
	root $PWD;
	index index.html;
	server_name _;
	location / {
		autoindex on;
	}
}" | tee /etc/nginx/sites-available/default
echo "Nginx Local  http://127.0.0.1:80"
echo "Nginx Local  http://localhost:80"
echo "Restarting the nginx service"
service nginx restart
# -------------
echo "Removing unused packages"
apt-get autoremove --purge -y
exit