/mob/Login()
    . = ..()
    src << "<h1>type join vc to join voice chat</h1> <br>type mute to mute yourself <br>type deafen to deafen yourself <br>step on the colored tiles to switch rooms"
    world << "[client] joined"
    // join_vc()

    
/mob/Logout()
    world << "[client] left"
    Del()
    . = ..()
    