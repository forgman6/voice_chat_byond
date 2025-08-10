echo adding packages...
sudo dpkg --add-architecture i386
sudo apt update && sudo apt upgrade
sudo apt install libc6:i386 libstdc++6:i386 libgcc1:i386 zlib1g:i386 zip gcc-multilib nodejs wget make  curl:i386 g++ g++-multilib
echo installing byond...
cd ..
wget https://www.byond.com/download/build/516/516.1666_byond_linux.zip
unzip *_byond_linux.zip && rm *_byond_linux.zip
cd byond && sudo make install
cd ../voice_chat
echo building node...
cd webrtc
npm install
echo building shared library...
cd  ../pipes/linux && make
echo building dm...
cd ../../ && DreamMaker voice_chat.dme -clean
echo done