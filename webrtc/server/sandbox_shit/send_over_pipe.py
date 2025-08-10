import sys
import pywintypes
import win32file
import win32pipe

PIPE_NAME = r'\\.\pipe\byond_node_pipe'

print(f"Connecting to the pipe '{PIPE_NAME}'")
try:
    handle = win32file.CreateFile(
        PIPE_NAME,
        win32file.GENERIC_WRITE,
        0,
        None,
        win32file.OPEN_EXISTING,
        0,
        None,
    )
except pywintypes.error as e:
    print(f"Error connecting to pipe: {e}")
    sys.exit(1)

print("Connected successfully")

# Prompt for message to send (e.g., JSON string)
data = input("Enter message to send (e.g., {\"message\":\"Hello from Python\"}): ")
data = data + "\n"  # Optional: Add newline for easier parsing on Node.js side

print("Sending message")
try:
    win32file.WriteFile(handle, data.encode('utf-8'))
except pywintypes.error as e:
    print(f"Error sending data: {e}")
    win32file.CloseHandle(handle)
    sys.exit(1)

win32file.CloseHandle(handle)
print("Message sent and connection closed")