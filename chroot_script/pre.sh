mount none -t proc /proc &>> /dev/null
mount none -t sysfs /sys &>> /dev/null
mount none -t devpts /dev/pts &>> /dev/null
export HOME=/root
export LC_ALL=C
source /tmp/envs.sh
mkdir -p /iso
echo "Live-CD" > /etc/hostname
source /etc/os-release
echo "nameserver 8.8.8.8
nameserver 1.1.1.1
search lan" > /etc/resolv.conf
apt install wget curl -y &>> /dev/null

mv -fv /etc/apt/sources.list /tmp/old-sources.list
echo "https://raw.githubusercontent.com/Sirherobrine23/Debian_ISO/main/debian_sources/$ID-$VERSION_ID.list"
curl "https://raw.githubusercontent.com/Sirherobrine23/Debian_ISO/main/debian_sources/$ID-$VERSION_ID.list" |sed "s|R_U|${R_U}|g" > /etc/apt/sources.list

echo "::group::Update Repository"
    apt update
echo "::endgroup::"

apt install -y dbus-tests &>> /dev/null
apt install -y systemd-sysv &>> /dev/null

dbus-uuidgen > /etc/machine-id
ln -fs /etc/machine-id /var/lib/dbus/machine-id

dpkg-divert --local --rename --add /sbin/initctl
ln -s /bin/true /sbin/initctl

if [ $ID == "debian" ];then
    kernelL="linux-headers-amd64 linux-image-amd64"
else
    kernelL="ubuntu-standard linux-generic"
fi
for installer in $kernelL discover resolvconf wpagui locales laptop-detect wireless-tools casper lupin-casper git net-tools curl wget git zip unzip curl vim nano os-prober network-manager apt-transport-https
do
    echo "::group::Installing: $installer"
    apt install -y $installer
    echo "::endgroup::"
done
echo "::group::Installing: Visual studio code insider"
    wget -q "https://code.visualstudio.com/sha/download?build=insider&os=linux-deb-x64" -O /tmp/code.deb
    dpkg -i /tmp/code.deb
echo "::endgroup::"
username='ubuntu'
password='12345678'
pass=$(perl -e 'print crypt($ARGV[0], "password")' $password)
useradd -m -p "$pass" "$username"
addgroup ubuntu sudo
usermod --shell /bin/bash ubuntu
echo "Live CD login:
Username: Ubuntu
Passworld: 12345678" >> /etc/issue
apt --fix-broken install -y &>> /iso/brokens.txt
apt autoremove -y &>> /iso/autoremove.txt
echo "[main]
rc-manager=resolvconf
plugins=ifupdown,keyfile
dns=dnsmasq
[ifupdown]
managed=false" > /etc/NetworkManager/NetworkManager.conf
dpkg-reconfigure network-manager &>> /dev/null

rm /sbin/initctl
dpkg-divert --rename --remove /sbin/initctl
exit