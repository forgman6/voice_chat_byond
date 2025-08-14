import socket

def send_to_unix_socket(message, socket_path="/tmp/byond_node.sock"):
    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as client:
        client.connect(socket_path)
        client.send((message + "\n").encode('ascii'))