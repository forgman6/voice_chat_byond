const {userCodeToSocketId } = require('./state');

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
            const socket = io.sockets.sockets.get(socketId)
            if (socketId && socket) {
                const out_packet = {peers: peers, own: userCode}
                if (Object.keys(peers).length === 0) {
                    socket.emit('loc', { none: 1 });
                } else {
                    socket.emit('loc', out_packet);
                }
            } else {
                // Optional: Log if userCode has no associated socket
                console.log(`No socket found for userCode: ${userCode}`);
            }
        }
    }
};
module.exports = {handleLocationPacket};

