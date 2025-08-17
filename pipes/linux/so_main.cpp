// Linux BYOND API v516.1666
#include "../byondapi/byondapi.h"
#include "../byondapi/byondapi_cpp_wrappers.h"
#include <sys/socket.h>
#include <sys/un.h>
#include <sys/types.h>
#include <unistd.h>
#include <mutex>
#include <cstdlib>
#include <cstring>

// Global mutex for thread safety during socket operations
static std::mutex socket_mutex;

// Constants
static const char* SOCKET_PATH = "/tmp/byond_node.sock"; // Consider using a more secure path in production

// Helper function to return an error to the waiting proc
static void ReturnError(const CByondValue* waiting_proc, const char* msg) {
    CByondValue error;
    ByondValue_SetStr(&error, msg);
    Byond_Return(waiting_proc, &error);
    ByondValue_DecRef(&error);
}

// Helper function to return success to the waiting proc
static void ReturnSuccess(const CByondValue* waiting_proc) {
    CByondValue ok;
    ByondValue_SetStr(&ok, "OK");
    Byond_Return(waiting_proc, &ok);
    ByondValue_DecRef(&ok);
}

// Test function (synchronous)
extern "C" BYOND_EXPORT CByondValue Test(u4c n, CByondValue v[]) {
    CByondValue out;
    ByondValue_Clear(&out);
    ByondValue_SetStr(&out, "hello world");
    return out;
}

// Send JSON via IPC (async with immediate return)
extern "C" BYOND_EXPORT void SendJSON(u4c n, CByondValue v[], CByondValue waiting_proc) {
    if (n != 2 || !ByondValue_IsStr(&v[0]) || !ByondValue_IsNum(&v[1])) {
        ReturnError(&waiting_proc, "Error: Expected string (JSON) and number (length)");
        return;
    }

    float len_float = ByondValue_GetNum(&v[1]);
    if (len_float <= 0) {
        ReturnError(&waiting_proc, "Error: Invalid length argument");
        return;
    }
    u4c len = static_cast<u4c>(len_float);

    // Allocate buffer based on provided length (includes space for null terminator)
    char* json = (char*)malloc(len + 1);
    if (!json) {
        ReturnError(&waiting_proc, "Error: Memory allocation failed");
        return;
    }

    u4c buffer_size = len + 1;
    if (!Byond_ToString(&v[0], json, &buffer_size)) {
        free(json);
        ReturnError(&waiting_proc, "Error: Failed to convert BYOND string");
        return;
    }

    // Verify the actual length matches the provided length (buffer_size includes null terminator)
    if (buffer_size != len + 1) {
        free(json);
        ReturnError(&waiting_proc, "Error: Length mismatch");
        return;
    }

    // Lock for thread-safe socket operation
    std::lock_guard<std::mutex> lock(socket_mutex);

    // Create Unix domain socket
    int sock = socket(AF_UNIX, SOCK_STREAM, 0);
    if (sock == -1) {
        free(json);
        ReturnError(&waiting_proc, "Error: Could not create socket");
        return;
    }

    // Set up address
    struct sockaddr_un addr;
    memset(&addr, 0, sizeof(addr));
    addr.sun_family = AF_UNIX;
    strncpy(addr.sun_path, SOCKET_PATH, sizeof(addr.sun_path) - 1);

    // Connect to socket
    if (connect(sock, (struct sockaddr*)&addr, sizeof(addr)) == -1) {
        free(json);
        close(sock);
        ReturnError(&waiting_proc, "Error: Could not connect to socket");
        return;
    }

    // Send data (without null terminator)
    ssize_t bytes_written = write(sock, json, len);
    free(json);
    close(sock);

    if (bytes_written != static_cast<ssize_t>(len)) {
        ReturnError(&waiting_proc, "Error: Failed to send all data");
        return;
    }

    // Success: Return to waiting proc
    ReturnSuccess(&waiting_proc);
}