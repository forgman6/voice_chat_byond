/mob/verb/join_vc()
	src << browse({"
	<html>
	<h2>Experimental Proximity Chat)</h2>
	<p>if the browser fails to open try "join vc external" instead</p>
	<p>This command should open an external broswer.<br>
	1. ignore the bad cert and continue onto the site.<br>
	2. When prompted, allow mic perms and then you should be set up.<br>
	3. To verify this is working, look for a speaker overlay over your mob in-game.</p>
	4. drag the voicechat to its own window so its only the active tab - why? if you open a different tab it stops detecting microphone input. The easiest way to ensure the tab is active, is to drag it to its own window.
	<h4>other verbs</h4>
	<p>mute - mutes yourself<br>
	deafen - deafens yourself<br>
	<h4>issues</h4>
	<p>To try to solve yourself, ensure browser extensions are off and if you are comfortable with it, turn off your VPN.
	Additionally try setting firefox as your default browser as that usually works best</p>
	<h4>reporting bugs</h4>
	<p> If your are still having issues, its most likely with rtc connections, (roughly 10% connections fail). When reporting bugs, please tell us what OS and browser you are using, if you use a VPN, and send a screenshot of your browser console to us (ctrl + shift + I).
	Additionally I might ask you to navigate to about:webrtc</p>
	<h4>But Im to lazy to report a bug</h4>
	<p>contact a_forg on discord and they might not ignore you.</p>
	<img src='https://files.catbox.moe/mkz9tv.png>
	</html>"}, "window=voicechat_help")

	if(SSvoicechat)
		SSvoicechat.join_vc(client)

/mob/verb/join_vc_external()
	if(SSvoicechat)
		SSvoicechat.join_vc(client, show_link_only=TRUE)

/mob/verb/mute_self()
	if(SSvoicechat)
		SSvoicechat.mute_mic(client)


/mob/verb/deafen()
	if(SSvoicechat)
		SSvoicechat.mute_mic(client, deafen=TRUE)


#ifdef TESTING
/mob/verb/restart()
	if(SSvoicechat)
		SSvoicechat.restart()


/mob/verb/try_shutdown()
	if(SSvoicechat)
		SSvoicechat.stop_node()

/mob/verb/make_dummy_client()
	var/global/number = 1
	var/list/paramstuff = alist(cmd="register")
	var/sessionId = "dummy_[number]"
	number ++
	src << link("https://localhost:[SSvoicechat.node_port]?sessionId=[sessionId]")
	paramstuff["userCode"] = "[sessionId]"
	paramstuff["sessionId"] = "[sessionId]"
	SSvoicechat.send_json(paramstuff)
	var/mob/dummy_mob = new(loc)
	dummy_mob.tag = sessionId
	dummy_mob.name = sessionId
	var/fake_client/C = new
	C.mob = dummy_mob
	dummy_mob.dummy_client = C
	SSvoicechat.link_userCode_client(sessionId, C)

/mob/verb/change_room(userCode in SSvoicechat.vc_clients, room in SSvoicechat.current_rooms)
	SSvoicechat.move_userCode_to_room(userCode, room)

/mob/verb/add_room(room as text)
	SSvoicechat.add_rooms(room)


/mob/verb/start_ping()
	SSvoicechat.pinging = TRUE

/mob/verb/stop_ping()
	SSvoicechat.pinging = FALSE

#endif