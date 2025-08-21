mob/verb/ping_node()
    var/list/data = alist(cmd = "ping", message = "Hello from BYOND!", time=world.timeofday)
    send_json(data)

//creates hopefully unique code to identify users by. 
//I didnt want to use ckeys or cids or ips because they all suck, and selfhosting issues.
proc/generate_userCode(client/C)
    if(!C || !(/client))
        CRASH("no client or wrong type, go fuck yourself retard")
    . = copytext(md5("[C.computer_id][C.address][rand()]"),-4) 
    return .

mob/verb/join_vc()
    var/check_userCode = SSVOICE.client_userCode_map[ref(client)]
    if(check_userCode) //client already connected
        SSVOICE.disconnect(check_userCode, from_byond= TRUE)
    var/sessionId = md5("[world.time][rand()][world.realtime][rand(0,9999)][client.address][client.computer_id]") // Generate unique session ID secure shit player can modify
    var/userCode = generate_userCode(client)
    while(userCode in SSVOICE.userCode_client_map) // ensure unique, should almost never run
        userCode = generate_userCode(client)
    #ifndef DEBUG
    src << link("https://[world.internet_address]:[NODEPORT]?sessionId=[sessionId]")
    #else
    src << link("https://localhost:[NODEPORT]?sessionId=[sessionId]")
    #endif
    var/list/paramstuff = alist(cmd="register")
    paramstuff["userCode"]=userCode
    paramstuff["sessionId"]=sessionId
    send_json(paramstuff)
    SSVOICE.link_userCode_client(userCode, client)

#ifdef DEBUG
mob/verb/make_dummy_client()
    var/global/number = 1
    var/list/paramstuff = alist(cmd="register")
    var/sessionId = "dummy_[number]"
    number ++
    #ifndef DEBUG
    src << link("https://[world.internet_address]:[NODEPORT]?sessionId=[sessionId]")
    #else
    src << link("https://localhost:[NODEPORT]?sessionId=[sessionId]")
    #endif
    paramstuff["userCode"] = "[sessionId]"
    paramstuff["sessionId"] = "[sessionId]"
    send_json(paramstuff)
    var/mob/dummy_mob = new(loc)
    dummy_mob.tag = sessionId
    dummy_mob.name = sessionId
    var/fake_client/C = new
    C.mob = dummy_mob
    dummy_mob.dummy_client = C
    SSVOICE.link_userCode_client(sessionId, C)



mob/verb/send_locs()
    SSVOICE.send_client_locs()

mob/verb/change_room(userCode in SSVOICE.vc_clients, room in SSVOICE.current_rooms)
    SSVOICE.move_userCode_to_room(userCode, room)

mob/verb/add_room(room as text)
    SSVOICE.add_rooms(room)
#endif

mob/verb/mute_self()
    SSVOICE.mute_mic(ref(client))

mob/verb/deafen()
    SSVOICE.mute_mic(ref(client), deafen=TRUE)