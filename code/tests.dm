/mob/verb/tests()
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