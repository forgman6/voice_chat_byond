const express = require('express');
const https = require('https');
const fs = require('fs');
const { Server } = require('socket.io');
const { createConnectionHandler } = require('./websocketHandlers');
const helmet = require('helmet');

function startWebSocketServer(byondPort) {
    const options = {
        key: fs.readFileSync(__dirname + '/certs/key.pem'),
        cert: fs.readFileSync(__dirname + '/certs/cert.pem')
    };
    const app = express();
    const server = https.createServer(options, app);
    const io = new Server(server);

    // Use Helmet to set up CSP and other security headers
    app.use(helmet({
        contentSecurityPolicy: {
            directives: {
                defaultSrc: ["'self'",],
                scriptSrc: ["'self'", "'unsafe-inline'"],
                styleSrc: ["'self'", "'unsafe-inline'"],
                connectSrc: ["'self'"],
                // Add more directives as needed, e.g., for media if your voice chat requires it:
                // mediaSrc: ["'self'", "blob:", "data:"],
            }
        }
    }));

    app.use(express.static(__dirname + '/public'));
    app.get('/', (req, res) => {
        res.sendFile(__dirname + '/public/voicechat.html');
    });

    const handleConnection = createConnectionHandler(byondPort, io);
    io.on('connection', handleConnection);

    const PORT = 443;
    server.listen(PORT, () => {
        console.log(`HTTPS server running on port ${PORT}`);
    });

    return { io, server };
}

function disconnectAllClients(io) {
    io.emit('server-shutdown');
    setTimeout(() => {
        io.sockets.sockets.forEach((socket) => {
            socket.disconnect(true);
        });
    }, 2000);
}

module.exports = { startWebSocketServer, disconnectAllClients };