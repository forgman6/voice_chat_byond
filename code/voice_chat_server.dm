
world/New()
    . = ..()
    //lifecycle shit
    var/sneedport = 1337
    OpenPort(sneedport)
    world.log << call_ext(get_lib(), "byond:Test")()
    // spawn() start_process()
    spawn() shell("node ./webrtc/server/main.js --byond-port=[sneedport]")

proc/start_process()
    while(1)
        sleep(10)
        if(!SSVOICE || !SSVOICE.prox_in_use)
            continue
        SSVOICE.send_client_locs()


world/Del()
    . = ..()
    //lifecycle shit
    var/params = alist(cmd="stop_node")    
    send_json(params)
    //byond kills the shell proc, wish someone fucking told me that
    sleep(30) //let the server run cleanup before getting raped: 
    return //if its still up after 3 seconds kill the damn thing
