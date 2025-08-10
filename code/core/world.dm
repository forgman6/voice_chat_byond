/world
    fps = 20
    icon_size = 32	// 32x32 icon size by default
    view = "15x15"
/client/
    view = 5
    
/mob
    step_size = 32
    icon = 'Icons.dmi'
    icon_state = "m"

/turf
    icon = 'Icons.dmi'

/turf/a 
    icon_state = "floor_a"

/turf/b 
    icon_state = "floor_b"
// var/help = {"<h3>display ui ref</h3>
// if var/ui_referance is set open it in a browse window

// <h3>external ui</h3>
// opens content.html file and loads css. nothing is stored in cache so you can make changes to 
// general.css, ui.css, and content.html without recompiling.

// <h3>get window stuff</h3>
// tells you all the attributes of the ui window, things like size and pos

// <h3>internal ui</h3>
// opens ui_content.dm, Once you are happy with the layout,
// you move content.html to ui_content.dm and you can start adding functionality.
// requires recompiling upon modifying anything.

// <h3>modify vars</h3>
// very crude ai made in game variable modification. also opens internal ui at the end<hr>
// "}

/mob/Login()
    x = 8; y = 8
    // src << help