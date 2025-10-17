/mob/verb/join_vc()
	set name = "Join"
	set category = "1. ProxChat"
	if(SSvoicechat)
		SSvoicechat.join_vc(client)

/mob/verb/join_vc_external()
	set name = "Join with URL"
	set category = "1. ProxChat"
	if(SSvoicechat)
		SSvoicechat.join_vc(client, show_link_only=TRUE)

/mob/verb/help_voicechat()
	set name = "Help"
	set category = "1. ProxChat"
	src << browse({"
	<html>
		<h2>Experimental Proximity Chat</h2>
		<p>
			Try <b>join</b> to load with default browser.
			If the browser fails to open, try <b>"Join with URL"</b> instead.<br>
			Once the external browser is loaded:<br>
				1. Ignore the bad cert and <b>continue onto the site</b>.<br>
				2. When prompted, allow mic perms,.<br>
				3. Verify this is working, by looking for a voice indicator over your mob when speaking.<br>
				4. Drag voicechat to its own window so its only the <b>active tab</b><br>
			If you open a different tab it stops detecting microphone input.
			So make sure voicechat is in its to its own browser window.
		</p>
		<h4>Verbs</h4>
		<p>
			Join - uses default web browser<br>
			Join with URL - gives you link and QR code to use<br>
			Leave - disconnects you from voicechat, note the website doesnt close<br>
			Mute - mutes yourself<br>
			Deafen - deafens yourself<br>
			Note: for security, <b>mute and deafen are one way, use the web browser to unmute</b>
		</p>
		<h4>Trouble shooting tips</h4>
		<p>
			* Ensure browser extensions are off and the page is whitelisted.<br>
			* VPNS occasionally break voicechat.<br>
			* For best results, use firefox browser
		</p>
		<h4>Issues</h4>
		<p>
			Note: You cant reuse the same link, from a browser. <b>Every time you reconnect you need to get a new link through
			the Join verbs</b>
		</p>
		<p> 
			If your are still having issues, its most likely with microphone setup or rtc connections, (roughly 10% connections
			fail).
			To verify the microphone is connected on the website, open the settings tabs and click test mic. If you can hear your
			mic playback then its working fine.
			To check if its an RTC connection issue, open your browser debugger console and check for connection failed errors.
			If you confirmed its a connection failure, try messing with your firewall to open the correct ports (usually
			3000).
			You can also try connecting with your phone using the <b>QR code generated from Join with URL</b>
		</p>
		<h4>Further help/Bug reporting</h4>
		<p>Try yelling at the staff or yelling at <b>a_forg</b> on discord.</p>
		<h4>Source</h4>
		<p>
			A small demo is availible at <a href="https://github.com/forgman6/voice_chat_byond">github.com/forgman6/voice_chat_byond</a><br>
			Contributions are always welcome. Currently this is a solo project.
		</p>
	</html>
	"}, "window=hugagh")

/mob/verb/leave()
	set name = "Leave"
	set category = "1. ProxChat"
	if(!SSvoicechat)
		return
	var/userCode = SSvoicechat.client_userCode_map[client]
	if(!userCode)
		// to_chat(src, span_ooc("Not connected, make sure to close the tab"))
		return
	SSvoicechat.disconnect(userCode, from_byond=TRUE)

/mob/verb/mute_self()
	set name = "Mute"
	set category = "1. ProxChat"
	if(SSvoicechat)
		SSvoicechat.mute_mic(client)


/mob/verb/deafen()
	set name = "Deafen"
	set category = "1. ProxChat"
	if(SSvoicechat)
		SSvoicechat.mute_mic(client, deafen=TRUE)


#ifdef TESTING
/mob/verb/restart()
	set name = "restart voicechat"
	set category = "2. Server"
	if(SSvoicechat)
		SSvoicechat.restart()


/mob/verb/try_shutdown()
	set name = "shutdown voicechat"
	set category = "2. Server"
	if(SSvoicechat)
		SSvoicechat.stop_node()

/mob/verb/make_dummy_client()
	set name = "make dummy client"
	set category = "3. Debug"
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
	set name = "change room"
	set category = "3. Debug"
	SSvoicechat.move_userCode_to_room(userCode, room)

/mob/verb/add_room(room as text)
	set name = "add room"
	set category = "3. Debug"
	SSvoicechat.add_rooms(room)


/mob/verb/ping()
	set name = "toggle ping"
	set category = "3. Debug"
	SSvoicechat.pinging = !SSvoicechat.pinging

/mob/verb/tests()
	set name = "run tests"
	set category = "3. Debug"
	world << "calling lib..."
	world << call_ext(SSvoicechat.lib_path, "byond:Echo")("calling lib worked")
	world << "send bad JSON..."
	var/params = alist(1="bad_key")
	SSvoicechat.send_json(params)
	sleep(1)
	world << "send json with no command..."
	params = alist(message="no command", "extra"="still no command")
	SSvoicechat.send_json(params)
	sleep(1)
	world << "send unknown command..."
	params = alist(cmd="nonexistant command")
	SSvoicechat.send_json(params)

	world << "pinging node"
	SSvoicechat.ping_node()
	sleep(1)


#endif