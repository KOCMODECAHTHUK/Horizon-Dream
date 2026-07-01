/**
 * # Supercruise Flight Console
 *
 * Allows controlling a shuttle in supercruise/orbital space.
 */
/obj/machinery/computer/supercruise
	name = "supercruise flight console"
	desc = "A console for controlling a vessel in supercruise."
	icon_screen = "shuttle"
	icon_keyboard = "generic_key"

	/// The shuttle we're controlling
	var/datum/orbital_object/shuttle/controlled_shuttle

/obj/machinery/computer/supercruise/Initialize(mapload)
	. = ..()
	connect_to_shuttle(SSshuttle.get_containing_shuttle(src))

/obj/machinery/computer/supercruise/connect_to_shuttle(mapload, obj/docking_port/mobile/port, obj/docking_port/stationary/dock)
	if(!port)
		return

	// Check if an orbital shuttle already exists for this port in any system
	for(var/system_id in SSsupercruise.star_systems)
		var/datum/overmap_star_system/system = SSsupercruise.star_systems[system_id]
		for(var/datum/orbital_object/shuttle/existing_shuttle in system.get_shuttles())
			if(existing_shuttle.shuttle_port == port)
				controlled_shuttle = existing_shuttle
				return TRUE

	// If no existing shuttle, create a new one and add it to the default system
	controlled_shuttle = new /datum/orbital_object/shuttle()
	controlled_shuttle.shuttle_port = port
	controlled_shuttle.name = port.name || "Shuttle"
	// Start at a default position - shuttle is docked at station initially
	controlled_shuttle.position_x = 100
	controlled_shuttle.position_y = 50

	// Add shuttle to the default system
	var/datum/overmap_star_system/default_system = SSsupercruise.get_default_system()
	if(default_system)
		default_system.add_object(controlled_shuttle)

	return TRUE

/obj/machinery/computer/supercruise/Destroy()
	// Clean up any open UIs
	SStgui.close_uis(src)
	return ..()

/obj/machinery/computer/supercruise/ui_interact(mob/user, datum/tgui/ui)
	. = ..()
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "SupercruiseMap")
		ui.open()
	SSsupercruise.open_orbital_maps |= ui
	ui.set_autoupdate(FALSE)

/obj/machinery/computer/supercruise/ui_close(mob/user, datum/tgui/ui)
	. = ..()
	SSsupercruise.open_orbital_maps -= ui

/obj/machinery/computer/supercruise/ui_state(mob/user)
	return GLOB.default_state

/obj/machinery/computer/supercruise/ui_data(mob/user)
	// Get orbital map data for the shuttle's current system
	var/system_id = controlled_shuttle?.star_system?.system_id
	var/list/data = SSsupercruise.get_orbital_map_data(system_id)

	// Add shuttle-specific data
	if(controlled_shuttle)
		data["linkedToShuttle"] = TRUE
		data["shuttleName"] = controlled_shuttle.name
		data["shuttleAngle"] = controlled_shuttle.thrust_angle
		data["shuttleThrust"] = controlled_shuttle.thrust_power
		data["shuttleVelX"] = controlled_shuttle.velocity_x
		data["shuttleVelY"] = controlled_shuttle.velocity_y
		data["shuttleVelZ"] = controlled_shuttle.velocity_z
		data["shuttleAlt"] = controlled_shuttle.position_z
		data["ourObject"] = controlled_shuttle.get_map_data()
		data["autopilotEnabled"] = controlled_shuttle.autopilot_enabled

		// Check if docked - either docked_at is set OR shuttle is not in transit dock
		var/obj/docking_port/stationary/current_dock = controlled_shuttle.shuttle_port?.get_docked()
		var/is_in_transit = istype(current_dock, /obj/docking_port/stationary/transit)
		var/is_docked = (controlled_shuttle.docked_at != null) || (current_dock && !is_in_transit)
		data["isDocked"] = is_docked

		var/docked_station_name = null
		if(controlled_shuttle.docked_at)
			// Check if it's a station (has station_name) or other object (use name)
			if(istype(controlled_shuttle.docked_at, /datum/orbital_object/station))
				var/datum/orbital_object/station/station = controlled_shuttle.docked_at
				docked_station_name = station.station_name
			else
				docked_station_name = controlled_shuttle.docked_at.name
		else if(is_docked && current_dock)
			docked_station_name = current_dock.name
		data["dockedStation"] = docked_station_name

		// Get nearby stations (only in current system)
		var/list/nearby_stations = list()
		for(var/datum/orbital_object/station/station in controlled_shuttle.get_nearby_stations())
			var/dx = station.position_x - controlled_shuttle.position_x
			var/dy = station.position_y - controlled_shuttle.position_y
			var/dz = station.position_z - controlled_shuttle.position_z
			nearby_stations += list(list(
				"id" = station.unique_id,
				"name" = station.station_name,
				"distance" = round(sqrt(dx*dx + dy*dy + dz*dz), 0.1),
				"occupied" = station.occupied
			))
		data["nearbyStations"] = nearby_stations

		// Get ALL nearby interactable objects (generic, only in current system)
		var/list/nearby_objects = list()
		for(var/datum/orbital_object/obj in controlled_shuttle.get_nearby_objects(30))
			var/dx = obj.position_x - controlled_shuttle.position_x
			var/dy = obj.position_y - controlled_shuttle.position_y
			var/dz = obj.position_z - controlled_shuttle.position_z
			nearby_objects += list(list(
				"id" = obj.unique_id,
				"name" = obj.name,
				"distance" = round(sqrt(dx*dx + dy*dy + dz*dz), 0.1),
				"type" = obj.render_mode,
				"occupied" = istype(obj, /datum/orbital_object/station) ? obj:occupied : FALSE
			))
		data["nearbyObjects"] = nearby_objects

		if(controlled_shuttle.target_position)
			data["targetX"] = controlled_shuttle.target_position["x"]
			data["targetY"] = controlled_shuttle.target_position["y"]

		// Jump drive data
		data["hasJumpDrive"] = controlled_shuttle.has_jump_drive
		data["isJumping"] = controlled_shuttle.is_jumping
		data["jumpCooldown"] = controlled_shuttle.jump_cooldown
		var/time_since_jump = (world.time - controlled_shuttle.last_jump_time)
		data["jumpReady"] = (time_since_jump >= controlled_shuttle.jump_cooldown)
		data["jumpCooldownRemaining"] = max(0, controlled_shuttle.jump_cooldown - time_since_jump) / 10
		data["jumpDestinations"] = controlled_shuttle.get_jump_destinations()
		data["currentSystemName"] = controlled_shuttle.star_system?.system_name || "Unknown"
	else
		data["linkedToShuttle"] = FALSE

	return data

