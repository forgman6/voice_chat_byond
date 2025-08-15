const { sessionIdToUserCode, userCodeToSocketId, socketIdToUserCode} = require('./state');
const { joinInitialRoom, leaveRoom } = require('./roomManagement');
const { sendJSON } = require('./byondCommunication');

function createConnectionHandler(byondPort, io) {
    return function handleConnection(socket) {
        console.log('A user connected:', socket.id);
        if(!socketIdToUserCode.get(socket.id)) {
            console.log(`id without userCode ${socket.id} disconnecting`);
                socket.emit('update', { type: 'status', data: 'disconnected from server' });
            socket.disconnect();
        }
        socket.on('join', (data) => {
            const sessionId = data.sessionId;
            const userCode = sessionIdToUserCode.get(sessionId);
            if (userCode) {
                userCodeToSocketId.set(userCode, socket.id);
                socketIdToUserCode.set(socket.id, userCode);
                sessionIdToUserCode.delete(sessionId);
                joinInitialRoom(userCode);
                socket.userCode = userCode;
                console.log(`Associated userCode ${userCode} with socket ${socket.id}`);
                socket.emit('update', { type: 'status', data: 'Connected successfully' });
                sendJSON({ 'registered': userCode }, byondPort);
            } else {
                console.log('Invalid sessionId', sessionId);
                socket.emit('update', { type: 'status', data: 'bad sessionId >:(' });
                socket.disconnect();
            }
        });

        socket.on('disconnect_page', () => {
            const userCode = socketIdToUserCode.get(socket.id);
            if (userCode) {
                sendJSON({disconnect: userCode}, byondPort);
                userCodeToSocketId.delete(userCode);
                socketIdToUserCode.delete(socket.id)
                console.log(`Removed userCode ${userCode} on disconnect`);
            }
            socket.disconnect();
            console.log('User disconnected:', socket.id);
        });

        socket.on('offer', (data) => {
            const { to, offer } = data;
            const targetSocketId = userCodeToSocketId.get(to);
            if (targetSocketId) {
                io.to(targetSocketId).emit('offer', { from: socket.userCode, offer });
            }
        });

        socket.on('answer', (data) => {
            const { to, answer } = data;
            const targetSocketId = userCodeToSocketId.get(to);
            if (targetSocketId) {
                io.to(targetSocketId).emit('answer', { from: socket.userCode, answer });
            }
        });

        socket.on('ice-candidate', (data) => {
            const { to, candidate } = data;
            const targetSocketId = userCodeToSocketId.get(to);
            if (targetSocketId) {
                io.to(targetSocketId).emit('ice-candidate', { from: socket.userCode, candidate });
            }
        });

        socket.on('voice_activity', (data) => {
            const userCode = socketIdToUserCode.get(socket.id); //ack
            sendJSON({voice_activity: userCode, active: data['active']}, byondPort)
        });
    };
}

module.exports = { createConnectionHandler };