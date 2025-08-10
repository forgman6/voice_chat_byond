
#include "pch.h" 
#include "../byondapi/byondapi.h"  
#include "../byondapi/byondapi_cpp_wrappers.h" 
#include <windows.h>
#include <mutex>

static std::mutex ws_mutex;
static const char* PIPE_NAME = "\\\\.\\pipe\\byond_node_pipe";  // Match Node.js pipe name

BOOL APIENTRY DllMain(HMODULE hModule, DWORD ul_reason_for_call, LPVOID lpReserved) {
    return TRUE;
}

// Test function (synchronous)
extern "C" BYOND_EXPORT CByondValue Test(u4c n, CByondValue v[]) {
    CByondValue out;
    ByondValue_Clear(&out);
    ByondValue_SetStr(&out, "hello world");
    return out;
}

// Helper to get string from ByondValue with resizing (ai retard edition)
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

// Send JSON via IPC
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

HANDLE pipe = CreateFileA(PIPE_NAME, GENERIC_WRITE, 0, NULL, OPEN_EXISTING, 0, NULL);
if (pipe == INVALID_HANDLE_VALUE) {
    CByondValue error;
    ByondValue_SetStr(&error, "Error: Could not open named pipe");
    Byond_Return(&waiting_proc, &error);
    ByondValue_DecRef(&error);
    free(json);
    return;
}

    DWORD bytes_written;
    BOOL success = WriteFile(pipe, json, len, &bytes_written, NULL);
    CloseHandle(pipe);

    free(json);

    CByondValue result;
    if (success) {
        ByondValue_SetStr(&result, "Message sent via IPC");
    }
    else {
        ByondValue_SetStr(&result, "Failed to send message via IPC");
    }
    Byond_Return(&waiting_proc, &result);
    ByondValue_DecRef(&result);
}