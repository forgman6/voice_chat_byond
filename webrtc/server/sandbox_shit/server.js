const net = require('net');
const PIPE_NAME = '\\\\.\\pipe\\byond_node_pipe';  // Unique name; use this in DLL too

const server = net.createServer((stream) => {
    console.log('Client connected to pipe');

    stream.on('data', (data) => {
        const jsonStr = data.toString('utf-8');
        console.log(jsonStr)
        try {
            const json = JSON.parse(jsonStr);
            console.log('Received JSON:', json);
            // Handle the JSON here, e.g., process "cmd": "ping" or whatever your use case is
            // If you need to send a response back: stream.write('{"status": "received"}');
        } catch (err) {
            console.error('Invalid JSON:', err);
        }
    });

    stream.on('end', () => {
        console.log('Client disconnected');
    });
});

server.listen(PIPE_NAME, () => {
    console.log(`Named pipe server listening on ${PIPE_NAME}`);
});

server.on('error', (err) => {
    console.error('Pipe server error:', err);
});