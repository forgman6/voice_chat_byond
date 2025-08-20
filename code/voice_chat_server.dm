#define BYONDPORT 1337
#define NODEPORT 3312

world/New()
    . = ..()
    //lifecycle shit
    OpenPort(BYONDPORT)
    spawn() start_processing()
    spawn() shell("node ./webrtc/server/main.js --byond-port=[BYONDPORT] --node-port=[NODEPORT]")

proc/start_processing()
    while(1)
        if(SSVOICE && (length(SSVOICE.vc_clients) > 1))
            SSVOICE.send_client_locs()
        sleep(3) //300ms

world/Del()
    . = ..()
    //lifecycle shit
    var/params = alist(cmd="stop_node")    
    send_json(params)
    //byond kills the shell proc, wish someone fucking told me that
    sleep(30) //let the server run cleanup before getting raped: 
    return //if its still up after 3 seconds kill the damn thing
