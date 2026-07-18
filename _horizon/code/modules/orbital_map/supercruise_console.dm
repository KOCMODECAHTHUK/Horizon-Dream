/**
 * # Supercruise Flight Console
 */
/obj/machinery/computer/shuttle_flight
	name = "supercruise flight console"
	desc = "A console for controlling a vessel in supercruise."
	icon_screen = "shuttle"
	icon_keyboard = "generic_key"

	var/datum/orbital_object/shuttle/controlled_shuttle
	var/last_action_error = ""

/obj/machinery/computer/shuttle_flight/Initialize(mapload)
	. = ..()
	connect_to_shuttle(SSshuttle.get_containing_shuttle(src))

/obj/machinery/computer/shuttle_flight/connect_to_shuttle(mapload, obj/docking_port/mobile/port, obj/docking_port/stationary/dock)
	if(!port)
		return

	for(var/system_id in SSsupercruise.star_systems)
		var/datum/overmap_star_system/system = SSsupercruise.star_systems[system_id]
		for(var/datum/orbital_object/shuttle/existing_shuttle in system.get_shuttles())
			if(existing_shuttle.shuttle_port == port)
				controlled_shuttle = existing_shuttle
				return TRUE

	controlled_shuttle = new /datum/orbital_object/shuttle()
	controlled_shuttle.shuttle_port = port
	controlled_shuttle.name = port.name || "Shuttle"
	controlled_shuttle.position.Set(100, 50, 0)

	var/datum/overmap_star_system/default_system = SSsupercruise.get_default_system()
	if(default_system)
		default_system.add_object(controlled_shuttle)
	return TRUE

/obj/machinery/computer/shuttle_flight/Destroy()
	SStgui.close_uis(src)
	return ..()

/obj/machinery/computer/shuttle_flight/ui_interact(mob/user, datum/tgui/ui)
	. = ..()
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "SupercruiseMap")
		ui.open()
	SSsupercruise.open_orbital_maps |= ui
	ui.set_autoupdate(FALSE)

/obj/machinery/computer/shuttle_flight/ui_close(mob/user, datum/tgui/ui)
	. = ..()
	SSsupercruise.open_orbital_maps -= ui

/obj/machinery/computer/shuttle_flight/ui_state(mob/user)
	return GLOB.default_state

