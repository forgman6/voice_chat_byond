/turf/room_changer
    var/room
    var/color_change


/turf/room_changer/Entered(atom/movable/Obj)    
    . = ..()
    var/mob/M = Obj
    if(!SSvoicechat || !room || !istype(M))
        return
    if(!SSvoicechat.current_rooms.Find("red")) //add rooms on first run
        SSvoicechat.add_rooms(list("red", "blue", "green"))
    var/userCode = SSvoicechat.client_userCode_map[ref(M.client)]
    if(!userCode)
        return
    M << "changing rooms..."
    SSvoicechat.move_userCode_to_room(userCode, room)
    apply_effects(M)    


/turf/room_changer/proc/apply_effects(mob/M)
    M.color = color_change
    return

/turf/room_changer/blue
    icon_state = "b"
    color_change = "#00F"
    room = "blue"

/turf/room_changer/green
    icon_state = "g"
    color_change = "#0F0"
    room = "green"

/turf/room_changer/red
    icon_state = "r"
    color_change = "#F00"
    room = "red"

/turf/room_changer/white
    icon_state = "w"
    room = "living"

