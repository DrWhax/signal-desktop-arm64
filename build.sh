#!/bin/bash

# Builds Signal Private Messenger Desktop Beta for Linux.
# This is built on a m6g.large EC2 instance running Ubuntu 18.04.
#
# Mostly based out of everyone contributing tips here: https://github.com/signalapp/Signal-Desktop/issues/3410
#
# This will not currently lead to a working build, misses building the beta dependencies for arm64 currently.
#

sudo apt update

# Install dependencies
sudo apt install libvips build-essential g++ flex bison gperf ruby perl \
libsqlite3-dev libfontconfig1-dev libicu-dev libfreetype6 libssl-dev \
libpng-dev libjpeg-dev python libx11-dev libxext-dev libssl-dev \
cargo cmake qt5-default libqt5webkit5-dev virtualenv\
apt-transport-https ca-certificates curl gnupg-agent software-properties-common \
make -yq

# install nodejs seperately

sudo apt install nodejs npm -yq


# FPM needs libruby-dev
sudo apt install libruby-dev -yq

# We need this to build the final .deb

sudo gem install fpm

# Install nvm

wget -qO- https://raw.githubusercontent.com/nvm-sh/nvm/v0.35.3/install.sh | bash

# Activate nvm
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm

# Install older node
nvm install 12.13.0

# Install npm stuff
npm i -g npm yarn

# downloading some patches

wget -q "https://gitlab.com/ohfp/pinebookpro-things/-/raw/master/signal-desktop/expire-from-source-date-epoch.patch?inline=false" -O expire-from-source-date-epoch.patch

wget -q "https://gitlab.com/ohfp/pinebookpro-things/-/raw/master/signal-desktop/openssl-linking.patch?inline=false" -O openssl-linking.patch

# downloading packages
wget https://github.com/atom/node-spellchecker/archive/613ff91dd2d9a5ee0e86be8a3682beecc4e94887.tar.gz
git clone https://github.com/signalapp/signal-zkgroup-node.git zkgroup
git clone https://github.com/signalapp/zkgroup.git libzkgroup
git clone --depth=1 --branch updates https://github.com/scottnonnenberg-signal/node-sqlcipher.git sqlcipher
cd /home/ubuntu/sqlcipher
git checkout updates
patch -Np3 -i ../openssl-linking.patch

# make libzkgroup
cd /home/ubuntu/libzkgroup
make libzkgroup
cp target/release/libzkgroup.so /home/ubuntu/zkgroup/libzkgroup.so
cp target/release/libzkgroup.so /home/ubuntu/libzkgroup/libzkgroup.so

cd $HOME

# git clone signal
git clone https://github.com/signalapp/Signal-Desktop.git

cd /home/ubuntu/Signal-Desktop

# Select node-gyp versions with python3 support
sed 's#"node-gyp": "5.0.3"#"node-gyp": "6.1.0"#' -i package.json
# https://github.com/sass/node-sass/pull/2841
# https://github.com/sass/node-sass/issues/2716
sed 's#"resolutions": {#"resolutions": {"node-sass/node-gyp": "^6.0.0",#' -i package.json

# Fix spellchecker in sqlcipher
sed -r 's#("spellchecker": ").*"#\1file:'"/home/ubuntu"'/613ff91dd2d9a5ee0e86be8a3682beecc4e94887.tar.gz"#' -i package.json

# Adjust sqlcipher thingie
sed -r 's#("@journeyapps/sqlcipher": ").*"#\1file:../sqlcipher"#' -i package.json

# Adjust thingies from sqlcipher
sed -r 's#("zkgroup": ").*"#\1file:../zkgroup"#' -i package.json

# Adjust thingies from zkgroup
sed 's#"ffi-napi": "2.4.5"#"ffi-napi": ">=2.4.7"#' -i /home/ubuntu/zkgroup/package.json

nvm use

[[ $CARCH == "aarch64"  ]] && CFLAGS=`echo $CFLAGS | sed -e 's/-march=armv8-a//'` && CXXFLAGS="$CFLAGS"

export USE_SYSTEM_FPM="true"

# We can't read the release date from git so we use SOURCE_DATE_EPOCH instead
patch --forward --strip=1 --input="/home/ubuntu/expire-from-source-date-epoch.patch"

# building of signal-desktop

[[ $CARCH == "aarch64"  ]] && CFLAGS=`echo $CFLAGS | sed -e 's/-march=armv8-a//'` && CXXFLAGS="$CFLAGS"

  if [[ $CARCH == 'aarch64' ]]; then
    # otherwise, it'll try to run x86_64-fpm..
    export USE_SYSTEM_FPM="true"
  fi

yarn install --ignore-engines

yarn generate exec:build-protobuf exec:transpile concat copy:deps sass

yarn grunt

yarn build:webpack

yarn build-release --arm64 --linux --dir

exit 0
# EOF
