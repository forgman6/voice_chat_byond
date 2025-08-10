proc/json_encode_sanitize(list/data)
    . = json_encode(data)
    //NOT in: alphanumeric, ", {}, :, commas, spaces, []
    var/static/regex/r = new/regex(@'[^\w"{}:,\s\[\]]', "g")
    // Replace unwanted characters with empty string
    . = r.Replace(., "")
    // Escape quotes and backslashes for command-line safety
    . = replacetext(., "\\", "\\\\")
    return .

proc/get_lib()
    var/static/LIB_NAME = ((world.system_type == "UNIX") ? "pipes/linux/pipes.so" : "pipes/Release/pipes.dll")
    . = LIB_NAME
    return .

proc/send_json(list/data)
    var/json = json_encode_sanitize(data)
    #ifdef LOG_TRAFFIC
    world.log << "BYOND: [json]"
    #endif
    call_ext(get_lib(), "byond:SendJSON")(json, length(json))

        
world/Topic(T, Addr, Master, Keys)
    if(Addr != "127.0.0.1")
        return
    . = ..()

    var/list/data = json_decode(T)
    if(data["error"])
        world.log << T
        return

    #ifdef LOG_TRAFFIC
    world.log << "NODE: [T]"
    #endif

    if(data["server_ready"])
        SSVOICE.handshaked()
        return

    if(data["pong"])
        world.log << "started: [data["time"]] round trip: [world.timeofday] approx: [world.timeofday -  data["time"]] x 1/10 seconds, data: [data["pong"]]"
        return

    if(data["registered"])
        SSVOICE.register_userCode(data["registered"])
        return

    if(data["voice_activity"])
        SSVOICE.toggle_active(data["voice_activity"], data["active"])    
        return