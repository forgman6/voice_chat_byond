const socket = io('https://localhost:3000', { rejectUnauthorized: false }); // Ignore self-signed cert for dev
const configuration = {
    iceServers: [
        { urls: 'stun:stun.l.google.com:19302' },
    ]
};
const triggers = document.querySelectorAll('.tooltip');
const tooltip = document.getElementById('tooltip_box');
triggers.forEach(trigger => {
    trigger.addEventListener('mouseenter', () => {
        tooltip.innerHTML = trigger.dataset.tip;
    });
});


// Extract sessionId from URL
const urlParams = new URLSearchParams(document.location.search);
const sessionId = urlParams.get('sessionId');
console.log('Session ID:', sessionId);

// Send sessionId to server
socket.emit('join', { sessionId });

// Handle updates from server
socket.on('update', (update) => {
    const statusDiv = document.getElementById('status');
    if (update.type === 'status') {
        statusDiv.innerText = update.data;
    }
});

// WebRTC setup
let localStream;
let peerConnections = new Map();

let audioElements = new Map();
let sinkId; //for setting output device
// Threshold for voice activity detection
let volumeThreshold = 0.01 //for setting voice sensitivity

// states
let is_deafened = false;
let manual_mute = false; // New: Tracks manual mute state (separate from effective transmission)
let is_voice_active = false; // New: Hoisted for global access
let audioSenders = new Map(); // New: Map of userCode => RTCRtpSender for audio (to control replaceTrack)
let is_mic_testing = false; // New: For mic test state
let previous_is_deafened = false; // New: To restore after mic test
let testAudioContext; // New: For mic test playback
let testSource; // New
let delayNode; // New
// Initialize local audio stream (no changes here, but included for context)
async function get_mic() {

    localStream = await navigator.mediaDevices.getUserMedia({ audio: true });
    await populateDevices();
    navigator.mediaDevices.addEventListener('devicechange', populateDevices)
    document.getElementById('audioInput').addEventListener('change', input_changed)
    document.getElementById('audioOutput').addEventListener('change', output_changed)

    setupGainNode(localStream);
    console.log('Local stream acquired');
    document.getElementById("mic").remove()
    document.getElementById('status').innerText = "Microphone access granted"

    // css change to signal mic is working

    // Now that localStream is available, set up the VAD
    setupVoiceActivityDetection();
}

async function populateDevices() {
    const devices = await navigator.mediaDevices.enumerateDevices();
    const audioInputs = devices.filter(device => device.kind === 'audioinput');
    const audioOutputs = devices.filter(device => device.kind === 'audiooutput');

    const inputSelect = document.getElementById('audioInput');
    inputSelect.innerHTML = audioInputs.map(device =>
        `<option value="${device.deviceId}" ${device.deviceId === 'default' ? 'selected' : ''}>${device.label || 'Default Input'}</option>`
    ).join('');

    const outputSelect = document.getElementById('audioOutput');
    outputSelect.innerHTML = audioOutputs.map(device =>
        `<option value="${device.deviceId}" ${device.deviceId === 'default' ? 'selected' : ''}>${device.label || 'Default Output'}</option>`
    ).join('');
}

async function input_changed(event) {
    const deviceId = event.target.value;
    if (localStream) {
        localStream.getTracks().forEach(track => track.stop());
    }

    // Get new stream with selected input device
    localStream = await navigator.mediaDevices.getUserMedia({
        audio: { deviceId: { exact: deviceId } }
    });
    // New: Re-setup processing and VAD for the new stream
    setupGainNode(localStream);
    setupVoiceActivityDetection();
    // New: Update all senders with the new track (or null, based on current state)
    updateAudioSenders();
    // New: If testing, restart playback
    if (is_mic_testing) {
        stopMicTestPlayback();
        startMicTestPlayback();
    }
}
async function output_changed(event) {
    const deviceId = event.target.value;
        sinkId = deviceId;
        audioElements.forEach(audio => {
        audio.setSinkId(sinkId);
    });

}


get_mic();
let gainNode; // Global reference to update dynamically (or store in a class/module)

function setupGainNode(stream) {
    // Assume only one audio track per stream
    const audioTrack = stream.getAudioTracks()[0];
    if (!audioTrack) {
        console.error('No audio track found in stream');
        return;
    }

    const ctx = new AudioContext();
    const src = ctx.createMediaStreamSource(new MediaStream([audioTrack]));
    const dst = ctx.createMediaStreamDestination();
    gainNode = ctx.createGain(); // Assign to global for later updates

    // Explicit connections for clarity
    src.connect(gainNode);
    gainNode.connect(dst);

    // Remove original track and add the processed one
    stream.removeTrack(audioTrack);
    stream.addTrack(dst.stream.getAudioTracks()[0]);

    // Set initial gain from slider
    updateGainFromSlider();
}

