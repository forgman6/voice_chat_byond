// Connects a client to voice chat via an external browser
/datum/controller/subsystem/voicechat/proc/join_vc(client/C, show_link_only=FALSE)
	if(!C)
		return
	// Disconnect existing session if present
	var/existing_userCode = client_userCode_map[C]
	if(existing_userCode)
		disconnect(existing_userCode, from_byond = TRUE)

	// Generate unique session and user codes
	var/sessionId = md5("[world.time][rand()][world.realtime][rand(0,9999)][C.address][C.computer_id]")
	var/userCode = generate_userCode(C)
	if(!userCode)
		return

	// Open external browser with voice chat link
	var/address = src.domain || world.internet_address
	var/web_link = "https://[address]:[node_port]?sessionId=[sessionId]"
	#ifdef TESTING
	web_link = "https://localhost:[node_port]?sessionId=[sessionId]"
	#endif
	if(!show_link_only)
		C << link(web_link)
	else
		C << browse({"
		<html>
			<body>
				<h3>[web_link]</h3>
				<p>copy and paste the link into your web browser of choice, or scan the qr code.</p>
				<img src="https://api.qrserver.com/v1/create-qr-code/?data=${encodeURIComponent([web_link])}&size=150x150">
			</body>
		</html>"}, "window=voicechat_help")


	send_json(alist(
		cmd = "register",
		userCode = userCode,
		sessionId = sessionId
	))

	// Link client to userCode
	userCode_client_map[userCode] = C
	client_userCode_map[C] = userCode
	// Confirmation handled in confirm_usekrCode


// Confirms userCode when browser and mic access are granted
/datum/controller/subsystem/voicechat/proc/confirm_userCode(userCode)
	if(!userCode || (userCode in vc_clients))
		return
	var/client/C = userCode_client_map[userCode]
	var/mob/M = C.mob
	if(!C || !M)
		disconnect(userCode)
		return
	mob_client_map[M] = C

	vc_clients += userCode
	move_userCode_to_room(userCode, "living")

// Disconnects a user from voice chat
/datum/controller/subsystem/voicechat/proc/disconnect(userCode, from_byond = FALSE)
	if(!userCode)
		return
	toggle_active(userCode, FALSE)
	clear_userCode(userCode)

	var/client/C = userCode_client_map[userCode]
	if(C)
		userCode_client_map.Remove(userCode)
		client_userCode_map.Remove(C)
		userCode_room_map.Remove(userCode)
		vc_clients -= userCode

	var/mob/M = C.mob

	if(userCodes_speaking_icon[userCode])
		if(C && M)
			M.overlays -= userCodes_speaking_icon[userCode]
			// unregister_mob_signals(M)

	if(from_byond)
		send_json(alist(cmd= "disconnect", userCode= userCode))
	// //for lobby chat

	// if(SSticker.current_state < GAME_STATE_PLAYING)
	// 	send_locations()

// Toggles the speaker overlay for a user
/datum/controller/subsystem/voicechat/proc/toggle_active(userCode, is_active)
	if(!userCode || isnull(is_active))
		return
	var/client/C = userCode_client_map[userCode]

	if(!C || !C.mob)
		return
	var/mob/M = C.mob
	if(!userCodes_speaking_icon[userCode])
		var/image/speaker = image('icons/talk.dmi', icon_state = "voice")
		speaker.alpha = 200
		userCodes_speaking_icon[userCode] = speaker

	var/image/speaker = userCodes_speaking_icon[userCode]
	var/mob/old_mob = userCode_mob_map[userCode]
	if(M != old_mob)
		if(old_mob)
			old_mob.overlays -= speaker
		userCode_mob_map[userCode] = M
	var/room = userCode_room_map[userCode]
	if(is_active && room)
		userCodes_active |= userCode
		M.overlays |= speaker
	else
		userCodes_active -= userCode
		M.overlays -= speaker

// Mutes or deafens a user's microphone
/datum/controller/subsystem/voicechat/proc/mute_mic(client/C, deafen = FALSE)
	if(!C)
		return
	var/userCode = client_userCode_map[C]
	if(!userCode)
		return
	send_json(list(
		cmd = deafen ? "deafen" : "mute_mic",
		userCode = userCode
	))