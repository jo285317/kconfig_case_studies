#!/bin/bash

set -x

sudo apt-get update

# dependencies for building axtls, toybox, fiasco
yes | sudo apt-get install go wget xz-utils cmake python autoconf automake freetype-dev linux-headers
yes | sudo apt-get install make g++ git zlib1g-dev libncurses5-dev libssl-dev libpcre2-dev zip vim
yes | sudo apt-get install python python3 python-pip python-dev build-essential make gcc libreadline-dev libselinux1-dev libssl-dev libncurses5-dev patch liblua50-dev libpam0g-dev libdmalloc-dev electric-fence libdlib-dev libaudit-dev linux-source-4.4.0 g++-mips-linux-gnu cbmc cppcheck default-jdk



# dependencies for building linux

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

#set-up llvm
wget http://llvm.org/releases/9.0.0/llvm-9.0.0.src.tar.xz
wget http://llvm.org/releases/9.0.0/cfe-9.0.0.src.tar.xz
tar xf llvm-9.0.0.src.tar.xz
tar xf cfe-9.0.0.src.tar.xz
mv cfe-9.0.0.src llvm-9.0.0.src/tools/clang
mkdir llvm-9.0.0.obj
cd llvm-9.0.0.obj
cmake -DCMAKE_BUILD_TYPE=MinSizeRel ../llvm-9.0.0.src 
make -j32  
cd /home/vagrant
mkdir llvm-9.0.0.dbj
cd llvm-9.0.0.dbj
cmake -DCMAKE_BUILD_TYPE:STRING=Debug ../llvm-9.0.0.src 
make -j32
cd /home/vagrant
git clone https://github.com/SVF-tools/SVF.git SVF
cd SVF
LLVMRELEASE=/home/vagrant/llvm-9.0.0/llvm-9.0.0.obj
LLVMDEBUG=/home/vagrant/llvm-9.0.0/llvm-9.0.0.dbg

bash ./build.sh
#bash ./build.sh debug
cd /home/vagrant
# Copy README and license info
cp /vagrant/.vagrant_resources/* ~

# Force vagrant to read ~/.bashrc
echo "source ~/.bashrc" >> /home/vagrant/.bash_profile
