const { sendJSON } = require('./byondCommunication');
const { sessionIdToUserCode, userCodeToSocketId, userCodetoRoomName, rooms, prox_rooms } = require('./state');
const { moveUserToRoom, handleLocationPacket } = require('./roomManagement');
function handleRequest(data, byondPort, io, shutdown_function) {
    try {
        const { cmd } = data;
        if (!cmd || typeof cmd !== 'string') {
            const errorMsg = "Missing or invalid command";
            console.log(`error: ${errorMsg}`);
            sendJSON({ error: errorMsg, data: data }, byondPort);
            return;
        }

        const commandHandlers = {
            ping: (data) => {
                console.log(data['message']);
                sendJSON({ 'pong': 'Hello from Node', 'time': data["time"] }, byondPort);
            },
            register: (data) => {
                if (data['sessionId'] && data['userCode']) {
                    sessionIdToUserCode.set(data['sessionId'], data['userCode']);
                    console.log(`Registered sessionId: ${data['sessionId']} with userCode: ${data['userCode']}`);
                }
            },
            alterRooms: (data) => {
                if (data['add_room']) {
                    rooms[data['add_room']] = [];
                    console.log(`added room: ${data['add_room']}`);
                    if (data['prox']) {
                        prox_rooms.push(data['add_room']);
                        console.log(`proximity mode activated in room: ${data['add_room']}`);
                    }
                }
                if (data['remove_room']) {
                    delete rooms[data['remove_room']];
                    console.log(`deleted room: ${data['remove_room']}`);
                }
                if (data['add_rooms']) {
                    data['add_rooms'].forEach(room_name => {
                        rooms[room_name] = [];
                        console.log(`added room: ${room_name}`);
                    });
                    if (data['proximity_rooms']) {
                        data['proximity_rooms'].forEach(room_name => {
                            if (rooms[room_name]) {
                                prox_rooms.push(room_name);
                                console.log(`proximity mode activated in room: ${room_name}`);
                            };
                        });
                    };
                }
            },
            changeRoom: (data) => moveUserToRoom(data.userCode, data.room_name, io),

            stop_node: () => shutdown_function(),

            deafen: (data) => {
                if (!data['userCode']) {
                    const errorMsg = "Missing or invalid data: userCode";
                    console.log(`error: ${errorMsg}`);
                    sendJSON({ error: errorMsg, data: data }, byondPort);
                    return;
                }
                const socketId = userCodeToSocketId.get(data['userCode']);
                if (!socketId) {
                    const errorMsg = "socketId not found";
                    console.log(`error: ${errorMsg}`);
                    sendJSON({ error: errorMsg, data: data }, byondPort);
                    return;
                }
                io.to(socketId).emit("deafen");
            },
            mute_mic: (data) => {
            
                if (!data['userCode']) {
                    const errorMsg = "Missing or invalid data: userCode";
                    console.log(`error: ${errorMsg}`);
                    sendJSON({ error: errorMsg, data: data }, byondPort);
                    return;
                }
                const socketId = userCodeToSocketId.get(data['userCode']);
                if (!socketId) {
                    const errorMsg = "socketId not found";
                    console.log(`error: ${errorMsg}`);
                    sendJSON({ error: errorMsg, data: data }, byondPort);
                    return;
                }
                io.to(socketId).emit("mute_mic");
            },
            loc: (data) => handleLocationPacket(data, io),
        };

        const handler = commandHandlers[cmd];
        if (handler) {
            handler(data);
        } else {
            const errorMsg = `Unknown command`;
            console.log(`error: ${errorMsg} cmd:${cmd}`);
            sendJSON({ error: errorMsg, cmd: cmd, data: data }, byondPort);
        }
    } catch (error) {
        console.error('Error processing request:', error);
        sendJSON({ error: error.message, data }, byondPort);
    }
}

module.exports = { handleRequest };