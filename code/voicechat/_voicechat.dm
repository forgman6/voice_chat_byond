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
	/// faster tick times means smoother proximity. If machine is lagging, increase.
	var/wait = 3 //300 ms
	// flags = SS_KEEP_TIMING
	// init_order = INIT_ORDER_VOICECHAT
	// runlevels = RUNLEVEL_GAME|RUNLEVEL_POSTGAME
	//userCodes associated thats been fully confirmed - browser paired and mic perms on
	var/list/vc_clients = list()
	//userCode to clientRef
	var/list/userCode_client_map = alist()
	var/list/client_userCode_map = alist()
	//change with add_rooms and remove_rooms.
	var/list/current_rooms = alist()
	// usercode to room
	var/list/userCode_room_map = alist()
	// usercode to mob only really used for the overlays
	var/list/userCode_mob_map = alist()
	// mob to client map, needed for tracking switched mobs
	var/list/mob_client_map = alist()
	// used to manage overlays
	var/list/userCodes_active = list()
	// each speaker per userCode
	var/list/userCodes_speaking_icon = alist()
	//list of all rooms to add at round start
	var/list/rooms_to_add = list("living", "ghost")
	//holds a normal list of all the ckeys and list of all usercodes that muted that ckey
	var/list/ckey_muted_by = alist()
	//node server path
	var/const/node_path = "voicechat/node/server/main.js"
	//library path set in get lib path
	var/lib_path
	//if you have a domain, put it here.
	var/const/domain
	var/pinging
	var/node_port = 3000


/datum/controller/subsystem/voicechat/New()
	. = ..()
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
	set_lib_path()
	if(!test_library())
		return SS_INIT_FAILURE

	add_rooms(rooms_to_add)
	start_node()
	return SS_INIT_SUCCESS


/datum/controller/subsystem/voicechat/proc/set_lib_path()
	var/const/lib_path_unix = "voicechat/pipes/unix/byondsocket"
	var/const/lib_path_win = "voicechat/pipes/windows/byondsocket/Release/byondsocket"
	if(world.system_type == MS_WINDOWS)
		lib_path = lib_path_win
	else
		lib_path = lib_path_unix


/datum/controller/subsystem/voicechat/proc/restart()
	message_admins("voicechat_restarting, please reconnect with join_vc")
	disconnect_all_clients()
	stop_node()
	spawn(5) start_node()

/datum/controller/subsystem/voicechat/proc/on_ice_failed(userCode)
	if(!userCode)
		CRASH("ice_failed error without usercode {userCode: [userCode || "null"]")
	var/client/C = userCode_client_map[userCode]
	message_admins("voicechat peer connection failed for [C || userCode]")


/datum/controller/subsystem/voicechat/proc/start_node()
	// byond port used for topic calls
	world.OpenPort(1337) // spaceman(vs launch with debuging) kind of gets weird if we dont specify a port
	var/byond_port = world.port
	var/cmd = "node [src.node_path] --node-port=[node_port] --byond-port=[byond_port] --byond-pid=[world.process] &"
	if(world.system_type == MS_WINDOWS) // ape shit insane but its ok :)
		cmd = "powershell.exe -Command \"Start-Process -FilePath 'node' -ArgumentList '[src.node_path]','--node-port=[node_port]','--byond-port=[byond_port]', '--byond-pid=[world.process]'\""
	var/exit_code = shell(cmd)
	if(exit_code != 0)
		message_admins("launching node failed {exit_code: [exit_code || "null"], cmd: [cmd || "null"]}")
	else
		return TRUE
	
/datum/controller/subsystem/voicechat/Del()
	stop_node()
	. = ..()

/datum/controller/subsystem/voicechat/proc/disconnect_all_clients()
	for(var/userCode in vc_clients)
		disconnect(userCode, from_byond = TRUE)

/datum/controller/subsystem/voicechat/proc/stop_node()
	send_json(alist(cmd="stop_node"))
	spawn(5) ensure_node_stopped()


/datum/controller/subsystem/voicechat/proc/ensure_node_stopped()
	var/pid = file2text("data/node.pid")
	if(!pid)
		return TRUE

	message_admins("node failed to shutdown when asked, trying forcefully...")

	var/cmd = "kill [pid]"
	if(world.system_type == MS_WINDOWS)
		cmd = "taskkill /F /PID [pid]"
	var/exit_code = shell(cmd)

	if(exit_code != 0)
		message_admins("killing node failed {exit_code: [exit_code || "null"], cmd: [cmd || "null"]}")
	else
		message_admins("node shutdown forcefully")
		fdel("data/node.pid")

/datum/controller/subsystem/voicechat/proc/verify_node_stopped()

//mock fire proc
/datum/controller/subsystem/voicechat/proc/fire()
	send_locations()
	if(pinging)
		ping_node()

/datum/controller/subsystem/voicechat/proc/on_node_start()
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

/datum/controller/subsystem/voicechat/proc/clear_userCode(userCode)
	var/own_room = userCode_room_map[userCode]
	if(own_room)
		current_rooms[own_room] -= userCode

	userCode_room_map[userCode] = null
	message_admins("clear room worked room [userCode_room_map[userCode] || "null"]")

/datum/controller/subsystem/voicechat/proc/move_userCode_to_room(userCode, room)
	if(!room || !current_rooms.Find(room))
		return

	var/own_room = userCode_room_map[userCode]
	if(own_room)
		current_rooms[own_room] -= userCode

	userCode_room_map[userCode] = room
	current_rooms[room] += userCode
	message_admins("move to room worked room [userCode_room_map[userCode] || "null"]")



/datum/controller/subsystem/voicechat/proc/link_userCode_client(userCode, client)
	if(!client|| !userCode)
		// CRASH("{userCode: [userCode || "null"], client: [client  || "null"]}")
		return
	userCode_client_map[userCode] = client
	client_userCode_map[client] = userCode

// faster the better
/datum/controller/subsystem/voicechat/proc/send_locations()
	var/list/params = list(cmd = "loc")
	var/locs_sent = 0

	for(var/userCode in vc_clients)
		var/client/C = userCode_client_map[userCode]
		var/room =  userCode_room_map[userCode]
		if(!C || !room)
			continue
		var/mob/M = C.mob
		if(!M)
			continue
		var/turf/T = get_turf(M)
		var/localroom = "[T.z]_[room]"
		if(!params[localroom])
			params[localroom] = list()
		params[localroom][userCode] = list(T.x, T.y)
		locs_sent ++

	if(!locs_sent) //dont send empty packets
		return
	send_json(params)


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


/datum/controller/subsystem/voicechat/proc/ping_node()
	var/list/data = alist(cmd = "ping", message = "Hello from BYOND!", time=world.timeofday)
	send_json(data)

	