/mob/verb/tests()
    world.log << "calling lib..."
    world.log << call_ext("pipes/byondsocket", "byond:Echo")("calling lib worked")
    world.log << "send bad JSON..."
    var/params = alist(1="bad_key")
    SSvoicechat.send_json(params)

    world.log << "send json with no command..."
    params = alist(message="no command", "extra"="still no command")
    SSvoicechat.send_json(params)

    world.log << "send unknown command..."
    params = alist(cmd="nonexistant command")
    SSvoicechat.send_json(params)

    world.log << "pinging node"
    SSvoicechat.ping_node()