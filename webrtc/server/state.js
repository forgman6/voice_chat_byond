const sessionIdToUserCode = new Map();
const userCodeToSocketId = new Map();
const socketIdToUserCode = new Map();
const userCodetoRoomName = new Map();
let rooms = {'NONE': []}; //client rooms
let prox_rooms = []; //which rooms in `rooms` has proximity mode on

module.exports = {
    sessionIdToUserCode,
    userCodeToSocketId,
    socketIdToUserCode,
    userCodetoRoomName,
    rooms,
    prox_rooms
};