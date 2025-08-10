/area/Entered(Obj, OldLoc)
    . = ..()
    if(!istype(Obj, /mob))
        return
    var/mob/M = Obj 
    M << "entering [src.type]"

/area/room_a/Entered(Obj, OldLoc)
    . = ..()
    if(!istype(Obj, /mob))
        return
    var/mob/M = Obj
    if(!M.client)
        return
    SSVOICE.move_client_to_room("a", M.client)

/area/room_b/Entered(Obj, OldLoc)
    . = ..()
    if(!istype(Obj, /mob))
        return
    var/mob/M = Obj
    if(!M.client)
        return
    SSVOICE.move_client_to_room("b", M.client)
