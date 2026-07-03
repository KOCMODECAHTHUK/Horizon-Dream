// COMPATIBILITY LAYER for PentestSS13
// Shuttle consoles now extend supercruise console for compatibility
// All old functionality is stubbed out - maps use supercruise console directly

#define SHUTTLE_CONSOLE_ACCESSDENIED "accessdenied"
#define SHUTTLE_CONSOLE_ENDGAME "endgame"
#define SHUTTLE_CONSOLE_RECHARGING "recharging"
#define SHUTTLE_CONSOLE_INTRANSIT "intransit"
#define SHUTTLE_CONSOLE_DESTINVALID "destinvalid"
#define SHUTTLE_CONSOLE_SUCCESS "success"
#define SHUTTLE_CONSOLE_ERROR "error"

/obj/machinery/computer/shuttle
	parent_type = /obj/machinery/computer/shuttle_flight
	name = "shuttle console"
	desc = "A shuttle control computer."
	icon_state = MAP_SWITCH("computer", "/obj/machinery/computer/shuttle")
	icon_screen = "shuttle"
	icon_keyboard = "tech_key"
	light_color = LIGHT_COLOR_CYAN
	req_access = list()
	interaction_flags_machine = INTERACT_MACHINE_ALLOW_SILICON
	/// ID of the attached shuttle
	var/shuttleId
	/// Possible destinations of the attached shuttle
	var/possible_destinations = ""
	/// Variable dictating if the attached shuttle requires authorization from the admin staff to move
	var/admin_controlled = FALSE
	/// Variable dictating if the attached shuttle is forbidden to change destinations mid-flight
	var/no_destination_swap = FALSE
	/// ID of the currently selected destination of the attached shuttle
	var/destination
	/// If the console controls are locked
	var/locked = FALSE
	/// List of head revs who have already clicked through the warning about not using the console
	var/static/list/dumb_rev_heads = list()
	///the remote control device linked
	var/datum/weakref/remote_ref
	///may this console be remote controlled?
	var/may_be_remote_controlled = FALSE
	/// Authorization request cooldown to prevent request spam to admin staff
	COOLDOWN_DECLARE(request_cooldown)

// Stub methods that do nothing - actual functionality is in supercruise console
/obj/machinery/computer/shuttle/Initialize(mapload)
	. = ..()

/obj/machinery/computer/shuttle/proc/launch_check(mob/user)
	return TRUE

/obj/machinery/computer/shuttle/proc/get_valid_destinations()
	return list()

/obj/machinery/computer/shuttle/proc/send_shuttle(dest_id, mob/user)
	return SHUTTLE_CONSOLE_SUCCESS

/obj/machinery/computer/shuttle/connect_to_shuttle(mapload, obj/docking_port/mobile/port, obj/docking_port/stationary/dock)
	return TRUE

#undef SHUTTLE_CONSOLE_ACCESSDENIED
#undef SHUTTLE_CONSOLE_ENDGAME
#undef SHUTTLE_CONSOLE_RECHARGING
#undef SHUTTLE_CONSOLE_INTRANSIT
#undef SHUTTLE_CONSOLE_DESTINVALID
#undef SHUTTLE_CONSOLE_SUCCESS
#undef SHUTTLE_CONSOLE_ERROR
