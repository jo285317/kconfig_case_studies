#!/bin/bash

set -x

sudo apt-get update

# dependencies for building axtls, toybox, fiasco
yes | sudo apt-get install python make gcc libreadline-dev libselinux1-dev libssl-dev libncurses5-dev patch liblua50-dev libpam0g-dev libdmalloc-dev electric-fence libdlib-dev libaudit-dev linux-source-4.4.0 g++-mips-linux-gnu cbmc cppcheck default-jdk

# smack dependencies for toybox
yes | sudo apt-get install autoconf libtool-bin

# install smack
cd /home/vagrant
git clone https://github.com/smack-team/smack
cd smack
./autogen.sh
make
sudo make install

# cross-compilation tools for fiasco
yes | sudo apt-get install g++-5-arm-linux-gnueabihf g++-aarch64-linux-gnu 

# dependencies for building linux
yes | sudo apt-get install libelf-dev build-essential libncurses-dev bison flex libssl-dev bc

# dependencies for java program to extract gcc args
sudo apt-get install openjdk-8-jre-headless

# allow user to add to /usr/local
sudo chgrp -R vagrant /usr/local; sudo chmod -R g+w /usr/local


# environment
echo 'export KCONFIG_CASE_STUDIES=/vagrant' > /home/vagrant/.bash_profile
echo 'export PATH=$KCONFIG_CASE_STUDIES/scripts:$PATH' >> /home/vagrant/.bash_profile
# prevent locale errors
echo "export LC_ALL=en_US.UTF-8" >> /home/vagrant/.bash_profile

# get source code and setup repos
cd /home/vagrant


# Install clang
wget -O - https://apt.llvm.org/llvm-snapshot.gpg.key|sudo apt-key add -
sudo apt-add-repository "deb http://apt.llvm.org/xenial/ llvm-toolchain-xenial-7 main"
sudo apt-get update
yes | sudo apt-get install clang-7
sudo ln -s /usr/bin/clang-7 /usr/bin/clang

# Install pyenv
curl https://pyenv.run > /home/vagrant/setup_pyenv.sh
sudo chmod +x /home/vagrant/setup_pyenv.sh
/home/vagrant/setup_pyenv.sh
echo 'export PATH="$HOME/.pyenv/bin:$PATH"' >> ~/.bashrc
echo 'eval "$(pyenv init -)"' >> ~/.bashrc
echo 'eval "$(pyenv virtualenv-init -)"' >> ~/.bashrc
rm /home/vagrant/setup_pyenv.sh

pyenv install 3.7.0
pyenv global 3.7.0

# Copy README and license info
cp /vagrant/.vagrant_resources/* ~
sudo apt-get install python-pip python-dev build-essential
sudo pip install kmaxtools
echo 'export export PATH=$PATH:/usr/local/bin/' >> /home/vagrant/.bash_profile

# Force vagrant to read ~/.bashrc
echo "source ~/.bashrc" >> /home/vagrant/.bash_profile
