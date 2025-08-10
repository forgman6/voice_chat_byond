// linux byondapi v 516.1666
#include "../byondapi/byondapi.h" 
#include "../byondapi/byondapi_cpp_wrappers.h"

#include <sys/socket.h>
#include <sys/un.h>
#include <unistd.h>
#include <mutex>
#include <cstdlib>

// Global mutex for thread safety
static std::mutex ws_mutex;
static const char* PIPE_NAME = "/tmp/byond_node.sock";  // Use a secure path, e.g., in your app's dir

// Test function (synchronous)
extern "C" BYOND_EXPORT CByondValue Test(u4c n, CByondValue v[]) {
    CByondValue out;
    ByondValue_Clear(&out);
    ByondValue_SetStr(&out, "hello world");
    return out;
}
// Helper to get string from ByondValue with resizing
bool GetByondString(const CByondValue& val, char** buffer, u4c* len) {
    *buffer = nullptr;
    *len = 0;

    // First, query the required length (if API supports buffer=nullptr; falls back to loop if not)
    if (!Byond_ToString(&val, nullptr, len)) {
        if (*len == 0) {
            return false;  // Likely not a string or real error
        }
    }
    else {
        // Unexpected success with nullptr buffer; treat as error
        return false;
    }

    // Allocate exact size
    *buffer = (char*)malloc(*len);
    if (!*buffer) {
        *len = 0;
        return false;
    }

    // Attempt conversion
    if (Byond_ToString(&val, *buffer, len)) {
        return true;
    }

    // If failed (rare, since we allocated exact), enter resize loop with safety
    u4c prev_len = *len;
    while (!Byond_ToString(&val, *buffer, len)) {
        if (*len == 0 || *len == prev_len) {  // Real failure or no progress (prevent infinite loop)
            free(*buffer);
            *buffer = nullptr;
            *len = 0;
            return false;
        }

        // Safe realloc
        char* temp = (char*)realloc(*buffer, *len);
        if (!temp) {
            free(*buffer);
            *buffer = nullptr;
            *len = 0;
            return false;
        }
        *buffer = temp;
        prev_len = *len;
    }

    return true;
}

// Send JSON via IPC (await mode, cross-platform)
extern "C" BYOND_EXPORT void SendJSON(u4c n, CByondValue v[], CByondValue waiting_proc) {
    if (n != 2 || !ByondValue_IsStr(&v[0]) || !ByondValue_IsNum(&v[1])) {
        CByondValue error;
        ByondValue_SetStr(&error, "Error: Expected string (JSON) and number (length)");
        Byond_Return(&waiting_proc, &error);
        ByondValue_DecRef(&error);
        return;
    }

    float len_float = ByondValue_GetNum(&v[1]);
    if (len_float <= 0) {
        CByondValue error;
        ByondValue_SetStr(&error, "Error: Invalid length argument");
        Byond_Return(&waiting_proc, &error);
        ByondValue_DecRef(&error);
        return;
    }
    u4c len = static_cast<u4c>(len_float);

    char* json = nullptr;
    u4c json_len = 0;
    if (!GetByondString(v[0], &json, &json_len) || json_len - 1 != len) {
        CByondValue error;
        ByondValue_SetStr(&error, "Error: Could not resolve JSON string or length mismatch");
        Byond_Return(&waiting_proc, &error);
        ByondValue_DecRef(&error);
        free(json);
        return;
    }

    std::lock_guard<std::mutex> lock(ws_mutex);
    // Linux Unix domain socket client
    int sock = socket(AF_UNIX, SOCK_STREAM, 0);
    if (sock == -1) {
        CByondValue error;
        ByondValue_SetStr(&error, "Error: Could not create socket");
        Byond_Return(&waiting_proc, &error);
        ByondValue_DecRef(&error);
        free(json);
        return;
    }
    struct sockaddr_un addr;
    memset(&addr, 0, sizeof(addr));
    addr.sun_family = AF_UNIX;
    strcpy(addr.sun_path, PIPE_NAME);
    if (connect(sock, (struct sockaddr*)&addr, sizeof(addr)) == -1) {
        CByondValue error;
        ByondValue_SetStr(&error, "Error: Could not connect to socket");
        Byond_Return(&waiting_proc, &error);
        ByondValue_DecRef(&error);
        close(sock);
        free(json);
        return;
    }

    ssize_t bytes_written = write(sock, json, len);
    close(sock);
    free(json);
}