// Function to update gain dynamically
function updateGainFromSlider() {
    if (!gainNode) {
        console.warn('Gain node not initialized');
        return;
    }
    const slider = document.getElementById('input_slider');
    const sliderValue = parseFloat(slider.value); // Parse to number
    // Map 0-100 slider to 0-2 gain (adjust mapping as needed to avoid distortion)
    const gainValue = sliderValue / 50;
    gainNode.gain.value = gainValue;
    // console.log('Gain set to:', gainValue); // For debugging
}

// Hook up the slider for real-time changes
document.getElementById('input_slider').addEventListener('input', updateGainFromSlider);

//hook up sensitivity slider
document.getElementById('sensitivity_slider').addEventListener('input', update_sensitivity);

function update_sensitivity(){
    const slider = document.getElementById('sensitivity_slider');
    const sliderValue = parseFloat(slider.value);
    if(!sliderValue) return;
    volumeThreshold = sliderValue
}

// Function to set up voice activity detection (called after localStream is ready)
function setupVoiceActivityDetection() {
    // Set up Web Audio API context
    const audioContext = new (window.AudioContext || window.webkitAudioContext)();
    const source = audioContext.createMediaStreamSource(localStream);
    const analyser = audioContext.createAnalyser();
    analyser.fftSize = 2048; // Adjust as needed for sensitivity (higher = more detail, but slower)
    const bufferLength = analyser.frequencyBinCount;
    const dataArray = new Float32Array(bufferLength);

    // Connect the nodes
    source.connect(analyser);
    // Note: You may also want to connect to destination if you need to hear the audio locally
    // analyser.connect(audioContext.destination);

    // Debounce time in ms to avoid rapid toggling (e.g., consider active if above threshold for at least 200ms)
    const debounceTime = 200;
    let lastActiveTime = 0;
    // is_voice_active is global (hoisted)

    // Callback function when voice activity is detected (for visual indicator or future signals)
    function onVoiceActivityDetected(active) {
        const voice_activity_status = document.getElementById("voice_activity_status")
        if (active) {
            voice_activity_status.classList = 'active'
        } else {
            voice_activity_status.classList = ''
        }
        socket.emit('voice_activity', { active: active });
    }

    // Function to calculate RMS volume from time domain data
    function getRMS() {
        analyser.getFloatTimeDomainData(dataArray);
        let sum = 0;
        for (let i = 0; i < bufferLength; i++) {
            sum += dataArray[i] * dataArray[i];
        }
        return Math.sqrt(sum / bufferLength);
    }

    // Monitoring loop using requestAnimationFrame for efficiency
    function monitorAudio() {
        const rms = getRMS();
        const now = Date.now();

        // New: Update visual indicator (always, for live mic volume display)
        const indicator = document.getElementById('mic_test_visual_indicator');
        if (indicator) {
            // Scale RMS to 0-100% (adjust 0.5 max expected RMS as needed)
            const level = Math.min(1, rms / 0.5) * 100;
            indicator.style.backgroundColor = is_voice_active ? 'green' :'grey'
            indicator.style.width = level + '%'; // Assumes CSS: #mic_test_visual_indicator { height: 10px; background: green; width: 0%; transition: width 0.1s; }
        }

        if (rms > volumeThreshold) {
            lastActiveTime = now;
            if (!is_voice_active) {
                is_voice_active = true;
                onVoiceActivityDetected(true);
                updateAudioSenders(); // New: Update transmission state
            }
        } else if (is_voice_active && now - lastActiveTime > debounceTime) {
            is_voice_active = false;
            onVoiceActivityDetected(false);
            updateAudioSenders(); // New: Update transmission state
        }

        requestAnimationFrame(monitorAudio);
    }

    // Start monitoring
    monitorAudio();

    // Don't forget to handle cleanup when done (e.g., on page unload)
    // Add event listener for cleanup
    window.addEventListener('beforeunload', () => {
        audioContext.close();
        if (localStream) {
            localStream.getTracks().forEach(track => track.stop());
        }
    });
}

const volumeSlider = document.getElementById('volume_slider');
// Set initial volume on any existing audios (though none yet)
volumeSlider.addEventListener('input', updateMasterVolume);

