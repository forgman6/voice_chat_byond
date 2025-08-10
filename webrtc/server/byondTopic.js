// credit to https://github.com/TamberP/byond.topic thank you, bong furry!


const net = require('net');

/**
 *  Formats data to url skibidi adds and checks for `?`.
 *  @param {string} data  - The topic data to format.
 *  @returns {string} - formatted data
 */
function formatData(data) {
    if (data.length == 0 || data[0] != '?') {
        return `?${data}`;
    }
    else {
        return data;
    }
}

/**
 * Builds a BYOND topic packet from the provided data.
 * @param {string} data - The topic data to encode.
 * @returns {Buffer} - The constructed packet.
 */
function buildPacket(data) {

    const dataString = formatData(data)
    const packetSize = dataString.length + 6;
    if (packetSize >= (2 ** 16 - 1)) {
        reject(new Error(`Data exceeds max size data size: ${packetSize}`));
        return;
    }
    const headerBuf = Buffer.alloc(9);  // 9 bytes, all initialized to 0x00
    headerBuf[1] = 0x83;  // Write 0x83 at position 1
    headerBuf.writeUInt16BE(packetSize, 2);  // Write packetSize at position 2 (2 bytes, big-endian)
    const queryBuf = Buffer.from(dataString, 'utf8');
    const nullBuf = Buffer.from([0]);
    return packet = Buffer.concat([headerBuf, queryBuf, nullBuf]);
}

/**
 * Sends a topic packet to a BYOND server.
 * @param {string} host - The server hostname or IP.
 * @param {number} port - The server port.
 * @param {string} data - The topic data to send.
 * @param {number} [timeout=5000] - Socket timeout in milliseconds.
 * @returns {Promise<void>} - Resolves when the packet is sent, rejects on error.
 */
function sendByondTopic(host, port, data, timeout = 10000) {
    return new Promise((resolve, reject) => {
        if (typeof data !== 'string') {
            reject(new Error('Data must be a string'));
            return;
        }

        const packet = buildPacket(data);
        const client = new net.Socket();

        client.setTimeout(timeout, () => {
            client.destroy();
        });

        client.on('error', (err) => {
            client.destroy();
            reject(err);
        });

        client.connect(port, host, () => {
            // console.log('Packet (hex):', packet.toString('hex'));
            client.write(packet, () => {
                client.unref(); // Allows Node.js to continue without waiting for socket closure
                resolve();
            });
        });
    });
}
module.exports = { sendByondTopic };