/obj/machinery/computer/supercruise/ui_act(action, list/params)
	. = ..()
	if(.)
		return

	if(!controlled_shuttle)
		return

	// Check if docked - prevent flight controls when docked
	var/obj/docking_port/stationary/current_dock = controlled_shuttle.shuttle_port?.get_docked()
	var/is_in_transit = istype(current_dock, /obj/docking_port/stationary/transit)
	var/is_docked = (controlled_shuttle.docked_at != null) || (current_dock && !is_in_transit)

	switch(action)
		if("set_thrust")
			if(is_docked)
				to_chat(usr, span_warning("Cannot control thrust while docked!"))
				return FALSE
			var/angle = text2num(params["angle"])
			var/power = text2num(params["power"])
			if(!isnull(angle) && !isnull(power))
				controlled_shuttle.set_thrust(angle, power)
			return TRUE

		if("set_heading")
			if(is_docked)
				to_chat(usr, span_warning("Cannot set heading while docked!"))
				return FALSE
			var/new_x = text2num(params["x"])
			var/new_y = text2num(params["y"])
			if(!isnull(new_x) && !isnull(new_y))
				// Calculate angle to target point
				var/dx = new_x - controlled_shuttle.position_x
				var/dy = new_y - controlled_shuttle.position_y
				var/angle = TODEGREES(arctan(dy, dx))
				// Normalize to 0-360
				if(angle < 0)
					angle += 360
				controlled_shuttle.thrust_angle = angle
			return TRUE

		if("setTargetCoords")
			if(is_docked)
				to_chat(usr, span_warning("Cannot engage autopilot while docked!"))
				return FALSE
			var/x = text2num(params["x"])
			var/y = text2num(params["y"])
			var/altKey = params["altKey"]

			if(altKey) // Alt+Click clears target and stops thrust
				controlled_shuttle.autopilot_enabled = FALSE
				controlled_shuttle.target_position = null
				controlled_shuttle.thrust_power = 0
			else if(!isnull(x) && !isnull(y))
				// Set target position and enable autopilot
				controlled_shuttle.target_position = list("x" = x, "y" = y)
				controlled_shuttle.autopilot_enabled = TRUE
			return TRUE

		if("adjust_altitude")
			if(is_docked)
				to_chat(usr, span_warning("Cannot adjust altitude while docked!"))
				return FALSE
			var/dz = text2num(params["dz"])
			if(isnull(dz))
				return FALSE
			var/alt_result = controlled_shuttle.adjust_altitude(dz)
			if(alt_result)
				to_chat(usr, span_warning("Altitude change failed: [alt_result]"))
			return TRUE

		if("dock")
			var/object_id = params["stationId"]
			if(!object_id)
				return FALSE

			// Find object in the shuttle's current system
			var/datum/overmap_star_system/current_system = SSsupercruise.get_current_system(controlled_shuttle)
			var/datum/orbital_object/target_object = SSsupercruise.find_object(object_id, current_system)
			if(!target_object)
				to_chat(usr, span_warning("Object not found in current system!"))
				return FALSE

			var/interact_result = target_object.interact(controlled_shuttle, usr)
			if(interact_result)
				to_chat(usr, span_warning("Interaction failed: [interact_result]"))
			return TRUE

		if("undock")
			var/undock_result = controlled_shuttle.undock_from_station()
			if(undock_result)
				to_chat(usr, span_warning("Undocking failed: [undock_result]"))
			else
				to_chat(usr, span_notice("Undocked successfully"))
			return TRUE

		if("jump")
			var/target_system_id = params["systemId"]
			if(!target_system_id)
				to_chat(usr, span_warning("No target system specified!"))
				return FALSE

			var/jump_result = controlled_shuttle.jump_to_system(target_system_id, usr)
			if(jump_result)
				to_chat(usr, span_warning("Jump failed: [jump_result]"))
			return TRUE
