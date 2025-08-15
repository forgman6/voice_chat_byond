

var/global/datum/vc/SSVOICE = new()
    
    
// shit you want the byond end to do after connection to node established
datum/vc/proc/handshaked()

datum/vc
    var/list/vc_clients = alist() //userCodes client associated thats been CONFIRMED
    var/list/userCode_client_map = alist() //userCode to clientRef
    var/list/client_userCode_map = alist() 

datum/vc/proc/link_userCode_client(userCode, client)
//    if(!client|| !userCode || !istype(client, /client)) 
    if(!client|| !userCode)
        CRASH("go fuck yourself retard userCode:[userCode], client:[client]")
    var/client_ref = ref(client)
    userCode_client_map[userCode] = client_ref
    client_userCode_map[client_ref] = userCode
    world.log << "registered userCode:[userCode] to client_ref:[client_ref]"


// this one finishes before userCode_client_map
datum/vc/proc/register_userCode(userCode)
    if(!userCode || (userCode in vc_clients))
        return
    vc_clients += userCode
    world.log << "registered [userCode]"

datum/vc/proc/send_client_locs()
    var/list/params = alist(cmd = "loc")
    for(var/userCode in vc_clients)
        var/mob/M = locate(userCode_client_map[userCode])?.mob
        if(!M)
            continue 
        var/z = "[M.z]"
        if(!params[z])
            params[z] = alist()
        params[z][userCode] = list(M.x, M.y)
    send_json(params)

datum/vc/proc/toggle_active(userCode, is_active)
    if(!userCode || isnull(is_active))
        // CRASH("null params")
        return
    var/mob/M = locate(src.userCode_client_map[userCode])?.mob
    if(!M)
        return
    var/image/speaker = image('icons/speaker.dmi',pixel_y=32, pixel_x=8)
    speaker.opacity = 200
    if(is_active)
        M.overlays += speaker
    else
        M.overlays -= speaker

datum/vc/proc/mute_mic(mob_ref, deafen=FALSE)
    if(!mob_ref)
        return
    var/userCode = client_userCode_map[mob_ref]
    if(!userCode)
        return
    var/params = alist(cmd = deafen ? "deafen" : "mute_mic", userCode = userCode)
    send_json(params)