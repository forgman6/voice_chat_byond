

var/global/datum/vc/SSVOICE = new()
    
    
datum/vc/proc/handshaked()


datum/vc
    //userCodes client associated thats been fully confirmed - browser paired and mic perms on
    var/list/vc_clients = list() 
    //userCode to clientRef
    var/list/userCode_client_map = alist()
    var/list/client_userCode_map = alist() 
    //list of all rooms to add at round start
    var/list/rooms_to_add = list("blue", "red", "green") 
    //a list all currnet rooms 
    //change with add_rooms and remove_rooms.
    var/list/current_rooms = alist() 
    //usercode to list (userCodes) that can see mob speaking overlay
    var/list/overlay_viewers = alist()

datum/vc/New()
    . = ..()
    add_rooms(rooms_to_add)
    //each zlevel is also stored as a room
    add_zlevels()

client  
    // treated like its own zlevel if set, so anyone with room var will can talk to eachother through proximity chat
    // useful for shit like ghost, or team mobs like xenos or maybe even capture the flag teams
    var/room
    // for use in overlay management hell
    var/image/speaker_icon

#ifdef DEBUG
fake_client
    var/mob/mob
    var/room
    var/image/speaker_icon
    var/list/images = list()
#endif

//run at start or when ever new zlevel is added
datum/vc/proc/add_zlevels()
    var/list/rooms_to_add = list()
    for(var/zlevel=1, zlevel<=world.maxz, zlevel++)
        rooms_to_add += num2text(zlevel)
    add_rooms(rooms_to_add, zlevel_mode = TRUE)
    // world.log << json_encode(current_rooms)

datum/vc/proc/add_rooms(list/rooms, zlevel_mode = FALSE)

    if(!islist(rooms))
        rooms = list(rooms)
    rooms.Remove(current_rooms) //remove existing rooms
    for(var/room in rooms)
        if(isnum(room) && !zlevel_mode)
            // CRASH("rooms cannot be numbers {room: [room]}")
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
    if(!room || !current_rooms.Find(room) || userCode in current_rooms[room])
        return
    var/client/C = locate(userCode_client_map[userCode])
    if(!C)
        // CRASH("dumb faggot {userCode: [userCode], client: [C || "null"]}")
        return
    if(current_rooms[C.room])
        // remove_overlay_from_room(userCode, C.room)
        current_rooms[C.room] -= userCode
    C.room = room
    current_rooms[room] += userCode
    // add_overlay_to_room(userCode, room)


// datum/vc/proc/add_overlay_to_room(own_userCode, room)
//     if(!own_userCode || !room || !current_rooms.Find(room))
//         return
//     var/client/own_client = locate(userCode_client_map[own_userCode])
//     if(!own_client)
//         return
//     for(var/userCode in current_rooms[room])
//         var/client/C = locate(userCode_client_map[userCode])
//         C.images += own_client.speaker_icon

// datum/vc/proc/remove_overlay_from_room(own_userCode, room)
//     if(!own_userCode || !room || !current_rooms.Find(room))
//         CRASH("bad params {own_userCode: [own_userCode ], room: [room || "null"], found_room: [current_rooms.Find(room) || "null"]}")
//         return
//     var/client/own_client = locate(userCode_client_map[own_userCode])
//     if(!own_client)
//         CRASH("no client {own_client [own_client || "null"]}")
//         return
//     for(var/userCode in current_rooms[room])
//         var/client/C = locate(userCode_client_map[userCode])
//         C.images -= own_client.speaker_icon


datum/vc/proc/link_userCode_client(userCode, client)
    if(!client|| !userCode)
        CRASH("go fuck yourself retard {userCode: [userCode || "null"], client: [client  || "null"]}")
    var/client_ref = ref(client)
    userCode_client_map[userCode] = client_ref
    client_userCode_map[client_ref] = userCode
    world.log << "registered userCode:[userCode] to client_ref:[client_ref]"

//called with both browser is paired and mic access granted
datum/vc/proc/confirm_userCode(userCode)
    if(!userCode || (userCode in vc_clients))
        return
    vc_clients += userCode
    //move_user to zlevel as default room
    var/client/C = locate(userCode_client_map[userCode])
    var/mob/M = C.mob
    move_userCode_to_room(userCode, num2text(M.z))
    world.log << "confirmed [userCode]"

datum/vc/proc/send_client_locs()
    var/list/params = alist(cmd = "loc")
    for(var/userCode in vc_clients)
        var/client/C = locate(userCode_client_map[userCode])
        var/room = C.room
        if(!C || !room)
            continue 
        var/atom/M = C.mob
        if(!M)
            continue
        if(!params[room])
            params[room] = alist()
        params[room][userCode] = list(M.x, M.y)
    send_json(params)


datum/vc/proc/toggle_active(userCode, is_active)
    if(!userCode || isnull(is_active))
        // CRASH("null params go fuck yourself retard")
        return
    var/client/C = locate(userCode_client_map[userCode])
    var/atom/M = C.mob
    var/image/speaker = image('icons/speaker.dmi', pixel_y=32, pixel_x=8)
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
        CRASH("your a retarded faggot {userCode: [userCode || "null"]}")
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
    del(src?.mob)
    