// Function to update volume on all audio elements
function updateMasterVolume() {
    const volume = volumeSlider.value / 100;
    audioElements.forEach(audio => {
        audio.volume = volume;
    });
};
// New: Centralized function to update audio transmission across all peers
function updateAudioSenders() {
    if (!localStream) return;
    const shouldSend = !manual_mute && !is_deafened && is_voice_active;
    const track = shouldSend ? localStream.getAudioTracks()[0] : null;
    audioSenders.forEach(sender => {
        sender.replaceTrack(track);
    });
}

//force_mute - forces mic to mute regardless of behavior
async function toggle_mute_self(force_mute = false) {
    if (!localStream) return;
    if (is_deafened && !force_mute) {
        toggle_deafen_self();
        return;
    }
    if (force_mute) {
        manual_mute = true;
    }
    else {
        manual_mute = !manual_mute;
    }
    updateAudioSenders(); // Modified: Update transmission instead of enabling/disabling track
    toggle_button('mute_toggle', !manual_mute); // Modified: Button reflects manual mute state
}
async function toggle_button(button_id, bool) {
    const button = document.getElementById(button_id);
    if (bool) {
        button.classList.remove("toggled");
    } else {
        button.classList.add("toggled");
    }
}
async function toggle_settings() {
    const settings_menu = document.getElementById("settings");
    const is_settings_open = settings_menu.classList.contains('open');
    if (is_settings_open) {
        settings_menu.classList.remove('open');
    }
    else {
        settings_menu.classList.add('open');
    }
    toggle_button('settings_button', is_settings_open);
}
//force_deafen - forces mic and volume to mute regardless of behavior
async function toggle_deafen_self(force_deafen = false) {
    if (!localStream) return;
    if (force_deafen) {
        is_deafened = true;
    }
    else {
        is_deafened = !is_deafened;
    }
    manual_mute = is_deafened; // New: Force manual mute state to match deafen (preserves original behavior)
    // Mute/unmute all incoming audio elements
    audioElements.forEach(audio => {
        audio.muted = is_deafened;
    });
    updateAudioSenders(); // Modified: Update transmission instead of enabling/disabling track
    toggle_button('mute_toggle', !manual_mute);
    toggle_button('deafen_toggle', !is_deafened);
}

// New: Start delayed mic playback
function startMicTestPlayback() {
    testAudioContext = new AudioContext();
    testSource = testAudioContext.createMediaStreamSource(localStream);
    delayNode = testAudioContext.createDelay(2); 
    testSource.connect(delayNode);
    delayNode.connect(testAudioContext.destination);
}

// New: Stop mic playback
function stopMicTestPlayback() {
    if (testSource) testSource.disconnect();
    if (delayNode) delayNode.disconnect();
    if (testAudioContext) testAudioContext.close();
    testAudioContext = null;
    testSource = null;
    delayNode = null;
}

// New: Toggle mic test mode
function toggle_mic_test() {
    if (!localStream) return;
    is_mic_testing = !is_mic_testing;
    const button = document.querySelector('.mic_test_container button');
    if (is_mic_testing) {
        previous_is_deafened = is_deafened;
        document.getElementById('buttons').classList.add('hide')
        toggle_deafen_self(true); // Force deafen to mute incoming/outgoing during test
        startMicTestPlayback();
        button.textContent = 'stop test';
        button.classList.add('toggled'); // Optional: Style as toggled
    } else {
        stopMicTestPlayback();
        if (!previous_is_deafened) toggle_deafen_self(); // Restore: Undeafen if previously not deafened
        button.textContent = 'test mic';
        button.classList.remove('toggled');
        document.getElementById('buttons').classList.remove('hide')
    }
}

function createPeerConnection(userCode, sendOffer) {
    const pc = new RTCPeerConnection(configuration);
    peerConnections.set(userCode, pc);

    // Create a dedicated audio element for this user
    const audio = document.createElement('audio');
    audio.autoplay = true;
    //if a different output device is set:
    if(sinkId){
        audio.setSinkId(sinkId); //set the audio to that output device.
    }
    audio.muted = is_deafened;
    audio.volume = volumeSlider.value / 100; // Set initial volume
    document.body.appendChild(audio); // Append to body (can be hidden via CSS: audio { display: none; })
    audioElements.set(userCode, audio);


    // Add local stream to peer connection
    if (localStream) {
        const track = localStream.getAudioTracks()[0];
        const sender = pc.addTrack(track, localStream); // Modified: Add track initially (required), then update based on state
        audioSenders.set(userCode, sender);
        updateAudioSenders(); // New: Immediately apply current transmission state (may replace with null)
    }

    // Handle ICE candidates
    pc.onicecandidate = (event) => {
        if (event.candidate) {
            socket.emit('ice-candidate', { to: userCode, candidate: event.candidate });
        }
    };

    // Handle incoming audio stream
    pc.ontrack = (event) => {
        audio.srcObject = event.streams[0];
        console.log(`Receiving audio from ${userCode}`);
    };

    // Send offer if initiator
    if (sendOffer) {
        pc.createOffer()
            .then(offer => pc.setLocalDescription(offer))
            .then(() => socket.emit('offer', { to: userCode, offer: pc.localDescription }))
            .catch(err => console.error('Failed to create offer:', err));
    }

    return pc;
}

