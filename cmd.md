# one liner to test shit on WSL

* [about wsl](https://learn.microsoft.com/en-us/windows/wsl/install)

```bash
    wsl --install debian
```

* change **spaceman** to your **windows username**

    ```bash
    cd ~ && \
    sudo apt install rsync dos2unix && \
    sudo rm -rf ~/voice_chat_byond && \
    cd /mnt/c/Users/spaceman/Documents/GitHub/voice_chat_byond && \
    rsync -av --progress --exclude='/.git' --filter="dir-merge,- .gitignore" ./ /home/a/voice_chat_byond/ &&\
    cd ~/voice_chat_byond && \
    dos2unix install.sh && \
    bash install.sh && \
    DreamMaker voice_chat_byond -clean && \
    DreamDaemon voice_chat_byond 1337 -trusted
    ```

* open [byond://localhost:1337](byond://localhost:1337) in **DreamSeeker** or if your lazy:

    ```bash
    DreamSeeker byond://localhost:1337
    ```
