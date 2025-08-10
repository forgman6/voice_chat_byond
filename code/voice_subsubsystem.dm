

var/global/datum/vc/SSVOICE = new()
    
    
// shit you want the byond end to do after connection to node established
datum/vc/proc/handshaked()
    add_rooms(list("a","b"), list("b"))

datum/vc
    var/list/rooms = alist("NONE" = list()) //none must be set
    var/list/proximity_rooms = alist() //list of rooms that need proxmity chat key is room name, value is bool if its in use
    var/prox_in_use = FALSE
    var/list/vc_clients = alist() //userCodes client associated thats been CONFIRMED
    var/list/userCode_client_map = alist() //userCode to clientRef
    var/list/client_userCode_map = alist() 
    var/list/userCode_current_room_map = alist()

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
    userCode_current_room_map[userCode] = "NONE"
    rooms["NONE"] += userCode
    world.log << "registered [userCode]"

// prox whether or not room will be in proximity mode
datum/vc/proc/add_room(room_name, prox=FALSE)
    if(!room_name || (room_name in rooms) || room_name == "NONE")
        return
    rooms[room_name] = list()
    var/params = alist(cmd = "alterRooms", add_room = room_name)
    if(prox)
        params["prox"] = TRUE
        proximity_rooms[room_name] = FALSE
    send_json(params)

// prox_rooms list of rooms in room_names that should be in proximity mode
// prox_rooms checking contents is done node side because its faster
datum/vc/proc/add_rooms(list/room_names, list/prox_rooms)
    if(!room_names || !islist(room_names) || !length(room_names))
        return
    var/rooms_added = list()
    for(var/room_name in room_names)
        if(room_name in rooms || room_name == "NONE")
            continue
        rooms[room_name] = list()
        rooms_added += room_name
    if(!length(rooms_added))
        return
    var/params = alist(cmd= "alterRooms", add_rooms= rooms_added )
    if(length(prox_rooms))
        prox_rooms &= rooms
        for(var/room_name in prox_rooms)
            proximity_rooms[room_name] = FALSE
        params["proximity_rooms"] = prox_rooms
    send_json(params) 

        
datum/vc/proc/remove_room(room_name)
    if(!room_name || room_name == "NONE" || !(room_name in rooms))
        return
    rooms[room_name]?.len = 0
    rooms.Remove(room_name)
    if(room_name in proximity_rooms)
        proximity_rooms.Remove(room_name)
    var/params = alist(cmd = "alterRooms", remove_room = room_name)
    send_json(params)


//pass "NONE" to remove client from all rooms (actually just moves the client into a room called NONE which is not processed)
datum/vc/proc/move_client_to_room(room_name="NONE", client/C)
    if(!room_name || !C || !(room_name in rooms))
        return
    var/userCode =  client_userCode_map[ref(C)]
    if(!userCode || !(userCode in vc_clients))
        return
    var/params = alist(cmd = "changeRoom", userCode = userCode, room_name = room_name)
    var/current_room = userCode_current_room_map[userCode]
    rooms[current_room] -= userCode
    rooms[room_name] += userCode
    check_prox_rooms(current_room, room_name)
    userCode_current_room_map[userCode] = room_name
    send_json(params)
    
datum/vc/proc/check_prox_rooms(last_room, new_room) 
    if(last_room in proximity_rooms)
        if(!length(rooms[last_room]))
            proximity_rooms[last_room] = FALSE

    if(new_room in proximity_rooms)
        proximity_rooms[new_room] = TRUE
        prox_in_use = TRUE
        return
    for(var/i,prox_room_full_bool in proximity_rooms)
        if(prox_room_full_bool)
            prox_in_use = TRUE
            return
    prox_in_use = FALSE


datum/vc/proc/send_client_locs()
    var/list/params = alist(cmd = "loc")
    var/list/output_rooms = alist()
    for(var/room_name, occupied_bool in proximity_rooms)
        if(!occupied_bool)
            continue
        var/list/current_room = alist()
        for(var/userCode in rooms[room_name])
            var/mob/M = locate(userCode_client_map[userCode])?.mob
            if(!M)
                continue 
            current_room[userCode] = list(M.x, M.y, M.z)
        output_rooms[room_name] = current_room
    params["rooms"] = output_rooms
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