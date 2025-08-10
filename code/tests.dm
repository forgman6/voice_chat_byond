mob/verb/test_errors()
    world.log << "send bad request..."
    var/bad_req = "{},1433"
    call_ext(get_lib(), "byond:SendJSON")(bad_req, length(bad_req))

    world.log << "send json with no command..."
    var/params = alist("message"="no command", "extra"="still no command")
    send_json(params)

    world.log << "send unknown command..."
    params = alist("cmd"="nonexistant command")
    send_json(params)


mob/verb/test_dll()
    world.log << "calling lib..."
    world.log << call_ext(get_lib(), "byond:Test")()