/obj/machinery/computer/shuttle_flight/ui_data(mob/user)
	var/system_id = controlled_shuttle?.star_system?.system_id
	var/list/data = SSsupercruise.get_orbital_map_data(system_id)

	if(controlled_shuttle)
		data["linkedToShuttle"] = TRUE
		data["shuttleName"] = controlled_shuttle.name
		data["shuttleAngle"] = controlled_shuttle.thrust_angle
		data["shuttlePitch"] = controlled_shuttle.thrust_pitch
		data["shuttleThrust"] = controlled_shuttle.thrust_power
		data["shuttleHeading"] = controlled_shuttle.heading
		data["shuttleHeadingPitch"] = controlled_shuttle.heading_pitch
		data["shuttleMaxSpeed"] = controlled_shuttle.max_speed
		data["shuttleVelX"] = controlled_shuttle.velocity.x
		data["shuttleVelY"] = controlled_shuttle.velocity.y
		data["shuttleVelZ"] = controlled_shuttle.velocity.z

		if(controlled_shuttle.docked_at)
			data["shuttlePosX"] = controlled_shuttle.docked_at.position.x
			data["shuttlePosY"] = controlled_shuttle.docked_at.position.y
			data["shuttlePosZ"] = controlled_shuttle.docked_at.position.z
		else
			data["shuttlePosX"] = controlled_shuttle.position.x
			data["shuttlePosY"] = controlled_shuttle.position.y
			data["shuttlePosZ"] = controlled_shuttle.position.z

		var/list/our_obj_data = controlled_shuttle.get_map_data()
		if(controlled_shuttle.docked_at)
			our_obj_data["position_x"] = data["shuttlePosX"]
			our_obj_data["position_y"] = data["shuttlePosY"]
			our_obj_data["position_z"] = data["shuttlePosZ"]
		data["ourObject"] = our_obj_data
		data["autopilotEnabled"] = controlled_shuttle.autopilot_mode > 0
		data["autopilotMode"] = controlled_shuttle.autopilot_mode
		data["targetObjectId"] = controlled_shuttle.target_object_id

		var/obj/docking_port/stationary/current_dock = controlled_shuttle.shuttle_port?.get_docked()
		var/is_in_transit = istype(current_dock, /obj/docking_port/stationary/transit)
		var/is_docked = (controlled_shuttle.docked_at != null) || (current_dock && !is_in_transit)
		data["isDocked"] = is_docked

		var/docked_station_name = null
		if(controlled_shuttle.docked_at)
			if(istype(controlled_shuttle.docked_at, /datum/orbital_object/station))
				var/datum/orbital_object/station/station = controlled_shuttle.docked_at
				docked_station_name = station.name
			else
				docked_station_name = controlled_shuttle.docked_at.name
		else if(is_docked && current_dock)
			docked_station_name = current_dock.name
		data["dockedStation"] = docked_station_name

		var/list/nearby_stations = list()
		for(var/datum/orbital_object/station/station in controlled_shuttle.get_nearby_stations())
			var/dist = controlled_shuttle.position.DistanceTo(station.position)
			nearby_stations += list(list(
				"id" = station.unique_id,
				"name" = station.name,
				"distance" = round(dist, 0.1),
				"occupied" = station.occupied
			))
		data["nearbyStations"] = nearby_stations

		var/list/nearby_objects = list()
		for(var/datum/orbital_object/obj in controlled_shuttle.get_nearby_objects(30))
			var/dist = controlled_shuttle.position.DistanceTo(obj.position)
			nearby_objects += list(list(
				"id" = obj.unique_id,
				"name" = obj.name,
				"distance" = round(dist, 0.1),
				"type" = obj.render_mode,
				"occupied" = istype(obj, /datum/orbital_object/station) ? obj:occupied : FALSE
			))
		data["nearbyObjects"] = nearby_objects

		var/datum/orbital_object/target_obj = SSsupercruise.find_object(controlled_shuttle.target_object_id, controlled_shuttle.star_system)
		if(target_obj)
			data["targetX"] = target_obj.position.x
			data["targetY"] = target_obj.position.y
			data["targetZ"] = target_obj.position.z
		else if(controlled_shuttle.has_target_position || controlled_shuttle.has_pending_target)
			data["targetX"] = controlled_shuttle.target_pos.x
			data["targetY"] = controlled_shuttle.target_pos.y
			data["targetZ"] = controlled_shuttle.target_pos.z

		if(controlled_shuttle.has_pending_target)
			data["pendingTargetX"] = controlled_shuttle.pending_target.x
			data["pendingTargetY"] = controlled_shuttle.pending_target.y
			data["pendingTargetZ"] = controlled_shuttle.pending_target.z
			data["hasPendingTarget"] = TRUE
		else
			data["hasPendingTarget"] = FALSE

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

	data["lastActionError"] = last_action_error
	last_action_error = ""
	return data

