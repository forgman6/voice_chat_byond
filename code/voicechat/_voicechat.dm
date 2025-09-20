#define TESTING //uncomment to allow more verbs, and creation of fake players
// #define LOG_TRAFFIC //uncomment to show byond and node traffic
#ifdef TESTING
/fake_client
    var/mob/mob
    var/image/speaker_icon
    var/list/images = list()
#endif

//controller isnt defined, the path is used to make adding this easier
/datum/controller/subsystem/voicechat
    var/name = "Voice Chat"
    var/wait = 3 //300 ms
    // flags = SS_KEEP_TIMING
    // init_order = INIT_ORDER_VOICECHAT //close to last
    // runlevels = RUNLEVEL_GAME|RUNLEVEL_POSTGAME 

    //     --list shit--

    //userCodes associated thats been fully confirmed - browser paired and mic perms on
    var/list/vc_clients = list()
    //userCode to clientRef
    var/list/userCode_client_map = alist()
    var/list/client_userCode_map = alist()

    //a list all currnet rooms
    //change with add_rooms and remove_rooms.
    var/list/current_rooms = alist()
    //list of rooms with direct chat (no proximity)
    var/list/direct_rooms = list()
    // usercode to room
    var/list/userCode_room_map = alist()
    // usercode to mob only really used for the overlays
    var/list/userCode_mob_map = alist()
    // used to ensure rooms are always updated
    var/list/userCodes_active = list()
    // each speaker per userCode
    var/list/userCodes_speaking_icon = alist()
    //list of all rooms to add at round start
    var/list/rooms_to_add = list("living", "ghost") // xeno, marines, admin, etc
    //holds a normal list of all the ckeys and list of all usercodes that muted that ckey
    var/list/ckey_muted_by = alist()
    // if the server and node have successfully communicated
    var/handshaked = FALSE\
    #ifdef TESTING
    var/pinging = FALSE
    #endif
    //   --subsystem "defines"--

    //which port to run the node websockets
    var/const/node_port = 3000
    //node server path
    // var/const/node_path = "voicechat/node/server/main.js"
    var/const/node_path = "voicechat/node/server/main.js"
    //library path
    var/lib_path
    var/const/lib_path_unix = "voicechat/pipes/unix/byondsocket"
    var/const/lib_path_win = "voicechat/pipes/windows/byondsocket/Release/byondsocket" 
    //if you have a domain, put it here.
    var/const/domain


/datum/controller/subsystem/voicechat/New()
    . = ..()

    if(world.system_type == MS_WINDOWS)
        lib_path = lib_path_win
    else
        lib_path = lib_path_unix

    //mock proc Initialize
    var/init_status = Initialize()
    if(init_status & ~SS_INIT_SUCCESS)
        return

    //mock firing setup
    spawn() start_firing()

/datum/controller/subsystem/voicechat/proc/start_firing()
    while(TRUE)
        sleep(wait)
        fire()

/datum/controller/subsystem/voicechat/proc/Initialize()
    if(!test_library())
        return SS_INIT_FAILURE
    add_rooms(rooms_to_add)
    start_node()
    return SS_INIT_SUCCESS


/datum/controller/subsystem/voicechat/proc/start_node()
    // byond port used for topic calls
    world.OpenPort(1337) // spaceman(vs launch with debuging) kind of gets weird if we dont specify a port
    var/byond_port = world.port
    spawn() shell("node [src.node_path] --node-port=[src.node_port] --byond-port=[byond_port]")

/datum/controller/subsystem/voicechat/Del()
    send_json(alist(cmd= "stop_node"))
    . = ..()
    
//mock fire proc
/datum/controller/subsystem/voicechat/proc/fire()
    send_locations()
    if(pinging)
        ping_node()

/datum/controller/subsystem/voicechat/proc/handshaked()
    handshaked = TRUE
    return

/datum/controller/subsystem/voicechat/proc/add_rooms(list/rooms, zlevel_mode = FALSE)
    if(!islist(rooms))
        rooms = list(rooms)
    rooms.Remove(current_rooms) //remove existing rooms
    for(var/room in rooms)
        if(isnum(room) && !zlevel_mode)
            // CRASH("rooms cannot be numbers {room: [room]}")
            continue
        current_rooms[room] = list()

