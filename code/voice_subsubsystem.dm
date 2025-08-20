

var/global/datum/vc/SSVOICE = new()
    
    
datum/vc/proc/handshaked()


datum/vc
    var/list/vc_clients = list() //userCodes client associated thats been CONFIRMED
    var/list/userCode_client_map = alist() //userCode to clientRef
    var/list/client_userCode_map = alist() 
    var/list/room_names = list() //list of all rooms to add at round start
    var/list/current_rooms = alist() //a list of all existing rooms change with add_rooms and remove_rooms.
    var/list/userCode_overlay_viewers = alist() //usercode to list (userCodes) that can see mob speaking overlay

datum/vc/New()
    . = ..()
    add_rooms(room_names)
    add_zlevels()

client  
    var/room //treated like its own zlevel if set, so anyone with room var will can talk to eachother through proximity chat
            // useful for shit like ghost, or team mobs like xenos or maybe even capture the flag teams
#ifdef DEBUG
fake_client
    var/mob/mob
    var/room
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
    if(!current_rooms.Find(room) || userCode in current_rooms[room])
        return
    var/client/C = locate(userCode_client_map[userCode])
    if(!C)
        // CRASH("dumb faggot {userCode: [userCode], client: [C || "null"]}")
        return
    if(current_rooms[C.room])
        current_rooms[C.room] -= userCode
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


datum/vc/proc/confirm_userCode(userCode)
    if(!userCode || (userCode in vc_clients))
        return
    vc_clients += userCode
    //move_user to zlevel as default room
    var/client/C = locate(userCode_client_map[userCode])
    move_userCode_to_room(userCode, num2text(C.mob.z))
    world.log << "confirmed [userCode]"

datum/vc/proc/send_client_locs()
    var/list/params = alist(cmd = "loc")
    for(var/userCode in vc_clients)
        var/mob/M = locate(userCode_client_map[userCode])?.mob
        if(!M)
            continue 
        #ifdef DEBUG
        var/client/client = M.client || M.dummy_client
        #else
        var/client/client = M.client
        #endif

        var/room = client.room
        if(isnull(room))
            continue

        if(!params[room])
            params[room] = alist()
        params[room][userCode] = list(M.x, M.y)
    send_json(params)

datum/vc/proc/toggle_active(userCode, is_active)
    if(!userCode || isnull(is_active))
        // CRASH("null params go fuck yourself retard")
        return
    var/mob/M = locate(src.userCode_client_map[userCode])?.mob
    if(!M)
        return
    var/image/speaker = image('icons/speaker.dmi',pixel_y=32, pixel_x=8, loc=M)
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
    del(src?.mob)
    