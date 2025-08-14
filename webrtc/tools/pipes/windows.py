import win32file

def send_to_pipe(message, pipe_name=r'\\.\pipe\byond_node_pipe'):
    handle = win32file.CreateFile(
        pipe_name,
        win32file.GENERIC_WRITE,
        0,
        None,
        win32file.OPEN_EXISTING,
        0,
        None
    )
    win32file.WriteFile(handle, (message + "\n").encode('utf-8'))
    win32file.CloseHandle(handle)