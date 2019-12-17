#!/bin/bash

set -x

sudo apt-get update

# dependencies for building axtls, toybox, fiasco
yes | sudo apt-get install python python-pip python-dev build-essential make gcc libreadline-dev libselinux1-dev libssl-dev libncurses5-dev patch liblua50-dev libpam0g-dev libdmalloc-dev electric-fence libdlib-dev libaudit-dev linux-source-4.4.0 g++-mips-linux-gnu cbmc cppcheck default-jdk

# smack dependencies for toybox
yes | sudo apt-get install autoconf libtool-bin
yes | sudo apt-get install python python-pip python-setuptools python-dev build-essential python3-pip
sudo pip install kmaxtools
sudo pip3 install scipy


# cross-compilation tools for fiasco

# dependencies for building linux
yes | sudo apt-get install libelf-dev build-essential libncurses-dev bison flex libssl-dev bc lzop

# dependencies for java program to extract gcc args
# sudo apt-get install openjdk-8-jre-headless

# allow user to add to /usr/local
sudo chgrp -R vagrant /usr/local; sudo chmod -R g+w /usr/local


# environment
echo 'export KCONFIG_CASE_STUDIES=/vagrant' > /home/vagrant/.bash_profile
echo 'export PATH=$KCONFIG_CASE_STUDIES/scripts:$PATH' >> /home/vagrant/.bash_profile
# prevent locale errors
echo "export LC_ALL=en_US.UTF-8" >> /home/vagrant/.bash_profile
echo 'export PATH=/usr/local/bin:$PATH' >> /home/vagrant/.bash_profile

# get source code and setup repos
cd /home/vagrant
git clone git://git.kernel.org/pub/scm/linux/kernel/git/next/linux-next.git
cd linux-next
git checkout next-20191211
wget https://kmaxtools.opentheblackbox.net/formulas/kmax-formulas_linux-next-20191211.tar.bz2
tar -xvf kmax-formulas_linux-next-20191211.tar.bz2
cd /home/vagrant


# Copy README and license info
cp /vagrant/.vagrant_resources/* ~

# Force vagrant to read ~/.bashrc
echo "source ~/.bashrc" >> /home/vagrant/.bash_profile
