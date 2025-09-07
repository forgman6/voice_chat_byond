# TODO

- [x] clean up voicechat.js
- [x] port tools
- [x] byond remove rooms
- [x] node remove rooms
- [x] get mute deafen working again, 
- [x] switch track to null if not sending
- [x] fix audio playback
- [x] clean up code for when a browser gets closed
- [x] clean up code for when byond gets closed
- [x] remove incorrect io.to function
- [x] make invalid sessions disconnect
- [x] optimize the neighbor function.
- [x] set it up so it works outside of localhost
- [x] test over non localhost
- [x] make location shit tick every 300 ms 
- [x] add room var to client that gets treated like zlevel.
- [x] clean up add dummy client so it only exist when in debug mode
- [x] fixed mic access condition
- [x] test rooms outside localhost  
- [x] update disconnect to update with message to user
- [x] increase updates
- [x] make the speaking ui's only appear only to those connected to voicechat and on the same zlevel/room
    1. [x] instead making and deleting the image change the opacity. 
    2. [x] figure out if you make overlays only visible to some or you need to use client.images
    3. [x] for everyone in a room, keep a list of the userCodes so you can use it for the overlays
- [x] add map elements to change your room and change the color of the player to show it
- [x] add in game instructions.
- [x] add mute mob client side
- [x] restructure files
- [x] update node to open named socket inside root
- [x] update node to delete existing socket if exist inside root
- [x] fix pipe lib to work better with tgs
- [x] fix up byond install
- [x] make alternative for when link() dont work
- [x] readd try mic access again
- [ ] add mute mob byond side
- [ ] see if its possible to make and enforce listen only connections for people who cant speak ingame.