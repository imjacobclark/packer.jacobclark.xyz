# Create swap file
fallocate -l 4G /swapfile
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
echo "vm.swappiness=10" >> /etc/sysctl.conf

# Install Docker Engine
echo "Bringing up the Docker engine"
apt-get update
apt-get install -y apt-transport-https ca-certificates curl
apt-key adv --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys 58118E89F3A912897C070ADBF76221572C52609D
echo "deb https://apt.dockerproject.org/repo ubuntu-xenial main" > /etc/apt/sources.list.d/docker.list
apt-get update
apt-get purge lxc-docker
apt-get install -y linux-image-extra-$(uname -r) linux-image-extra-virtual
apt-get install -y docker-engine
service docker start

# Set up Caddy
echo "Bringing up Caddy"
curl https://getcaddy.com | bash -s cors,filemanager,git,hugo,ipfilter,minify,prometheus,ratelimit,realip,search,upload,mailout,digitalocean
groupadd -g 33 www-data
useradd -g www-data --no-user-group --home-dir /var/www --no-create-home --shell /usr/sbin/nologin --system --uid 33 www-data
mkdir /etc/caddy
chown -R root:www-data /etc/caddy
mkdir /etc/ssl/caddy
chown -R www-data:root /etc/ssl/caddy
chmod 0770 /etc/ssl/caddy
touch /var/log/access.log
chown -R www-data:www-data /var/log/access.log

# Enable startup provisioner
echo "Bringing up systemd"
systemctl daemon-reload
systemctl enable startup-provisioner.service
systemctl start caddy.service
systemctl enable caddy.service

# Set up blog
apt-get -y install ruby ruby-dev make gcc nodejs
gem install jekyll github-pages --no-rdoc --no-ri
git clone https://github.com/imjacobclark/blog.jacobclark.xyz.git /etc/blog.jacobclark.xyz
adduser --disabled-password --gecos "" jekyll
chown jekyll:jekyll /etc/blog.jacobclark.xyz

# Spin up containers
echo "Bringing up monitoring container infrastructure"
docker run --restart=always -d --name=grafana -p 3006:3000 grafana/grafana
docker run --restart=always --volume=/:/rootfs:ro --volume=/var/run:/var/run:rw --volume=/sys:/sys:ro --volume=/var/lib/docker/:/var/lib/docker:ro --publish=8080:8080 --detach=true --name=cadvisor google/cadvisor:latest
docker run --restart=always -d --name=prometheus -p 9090:9090 -v /etc/prometheus.yml:/etc/prometheus/prometheus.yml prom/prometheus -config.file=/etc/prometheus/prometheus.yml -storage.local.path=/prometheus -storage.local.memory-chunks=10000
docker run --restart=always -d --name=node-exporter -p 9100:9100 -v "/proc:/host/proc" -v "/sys:/host/sys" -v "/:/rootfs" --net="host" prom/node-exporter -collector.procfs /host/proc -collector.sysfs /host/proc -collector.filesystem.ignored-mount-points "^/(sys|proc|dev|host|etc)($|/)"

# Spin up containers
echo "Bringing up main container infrastructure"
docker run --restart=always -d -p 3000:8080 --name jacobclark.xyz imjacobclark/jacobclark.xyz
docker run --restart=always -d -p 3001:3000 --name ngaas.jacobclark.xyz imjacobclark/ngaas
docker run --restart=always -d -p 3002:3000 --name api.devnews.today imjacobclark/devnews-core
docker run --restart=always -d -p 3003:3000 --name devnews.today imjacobclark/devnews-web
docker run --restart=always -d -p 3004:3000 --name cors-container imjacobclark/cors-container
