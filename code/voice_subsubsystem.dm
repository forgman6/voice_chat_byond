

var/global/datum/vc/SSVOICE = new()
    
    
datum/vc/proc/handshaked()
    return

datum/vc
    var/list/vc_clients = alist() //userCodes client associated thats been CONFIRMED
    var/list/userCode_client_map = alist() //userCode to clientRef
    var/list/client_userCode_map = alist() 
    var/list/room_names = list() //list of all rooms to add at round start
    var/list/current_rooms = alist() //a list of all existing rooms change with add_rooms and remove_rooms.
    

datum/vc/New()
    . = ..()
    add_rooms(room_names)

client  
    var/room //treated like its own zlevel if set, so anyone with room var will can talk to eachother through proximity chat
            // useful for shit like ghost, or team mobs like xenos or maybe even capture the flag teams
#ifdef DEBUG
fake_client
    var/mob/mob
    var/room
#endif

datum/vc/proc/add_rooms(list/rooms)

    if(!islist(rooms))
        rooms = list(rooms)
    rooms.Remove(current_rooms) //remove existing rooms
    for(var/room in rooms)
        if(isnum(room))
            CRASH("rooms cannot be numbers {room: [room]}")
            continue
        current_rooms[room] = list()

datum/vc/proc/remove_rooms(list/rooms)
    if(!islist(rooms))
        rooms = list(rooms)
    rooms &= current_rooms //remove nonexistant rooms
    for(var/room in rooms)
        for(var/userCode in current_rooms[room])
            var/client/C = locate(userCode_client_map[userCode])
            if(!C)
                continue
            C.room = null
        current_rooms.Remove(room)

datum/vc/proc/move_userCode_to_room(userCode, room)
    if(!current_rooms.Find(room) || userCode in current_rooms[room])
        return
    var/client/C = locate(userCode_client_map[userCode])
    if(!C)
        // CRASH("dumb faggot {userCode: [userCode], client: [C || "null"]}")
        return
    C.room = room
    current_rooms[room] += userCode

datum/vc/proc/link_userCode_client(userCode, client)
    #ifndef DEBUG //for dummyclients
    if(!client|| !userCode || !istype(client, /client)) 
    #else
    if(!client|| !userCode)
    #endif
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
        var/z
        #ifdef DEBUG
        var/client/client = M.client || M.dummy_client
        #else
        var/client/client = M.client
        #endif
        if(client.room)
            z = client.room
        else
            z = "[M.z]"
            
        if(!params[z])
            params[z] = alist()
        params[z][userCode] = list(M.x, M.y)
    send_json(params)

datum/vc/proc/toggle_active(userCode, is_active)
    if(!userCode || isnull(is_active))
        // CRASH("null params go fuck yourself retard")
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


datum/vc/proc/disconnect(userCode, from_byond= FALSE)
    if(!userCode)
        CRASH("your a retarded faggot userCode: [userCode || "null"]")
        return

    toggle_active(userCode, FALSE)
    var/client_ref = userCode_client_map[userCode]
    userCode_client_map.Remove(userCode)
    client_userCode_map.Remove(client_ref)

    if(from_byond)
        send_json(alist(cmd="disconnect", userCode=userCode))
    vc_clients -= userCode

client/Del()
    var/userCode = SSVOICE.client_userCode_map[ref(src)]
    if(userCode)
        SSVOICE.disconnect(userCode, from_byond= TRUE)
    . = ..()
    