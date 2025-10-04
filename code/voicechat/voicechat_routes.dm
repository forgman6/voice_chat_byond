


/datum/controller/subsystem/voicechat/proc/test_library()
	var/text = "hello word"
	var/out = call_ext(src.lib_path, "byond:Echo")(text)
	var/confirmed = (out == text)
	return confirmed



/proc/json_encode_sanitize(list/data)
	. = json_encode(data)
	//NOT in: alphanumeric, ", {}, :, commas, spaces, []
	var/static/regex/r = new/regex(@'[^\w"{}:.,\s\[\]]', "g")
	. = r.Replace(., "")
	. = replacetext(., "\\", "\\\\")
	return .

	
/datum/controller/subsystem/voicechat/proc/send_json(list/data)
	var/json = json_encode_sanitize(data)
	#ifdef LOG_TRAFFIC
	world << "BYOND: [json]"
	#endif
	call_ext(src.lib_path, "byond:SendJSON")(json)

/datum/controller/subsystem/voicechat/proc/handle_topic(T, addr)
	if(addr != "127.0.0.1")
		return

	var/list/data = json_decode(T)
	if(data["error"])
		world << T
		return

	#ifdef LOG_TRAFFIC
	world << "NODE: [T]"
	#endif

	if(data["node_started"])
		on_node_start()
		return

	if(data["pong"])
		world << "started: [data["time"]] round trip: [world.timeofday] approx: [world.timeofday -  data["time"]] x 1/10 seconds, data: [data["pong"]]"
		return

	if(data["confirmed"])
		confirm_userCode(data["confirmed"])
		return

	if(data["voice_activity"])
		toggle_active(data["voice_activity"], data["active"])
		return
	if(data["disconnect"])
		disconnect(userCode= data["disconnect"])
		
/world/Topic(T, Addr, Master, Keys)
	. = ..()
	if(SSvoicechat && Addr != "127.0.0.1")
		SSvoicechat.handle_topic(T, Addr)