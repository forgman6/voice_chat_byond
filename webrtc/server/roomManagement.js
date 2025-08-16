const { userCodeToSocketId } = require('./state');

const handleLocationPacket = (packet, io) => {
    for (const zlevel in packet) {
        if (zlevel === "loc") continue;
        const locations = packet[zlevel];
        const userCodes = Object.keys(locations);
        const numUsers = userCodes.length;

        // Initialize peers for all users
        const peersByUser = {};
        for (const userCode of userCodes) {
            peersByUser[userCode] = {};
        }

        // Compute distances only for unique pairs (i < j)
        for (let i = 0; i < numUsers; i++) {
            const userCode = userCodes[i];
            const [ux, uy] = locations[userCode];
            for (let j = i + 1; j < numUsers; j++) {
                const otherCode = userCodes[j];
                const [ox, oy] = locations[otherCode];
                const dx = Math.abs(ux - ox);
                const dy = Math.abs(uy - oy);
                if (dx < 8 && dy < 8) {
                    const dist = Math.hypot(ux - ox, uy - oy);
                    const roundedDist = Math.round(dist * 10) / 10;
                    peersByUser[userCode][otherCode] = roundedDist;
                    peersByUser[otherCode][userCode] = roundedDist;
                }
            }
        }

        // Emit for each user
        for (const userCode of userCodes) {
            const peers = peersByUser[userCode];
            const socketId = userCodeToSocketId.get(userCode);
            const socket = io.sockets.sockets.get(socketId);
            if (socketId && socket) {
                const out_packet = { peers: peers, own: userCode };
                if (Object.keys(peers).length === 0) {
                    socket.emit('loc', { none: 1 });
                } else {
                    socket.emit('loc', out_packet);
                }
            } else {
                console.log(`No socket found for userCode: ${userCode}`);
            }
        }
    }
};
module.exports = {handleLocationPacket};

