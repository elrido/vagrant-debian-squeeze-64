#!/bin/sh

# passwordless sudo
echo "%sudo   ALL=NOPASSWD: ALL" >> /etc/sudoers

# public ssh key for vagrant user
mkdir /home/vagrant/.ssh
wget -O /home/vagrant/.ssh/authorized_keys "https://raw.github.com/mitchellh/vagrant/master/keys/vagrant.pub"
chmod 755 /home/vagrant/.ssh
chmod 644 /home/vagrant/.ssh/authorized_keys
chown -R vagrant:vagrant /home/vagrant/.ssh

# speed up ssh
echo "UseDNS no" >> /etc/ssh/sshd_config

# get chef
# http://wiki.opscode.com/display/chef/Installing+Chef+Client+on+Ubuntu+or+Debian
echo "deb http://apt.opscode.com/ squeeze-0.10 main" > /etc/apt/sources.list.d/opscode.list
mkdir -p /etc/apt/trusted.gpg.d
gpg --keyserver keys.gnupg.net --recv-keys 83EF826A
gpg --export packages@opscode.com > /etc/apt/trusted.gpg.d/opscode-keyring.gpg
apt-get update
apt-get install opscode-keyring
apt-get upgrade
echo "chef chef/chef_server_url string none" | debconf-set-selections && apt-get install chef -y

# display login promt after boot
sed "s/quiet splash//" /etc/default/grub > /tmp/grub
mv /tmp/grub /etc/default/grub
update-grub

# clean up
apt-get -y autoremove
apt-get clean
# fill the empty space with zeros
# takes quite long but results in much smaller vagrant box (ca. 300 vs 440 MiB)
sync
dd if=/dev/zero of=/zero bs=1M
rm -f /zero