/datum/controller/subsystem/voicechat/proc/remove_rooms(list/rooms)
    if(!islist(rooms))
        rooms = list(rooms)
    rooms &= current_rooms //remove nonexistant rooms
    for(var/room in rooms)
        for(var/userCode in current_rooms[room])
            userCode_room_map[userCode] = null
        current_rooms.Remove(room)

/datum/controller/subsystem/voicechat/proc/move_userCode_to_room(userCode, room)
    if(!room || !current_rooms.Find(room))
        return

    var/own_room = userCode_room_map[userCode]
    if(own_room)
        current_rooms[own_room] -= userCode

    userCode_room_map[userCode] = room
    current_rooms[room] += userCode


/datum/controller/subsystem/voicechat/proc/link_userCode_client(userCode, client)
    if(!client|| !userCode)
        // CRASH("{userCode: [userCode || "null"], client: [client  || "null"]}")
        return
    var/client_ref = ref(client)
    userCode_client_map[userCode] = client_ref
    client_userCode_map[client_ref] = userCode
    world << "registered userCode:[userCode] to client_ref:[client_ref]"


// Confirms userCode when browser and mic access are granted
/datum/controller/subsystem/voicechat/proc/confirm_userCode(userCode)
    if(!userCode || (userCode in vc_clients))
        return
    var/client_ref = userCode_client_map[userCode]
    if(!client_ref)
        return

    vc_clients += userCode
    // log_world("Voice chat confirmed for userCode: [userCode]")
    world << "Voice chat confirmed for userCode: [userCode]"
    post_confirm(userCode)

// faster the better
/datum/controller/subsystem/voicechat/proc/send_locations()
    var/list/params = alist(cmd = "loc")
    for(var/userCode in vc_clients)
        var/client/C = locate(userCode_client_map[userCode])
        var/room =  userCode_room_map[userCode]
        if(!C || !room)
            continue
        var/mob/M = C.mob
        var/zlevel = M.z
        if(!M || !zlevel)
            continue
        var/localroom = "[zlevel]_[room]"
        if(userCode in userCodes_active)
            room_update(M)
        if(!params[localroom])
            params[localroom] = alist()
        params[localroom][userCode] = list(M.x, M.y)
    send_json(params)


// Disconnects a user from voice chat
/datum/controller/subsystem/voicechat/proc/disconnect(userCode, from_byond = FALSE)
    if(!userCode)
        return

    toggle_active(userCode, FALSE)
    var/room = userCode_room_map[userCode]
    if(room)
        current_rooms[room] -= userCode

    var/client_ref = userCode_client_map[userCode]
    if(client_ref)
        userCode_client_map.Remove(userCode)
        client_userCode_map.Remove(client_ref)
        userCode_room_map.Remove(userCode)
        vc_clients -= userCode
        
    if(userCodes_speaking_icon[userCode])
        var/client/C = locate(client_ref)
        if(C && C.mob)
            C.mob.overlays -= userCodes_speaking_icon[userCode]
            // C.mob.cut_overlay(userCodes_speaking_icon[userCode])

    if(from_byond)
        send_json(alist(cmd= "disconnect", userCode= userCode))


/datum/controller/subsystem/voicechat/proc/generate_userCode(client/C)
    if(!C)
        // CRASH("no client or wrong type")
        return
    . = copytext(md5("[C.computer_id][C.address][rand()]"),-4)
    //ensure unique
    while(. in userCode_client_map)
        . = copytext(md5("[C.computer_id][C.address][rand()]"),-4)
    return .

/datum/controller/subsystem/voicechat/proc/room_update(mob/source)
    return

// shit pattern
// /datum/controller/subsystem/voicechat/proc/room_update(mob/source)
// 	var/client/C = source.client
// 	var/userCode = client_userCode_map[ref(C)]
// 	if(!C || !userCode)
// 		return
// 	var/room
// 	switch(source.stat)
// 		if(CONSCIOUS to SOFT_CRIT)
// 			room = "living"
// 		if(UNCONSCIOUS to HARD_CRIT)
// 			room = null
// 		else
// 			room = "ghost"
// 	if(userCode_room_map[userCode] != room)
// 		move_userCode_to_room(userCode, room)


/datum/controller/subsystem/voicechat/proc/ping_node()
    var/list/data = alist(cmd = "ping", message = "Hello from BYOND!", time=world.timeofday)
    send_json(data)

    