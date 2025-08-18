#!/bin/bash
set -e  

PROJECT_NAME=$(basename "$PWD")
BYOND_VERSION="516"
BYOND_BUILD="516.1666"
BYOND_ZIP="${BYOND_BUILD}_byond_linux.zip"
BYOND_URL="https://www.byond.com/download/build/${BYOND_VERSION}/${BYOND_ZIP}"

echo "Starting build process for project: $PROJECT_NAME"

echo "Adding i386 architecture and updating packages..."
sudo dpkg --add-architecture i386
sudo apt update
sudo apt upgrade -y
sudo apt install -y libc6:i386 libstdc++6:i386 libgcc1:i386 zlib1g:i386 zip gcc-multilib nodejs npm wget make curl:i386 g++ g++-multilib

echo "Installing BYOND version ${BYOND_BUILD}..."
cd ..

wget "$BYOND_URL" 
unzip "$BYOND_ZIP" && rm "$BYOND_ZIP"
cd byond && sudo make install

echo "copying byondapi..."
cp byondapi/*.h "../${PROJECT_NAME}/pipes"
cp byondapi/*.cpp "../${PROJECT_NAME}/pipes"
cd "../${PROJECT_NAME}"

echo "Building Node.js components..."
cd webrtc
npm install
echo "Building shared library..."
cd ../pipes && make

echo "Building DM project..."
cd ..
DreamMaker "${PROJECT_NAME}.dme" -clean

echo "Build process completed successfully."