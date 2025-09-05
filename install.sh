#!/bin/bash
set -e  

PROJECT_NAME=$(basename "$PWD")
BYOND_MAJOR="516"
BYOND_MINOR="1667"

echo "Starting build process for project: $PROJECT_NAME"

echo "Adding i386 architecture and updating packages..."
sudo dpkg --add-architecture i386
sudo apt update
sudo apt upgrade -y
sudo apt install -y libc6:i386 libstdc++6:i386 libgcc1:i386 zlib1g:i386 zip gcc-multilib wget make curl:i386 g++ g++-multilib npm

echo "Installing BYOND version ${BYOND_BUILD}..."
if [ -d "$HOME/BYOND/byond/bin" ] && grep -Fxq "${BYOND_MAJOR}.${BYOND_MINOR}" $HOME/BYOND/version.txt;
then
    echo "Using cached directory."
else
    echo "Setting up BYOND."
    rm -rf "$HOME/BYOND"
    mkdir -p "$HOME/BYOND"
    cd "$HOME/BYOND"
    if ! curl --connect-timeout 2 --max-time 8 "https://spacestation13.github.io/byond-builds/${BYOND_MAJOR}/${BYOND_MAJOR}.${BYOND_MINOR}_byond_linux.zip" -o byond.zip -A "GitHub Actions/1.0"; then
        echo "Mirror download failed, falling back to byond.com"
        if ! curl --connect-timeout 2 --max-time 8 "http://www.byond.com/download/build/${BYOND_MAJOR}/${BYOND_MAJOR}.${BYOND_MINOR}_byond_linux.zip" -o byond.zip -A "GitHub Actions/1.0"; then
            echo "BYOND download failed too :("
            exit 1
        fi
    fi
    unzip byond.zip
    rm byond.zip
    cd byond
    sudo make install
    echo "$BYOND_MAJOR.$BYOND_MINOR" > "$HOME/BYOND/version.txt"
    cd ~/${PROJECT_NAME}
fi

echo "Building Node.js components..."
cd voicechat/node
npm install
echo "Building shared library..."
cd ../pipes && make
echo "Build process completed successfully."


