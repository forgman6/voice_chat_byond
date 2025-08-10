mob/verb/tests()
    world.log << "calling lib..."
    world.log << call_ext(get_lib(), "byond:Test")()

    world.log << "send bad JSON..."
    var/params = alist(1="bad_key")
    send_json(params)

    world.log << "send json with no command..."
    params = alist("message"="no command", "extra"="still no command")
    send_json(params)

    world.log << "send unknown command..."
    params = alist("cmd"="nonexistant command")
    send_json(params)