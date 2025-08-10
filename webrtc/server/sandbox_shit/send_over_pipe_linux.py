import socket
import sys

with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as client:
    client.connect("/tmp/byond_node.sock")
    niggerbob = input("enter string to send: ").encode('ascii')
    client.send(niggerbob)
    client.close()
