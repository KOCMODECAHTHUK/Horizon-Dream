/obj/machinery/transponder
	name = "ship transponder"
	desc = "Broadcasts vessel identification."
	icon = 'icons/obj/machines/telecomms.dmi'
	icon_state = "transponder"
	var/datum/orbital_object/shuttle/linked_shuttle
	var/transponder_id = "NTV-UNKNOWN"
	var/faction = "Nanotrasen"
	var/active = TRUE

/obj/machinery/transponder/LateInitialize()
	var/obj/docking_port/mobile/port = SSshuttle.get_containing_shuttle(src)
	if(port)
		for(var/datum/orbital_object/shuttle/S in SSsupercruise.get_all_shuttles())
			if(S.shuttle_port == port)
				linked_shuttle = S
				break
	update_signature()

/obj/machinery/transponder/proc/update_signature()
	if(linked_shuttle && linked_shuttle.signature)
		linked_shuttle.signature.transponder_code = active ? "[faction] | [transponder_id]" : null

/obj/machinery/transponder/ui_act(action, params)
	. = ..()
	if(.)
		return
	switch(action)
		if("toggle")
			active = !active
			update_signature()
			return TRUE
		if("set_id")
			transponder_id = params["id"] || "UNKNOWN"
			update_signature()
			return TRUE
