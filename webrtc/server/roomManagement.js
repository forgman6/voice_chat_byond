const { userCodetoRoomName, rooms, userCodeToSocketId } = require('./state');
function joinInitialRoom(userCode, roomName = 'NONE') {
    userCodetoRoomName.set(userCode, roomName);
    rooms[roomName].push(userCode);
}

function moveUserToRoom(userCode, newRoomName, io) {
    const currentRoom = userCodetoRoomName.get(userCode);
    if (currentRoom === newRoomName) {
        console.log(`client moved to same room, currentRoom:${currentRoom} newRoomName:${newRoomName}`);
        return;
    }

    if (currentRoom) {
        const index = rooms[currentRoom].indexOf(userCode);
        if (index > -1) {
            rooms[currentRoom].splice(index, 1);
        }
        for (let otherUserCode of rooms[currentRoom]) {
            const otherSocketId = userCodeToSocketId.get(otherUserCode);
            if (otherSocketId) {
                io.to(otherSocketId).emit('user-left', { userCode });
            }
        }
    }

    if (!rooms[newRoomName]) {
        console.log('bad roomname banbanban');
        return;
    }
    userCodetoRoomName.set(userCode, newRoomName);
    rooms[newRoomName].push(userCode);

    const otherUsers = rooms[newRoomName].filter(uc => uc !== userCode);
    const socketId = userCodeToSocketId.get(userCode);
    if (socketId) {
        io.to(socketId).emit('room-users', { room: newRoomName, users: otherUsers });
    }

    for (let otherUserCode of otherUsers) {
        const otherSocketId = userCodeToSocketId.get(otherUserCode);
        if (otherSocketId) {
            io.to(otherSocketId).emit('user-joined', { userCode });
        }
    }

    console.log(`changeRoom userCode:${userCode} roomName:${newRoomName} -> ${rooms[newRoomName]}`);
}

function leaveRoom(userCode, io) {
    const currentRoom = userCodetoRoomName.get(userCode);
    if (currentRoom) {
        const index = rooms[currentRoom].indexOf(userCode);
        if (index > -1) {
            rooms[currentRoom].splice(index, 1);
        }
        userCodetoRoomName.delete(userCode);
        for (let otherUserCode of rooms[currentRoom]) {
            const otherSocketId = userCodeToSocketId.get(otherUserCode);
            if (otherSocketId) {
                io.to(otherSocketId).emit('user-left', { userCode });
            }
        }
    }
}

const handleLocationPacket = (packet, io) => {
    for (const zlevel in packet) {
        if(zlevel === "loc") continue; 
        const locations = packet[zlevel];
        const userCodes = Object.keys(locations);

        for (const userCode of userCodes) {
            const [ux, uy] = locations[userCode];
            const peers = {};

            for (const otherCode of userCodes) {
                if (otherCode === userCode) continue;
                const [ox, oy] = locations[otherCode];
                const dx = Math.abs(ux - ox);
                const dy = Math.abs(uy - oy);

                if (dx < 7 && dy < 7) {
                    const dist = Math.hypot(ux - ox, uy - oy);
                    peers[otherCode] = Math.round(dist * 10) / 10; // Round to 1 decimal place
                }
            }

            const socketId = userCodeToSocketId.get(userCode);
            if (socketId) {
                const out_packet = {peers: peers, own: userCode}
                if (Object.keys(peers).length === 0) {
                    io.to(socketId).emit('loc', { none: 1 });
                } else {
                    io.to(socketId).emit('loc', out_packet);
                }
            } else {
                // Optional: Log if userCode has no associated socket
                console.log(`No socket found for userCode: ${userCode}`);
            }
        }
    }
};
module.exports = { joinInitialRoom, moveUserToRoom, leaveRoom, handleLocationPacket};

