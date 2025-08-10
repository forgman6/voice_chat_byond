mob/verb/ping_node()
    var/list/data = alist("cmd" = "ping", "message" = "Hello from BYOND!", "time"=world.timeofday )
    send_json(data)

//creates hopefully unique code to identify users by. 
//I didnt want to use ckeys or cids or ips because they all suck, and selfhosting issues.
proc/generate_userCode(client/C)
    if(!C || !(/client))
        CRASH("no client or wrong type, go fuck yourself retard")
    . = copytext(md5("[C.computer_id][C.address][rand()]"),-4) 
    return .

mob/verb/join_vc()
    var/sessionId = md5("[world.time][rand()][world.realtime][rand(0,9999)][client.address][client.computer_id]") // Generate unique session ID secure shit player can modify
    var/userCode = generate_userCode(client)
    while(userCode in SSVOICE.userCode_client_map) // ensure unique, should almost never run
        userCode = generate_userCode(client)
    src << link("https://localhost:3000?sessionId=[sessionId]")

    var/list/paramstuff = alist()
    paramstuff["cmd"] = "register"
    paramstuff["userCode"]=userCode
    paramstuff["sessionId"]=sessionId
    send_json(paramstuff)
    SSVOICE.link_userCode_client(userCode, client)
    

mob/verb/test_client()
    var/list/paramstuff = alist()
    src << link("https://localhost:3000?sessionId=test")
    paramstuff["userCode"] = "test"
    paramstuff["sessionId"] = "test"
    paramstuff["cmd"] = "register"
    send_json(paramstuff)

mob/verb/test_room()
    var/params = alist("cmd" = "changeRoom", "userCode" = "test", "room_name" = "a")
    send_json(params)


