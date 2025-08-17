world/New()
    . = ..()
    //lifecycle shit
    var/sneedport = 1337
    OpenPort(sneedport)
    spawn() start_processing()
    spawn() shell("node ./webrtc/server/main.js --byond-port=[sneedport]")

proc/start_processing()
    while(1)
        if(SSVOICE && (length(SSVOICE.vc_clients) > 1))
            SSVOICE.send_client_locs()
        sleep(5)

world/Del()
    . = ..()
    //lifecycle shit
    var/params = alist(cmd="stop_node")    
    send_json(params)
    //byond kills the shell proc, wish someone fucking told me that
    sleep(30) //let the server run cleanup before getting raped: 
    return //if its still up after 3 seconds kill the damn thing
