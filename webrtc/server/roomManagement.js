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

module.exports = { joinInitialRoom, moveUserToRoom, leaveRoom };