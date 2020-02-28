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
export LLVM_SRC=/home/vagrant/llvm-9.0.0/llvm-9.0.0.src
export LLVM_OBJ=/home/vagrant/llvm-9.0.0/llvm-9.0.0.obj
export LLVM_DIR=/home/vagrant/llvm-9.0.0/llvm-9.0.0.obj
export PATH=$LLVM_DIR/bin:$PATH

mkdir Release-build
cd Release-build
cmake ../
make -j4

#bash ./build.sh debug
cd /home/vagrant
# Copy README and license info
cp /vagrant/.vagrant_resources/* ~

# Force vagrant to read ~/.bashrc
echo "source ~/.bashrc" >> /home/vagrant/.bash_profile


# setup svf


export LLVM_OBJ_ROOT=/home/vagrant/llvm-9.0.0/llvm-9.0.0.obj

export PATH=$LLVM_OBJ_ROOT/bin:$PATH
export LLVM_DIR=$LLVM_OBJ_ROOT
#export LLVM_OBJ_ROOT=$LLVM_HOME/llvm-$llvm_version.dbg
#export PATH=$LLVM_OBJ_ROOT/Debug+Asserts/bin:$PATH
export LLVMOPT=opt
export CLANG=$LLVM_OBJ_ROOT/bin/clang
export CLANGCPP=$LLVM_OBJ_ROOT/bin/clang++
export LLVMDIS=llvm-dis
export LLVMLLC=llc

##############astyle code formatting###############
AstyleDir=/home/ysui/astyle/build/clang
export PATH=$AstyleDir/bin:$PATH

##############check what os we have
PLATFORM='unknown'
unamestr=`uname`
if [[ "$unamestr" == 'Linux' ]]; then
export PLATFORM='linux'
elif [[ "$unamestr" == 'Darwin' ]]; then
export PLATFORM='darwin'
elif [[ "$unamestr" == 'FreeBSD' ]]; then
export PLATFORM='freebsd'
fi


#########PATH FOR PTA##############                                                                 
export SVF_HOME=`pwd`
if [[ $1 == 'debug' ]]
then
PTAOBJTY='Debug'
else
PTAOBJTY='Release'
fi
Build=$PTAOBJTY'-build'
export SVF_HOME=`pwd`
export PTABIN=$SVF_HOME/$Build/bin
export PTALIB=$SVF_HOME/$Build/lib
export PTARTLIB=$SVF_HOME/lib/RuntimeLib
export PATH=$PTABIN:$PATH

export PTATEST=$SVF_HOME/PTABen
export PTATESTSCRIPTS=$PTATEST/scripts
export RUNSCRIPT=$PTATESTSCRIPTS/run.sh

