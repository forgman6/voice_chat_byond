# one liner to test shit on WSL

* [about wsl](https://learn.microsoft.com/en-us/windows/wsl/install)

    ```bash
    wsl --install debian
    ```

* run from wsl, if using github desktop, folder should be in right place. if not correct.

    ```bash
    cd ~ && \
    windows_user=$(cmd.exe /c echo %USERNAME% | tr -d '\r') && \
    sudo apt install rsync dos2unix && \
    sudo rm -rf ~/voice_chat_byond && \
    cd "/mnt/c/Users/$windows_user/Documents/GitHub/voice_chat_byond" && \
    rsync -av --progress --exclude='/.git' --filter="dir-merge,- .gitignore" ./ ~/voice_chat_byond/ &&\
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
