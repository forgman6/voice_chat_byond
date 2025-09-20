/mob/Login()
	. = ..()
	src << "<h1>type join vc to join voice chat</h1> <br>type mute to mute yourself <br>type deafen to deafen yourself <br>step on the colored tiles to switch rooms"
	world << "[client] joined"
	// join_vc()


client/Del()
	world << "[src] left"
	var/userCode = SSvoicechat.client_userCode_map[ref(src)]
	if(userCode)
		SSvoicechat.disconnect(userCode, from_byond= TRUE)
	del(src?.mob)
	. = ..()    

world/Topic(T, Addr, Master, Keys)
	. = ..()
	if(SSvoicechat && Addr == "127.0.0.1")
		SSvoicechat.handle_topic(T, Addr)
		
var/global/datum/controller/subsystem/voicechat/SSvoicechat = new()