/obj/machinery/computer/shuttle_flight/ui_act(action, list/params)
	. = ..()
	if(.)
		return

	if(!controlled_shuttle)
		return

	var/obj/docking_port/stationary/current_dock = controlled_shuttle.shuttle_port?.get_docked()
	var/is_in_transit = istype(current_dock, /obj/docking_port/stationary/transit)
	var/is_docked = (controlled_shuttle.docked_at != null) || (current_dock && !is_in_transit)

	var/list/flight_actions = list(
		"set_thrust", "set_thrust_3d", "set_heading", "setTargetCoords",
		"confirmAutopilot", "adjust_altitude", "kill_thrust",
		"toggle_rotate_left", "toggle_rotate_right",
		"toggle_rotate_pitch_up", "toggle_rotate_pitch_down"
	)

	if(is_docked && (action in flight_actions))
		last_action_error = "Cannot perform flight actions while docked"
		to_chat(usr, span_warning("Cannot control thrust while docked!"))
		return FALSE

	switch(action)
		if("set_thrust")
			var/angle = text2num(params["angle"])
			var/power = text2num(params["power"])
			var/pitch = text2num(params["pitch"])
			if(!isnull(angle) && !isnull(power))
				controlled_shuttle.set_thrust(angle, power, pitch)
			return TRUE

		if("set_thrust_3d")
			var/tx = text2num(params["tx"])
			var/ty = text2num(params["ty"])
			var/tz = text2num(params["tz"])
			var/power = text2num(params["power"])
			if(!isnull(tx) && !isnull(ty) && !isnull(tz) && !isnull(power))
				controlled_shuttle.set_thrust_3d(tx, ty, tz, power)
			return TRUE

		if("set_heading")
			var/new_x = text2num(params["x"])
			var/new_y = text2num(params["y"])
			var/new_z = text2num(params["z"])
			if(!isnull(new_x) && !isnull(new_y))
				var/datum/orbital_vector/delta = new(new_x - controlled_shuttle.position.x, new_y - controlled_shuttle.position.y, (isnull(new_z) ? 0 : new_z) - controlled_shuttle.position.z)
				var/mag = delta.Length()
				if(mag > 0.001)
					controlled_shuttle.set_thrust_3d(delta.x / mag, delta.y / mag, delta.z / mag, controlled_shuttle.thrust_power)
			return TRUE

		if("setTargetCoords")
			var/x = text2num(params["x"])
			var/y = text2num(params["y"])
			var/z = text2num(params["z"])
			var/objectId = params["objectId"]
			var	altKey = params["altKey"]

			if(altKey)
				controlled_shuttle.autopilot_mode = 0
				controlled_shuttle.kill_thrust()
			else if(objectId)
				controlled_shuttle.target_object_id = objectId
				controlled_shuttle.has_pending_target = TRUE
			else if(!isnull(x) && !isnull(y) && !isnull(z))
				controlled_shuttle.target_object_id = null
				controlled_shuttle.target_pos.Set(x, y, z)
				controlled_shuttle.has_pending_target = TRUE
			return TRUE

		if("setAutopilotMode")
			var/mode = text2num(params["mode"])
			var/orbit_radius = text2num(params["orbitRadius"]) || 150

			if(controlled_shuttle.has_pending_target && controlled_shuttle.target_object_id)
				controlled_shuttle.autopilot_mode = mode
				controlled_shuttle.target_orbit_radius = max(orbit_radius, 50)
				controlled_shuttle.has_pending_target = FALSE
				controlled_shuttle.has_target_position = FALSE
				return TRUE
			else if(controlled_shuttle.has_pending_target && !controlled_shuttle.target_object_id)
				controlled_shuttle.autopilot_mode = 1
				controlled_shuttle.has_target_position = TRUE
				controlled_shuttle.has_pending_target = FALSE
				return TRUE
			return FALSE

		if("clearPendingTarget")
			controlled_shuttle.has_pending_target = FALSE
			controlled_shuttle.has_target_position = FALSE
			controlled_shuttle.target_object_id = null
			if(controlled_shuttle.autopilot_mode > 0)
				controlled_shuttle.autopilot_mode = 0
				controlled_shuttle.kill_thrust()
			return TRUE

		if("adjust_altitude")
			var/dz = text2num(params["dz"])
			if(isnull(dz))
				return FALSE
			var/alt_result = controlled_shuttle.adjust_altitude(dz)
			if(alt_result)
				to_chat(usr, span_warning("Altitude change failed: [alt_result]"))
			return TRUE

		if("kill_thrust")
			controlled_shuttle.kill_thrust()
			return TRUE

		if("toggle_rotate_left")
			controlled_shuttle.toggle_rotate_left(text2num(params["enable"]))
			return TRUE
		if("toggle_rotate_right")
			controlled_shuttle.toggle_rotate_right(text2num(params["enable"]))
			return TRUE
		if("toggle_rotate_pitch_up")
			controlled_shuttle.toggle_rotate_pitch_up(text2num(params["enable"]))
			return TRUE
		if("toggle_rotate_pitch_down")
			controlled_shuttle.toggle_rotate_pitch_down(text2num(params["enable"]))
			return TRUE

		if("set_rcs")
			var/sx = text2num(params["sx"]) || 0
			var/sy = text2num(params["sy"]) || 0
			var/sz = text2num(params["sz"]) || 0
			var/power = text2num(params["power"]) || 0

			if(sx == 0 && sy == 0 && sz == 0)
				controlled_shuttle.rcs_power = 0
			else
				controlled_shuttle.rcs_power = clamp(power, 0, 10)

			controlled_shuttle.rcs_strafe.Set(sx, sy, sz)
			return TRUE

		if("dock")
			var/object_id = params["stationId"]
			if(!object_id)
				last_action_error = "No target specified"
				return FALSE

			var/datum/overmap_star_system/current_system = SSsupercruise.get_current_system(controlled_shuttle)
			var/datum/orbital_object/target_object = SSsupercruise.find_object(object_id, current_system)
			if(!target_object)
				last_action_error = "Object not found in current system"
				to_chat(usr, span_warning("Object not found in current system!"))
				return FALSE

			var/interact_result = target_object.interact(controlled_shuttle, usr, src)
			if(interact_result)
				last_action_error = interact_result
				to_chat(usr, span_warning("Docking failed: [interact_result]"))
			return TRUE

		if("undock")
			var/undock_result = controlled_shuttle.undock_from_station()
			if(undock_result)
				last_action_error = undock_result
				to_chat(usr, span_warning("Undocking failed: [undock_result]"))
			else
				last_action_error = ""
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