// Handle room users list (sent when joining a room)
socket.on('room-users', (data) => {
    const { users } = data;
    console.log('Room users:', users);
    for (let userCode of users) {
        createPeerConnection(userCode, true); // New user sends offers
    }
    toggle_room_status(true); // Indicate connected to the room
});

// Handle new user joining the room
socket.on('user-joined', (data) => {
    const { userCode } = data;
    console.log(`User joined: ${userCode}`);
    createPeerConnection(userCode, false); // Wait for their offer
});

// Handle incoming offer
socket.on('offer', (data) => {
    const { from, offer } = data;
    console.log(`Received offer from ${from}`);
    const pc = peerConnections.get(from) || createPeerConnection(from, false);
    pc.setRemoteDescription(new RTCSessionDescription(offer))
        .then(() => pc.createAnswer())
        .then(answer => pc.setLocalDescription(answer))
        .then(() => socket.emit('answer', { to: from, answer: pc.localDescription }))
        .catch(err => console.error('Error handling offer:', err));
});

// Handle incoming answer
socket.on('answer', (data) => {
    const { from, answer } = data;
    console.log(`Received answer from ${from}`);
    const pc = peerConnections.get(from);
    if (pc) {
        pc.setRemoteDescription(new RTCSessionDescription(answer))
            .catch(err => console.error('Error setting remote description:', err));
    }
});

// Handle incoming ICE candidate
socket.on('ice-candidate', (data) => {
    const { from, candidate } = data;
    console.log(`Received ICE candidate from ${from}`);
    const pc = peerConnections.get(from);
    if (pc) {
        pc.addIceCandidate(new RTCIceCandidate(candidate))
            .catch(err => console.error('Error adding ICE candidate:', err));
    }
});

// Handle user leaving the room
socket.on('user-left', (data) => {
    const { userCode } = data;
    console.log(`User left: ${userCode}`);
    const pc = peerConnections.get(userCode);
    if (pc) {
        pc.close();
        peerConnections.delete(userCode);
    }
    const audio = audioElements.get(userCode);
    if (audio) {
        audio.remove(); // Remove from DOM
        audioElements.delete(userCode);
    }
    audioSenders.delete(userCode); // New: Clean up sender
});


// Handle server shutdown signal
socket.on('server-shutdown', () => {
    console.log('Server is shutting down. Cleaning up...');

    // Close all peer connections
    peerConnections.forEach((pc) => {
        pc.close();
    });
    peerConnections.clear();

    // Stop local media stream tracks
    if (localStream) {
        localStream.getTracks().forEach((track) => track.stop());
    }

    // Disconnect the socket
    socket.disconnect();

    document.getElementById('status').innerText = 'Server shutting down. Connection closed.';
    toggle_room_status(false); // Indicate disconnected
    audioSenders.clear(); // New: Clean up
});

socket.on('disconnect', (reason) => {
    console.log(`Socket disconnected: ${reason}`);
    peerConnections.forEach((pc) => {
        pc.close();
    });
    peerConnections.clear();
    audioElements.forEach((audio) => {
        audio.remove();
    });
    audioElements.clear();
    if (localStream) {
        localStream.getTracks().forEach((track) => track.stop());
    }
    toggle_room_status(false); // Indicate disconnected
    audioSenders.clear(); // New: Clean up
});

socket.on('mute_mic', () => {
    toggle_mute_self(force_mute = true);
});

socket.on('deafen', () => {
    toggle_deafen_self(force_deafen = true);
});

function toggle_room_status(on = false) {
    const room_status = document.getElementById('room_status')
    if (on) {
        room_status.src = 'fastclown.gif'
        room_status.classList = 'active'
    } else {
        room_status.src = 'stopclown.png'
        room_status.classList = ''
    }
}