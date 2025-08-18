// build: g++ -std=c++17 -O2 -fPIC -shared unix_send_export.cpp -o libunixsend.so
#include <sys/types.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>
#include <signal.h>
#include <errno.h>
#include <string.h>
#include <stddef.h>


static inline bool make_un_addr(const char* path, sockaddr_un &addr, socklen_t &alen){
    memset(&addr, 0, sizeof(addr));
    addr.sun_family = AF_UNIX;
    size_t n = strnlen(path, sizeof(addr.sun_path));
    if(n>=sizeof(addr.sun_path)){
        errno = ENAMETOOLONG;
        return false;
    }
    memcpy(addr.sun_path, path, n+1);
    alen = static_cast<socklen_t>(offsetof(sockaddr_un, sun_path) + n + 1);
    return true;
}

static inline ssize_t send_all_stream(int fd, const void* buf, size_t len){
    const char* p = static_cast<const char*>(buf);
    size_t left = len;
    while(left){
        ssize_t n = send(fd, p, left, MSG_NOSIGNAL);
        if(n>0){ p+=n; left-=n; continue; }
        if(n<0 && (errno==EINTR)) continue;
        return -1;
    }
    return static_cast<ssize_t>(len);
}

static inline ssize_t uds_send_stream(const char* path, const void* data, size_t len){
    int fd = socket(AF_UNIX, SOCK_STREAM, 0);
    if(fd==-1) return -1;

    sockaddr_un addr; socklen_t alen;
    if(!make_un_addr(path, addr, alen)){
        int e=errno; close(fd); errno=e; return -1;
    }
    if(connect(fd, reinterpret_cast<sockaddr*>(&addr), alen)==-1){
        int e=errno; close(fd); errno=e; return -1;
    }
    ssize_t sent = send_all_stream(fd, data, len);
    int e=errno; close(fd); errno=e; return sent;
}

static inline ssize_t uds_send_dgram(const char* path, const void* data, size_t len){
    int fd = socket(AF_UNIX, SOCK_DGRAM, 0);
    if(fd==-1) return -1;

    sockaddr_un addr; socklen_t alen;
    if(!make_un_addr(path, addr, alen)){
        int e=errno; close(fd); errno=e; return -1;
    }
    ssize_t sent = sendto(fd, data, len, MSG_NOSIGNAL, reinterpret_cast<sockaddr*>(&addr), alen);
    int e=errno; close(fd); errno=e; return sent;
}

static inline ssize_t fifo_write_impl(const char* path, const void* data, size_t len){
    int fd = open(path, O_WRONLY|O_NONBLOCK);
    if(fd==-1) return -1;
    ssize_t wrote = write(fd, data, len);
    int e=errno; close(fd); errno=e; return wrote;
}

// kill SIGPIPE so we get -EPIPE instead of getting owned
__attribute__((constructor))
static void no_sigpipe(){
    signal(SIGPIPE, SIG_IGN);
}

extern "C" {

// byond: call_ext(lib, "SendJSON")(json, length(json), "/tmp/my.sock")
// sends to UNIX DGRAM socket at `path`
int SendJSON(const char* json, int len, const char* path){
    if(!json||!path){ return -EINVAL; }
    if(len<0){ return -EINVAL; }
    size_t n = static_cast<size_t>(len);
    ssize_t r = uds_send_dgram(path, json, n);
    return (r<0)? -errno : static_cast<int>(r);
}

// stream variant
int UDS_SendStream(const char* path, const char* data, int len){
    if(!path||!data||len<0){ return -EINVAL; }
    ssize_t r = uds_send_stream(path, data, static_cast<size_t>(len));
    return (r<0)? -errno : static_cast<int>(r);
}

// datagram variant (explicit)
int UDS_SendDgram(const char* path, const char* data, int len){
    if(!path||!data||len<0){ return -EINVAL; }
    ssize_t r = uds_send_dgram(path, data, static_cast<size_t>(len));
    return (r<0)? -errno : static_cast<int>(r);
}

// fifo (named pipe) write
int FIFO_Write(const char* path, const char* data, int len){
    if(!path||!data||len<0){ return -EINVAL; }
    ssize_t r = fifo_write_impl(path, data, static_cast<size_t>(len));
    return (r<0)? -errno : static_cast<int>(r);
}

} // extern "C"