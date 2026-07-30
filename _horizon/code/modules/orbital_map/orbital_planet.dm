/**
 * # Orbital Planet
 */
/datum/orbital_object/planet
	render_mode = "planet"
	radius = 8
	mass = 200
	static_object = FALSE
	ignore_gravity = TRUE

	var/description = "A distant celestial body."
	var/planet_size = 100
	var/landable = TRUE
	var/map_generator_type = /datum/map_generator/planet_generator/rocky
	var/datum/virtual_level/planet_level
	var/datum/virtual_level/cave_level
	var/list/obj/docking_port/stationary/reserve_docks
	var/baseturf_type = /turf/open/space/basic
	var/preserve_level = FALSE

	var/datum/orbital_object/star/orbit_center = null
	var/orbit_radius = 100
	var/soi_radius = 150

	var/orbit_inclination = 0
	var/orbit_ascension = 0
	var/orbit_angle = 0
	var/orbit_speed = 1.0

/datum/orbital_object/planet/New(x_pos, y_pos, z_pos, planet_name, set_type = /datum/orbital_object/planet/rocky, datum/overmap_star_system/spawn_system = null)
	. = ..(x_pos, y_pos, z_pos, spawn_system)
	name = planet_name

/datum/orbital_object/planet/proc/setup_orbit(datum/orbital_object/star/center, _radius, inclination = 0, ascension = 0, _orbit_speed = 1.0, direction = 1)
	if(!center)
		return
	orbit_center = center
	orbit_radius = _radius
	orbit_inclination = inclination
	orbit_ascension = ascension
	orbit_speed = _orbit_speed
	orbit_angle = rand(0, 360)

	process(0)

/datum/orbital_object/planet/proc/generate_level()
	if(planet_level)
		return TRUE

	if(!map_generator_type)
		log_world("ERROR: Planet [name] has no map generator type!")
		return FALSE

	var/datum/map_generator/planet_generator/generator = new map_generator_type()
	var/list/result = generator.generate_planet_level(name, planet_size, baseturf_type, null)

	if(!result || !length(result))
		log_world("ERROR: Failed to generate planet level for [name]")
		return FALSE

	planet_level = result[1]
	reserve_docks = result[2]

	if(length(result) >= 3)
		cave_level = result[3]

	if(!planet_level)
		log_world("ERROR: Invalid planet level generated for [name]")
		return FALSE

	log_world("Planet [name] successfully generated with [length(reserve_docks)] docking ports")
	return TRUE

/datum/orbital_object/planet/proc/get_dockable_locations()
	if(!planet_level && !generate_level())
		return list()

	var/list/available_docks = list()
	for(var/obj/docking_port/stationary/dock as anything in reserve_docks)
		var/occupied = FALSE
		for(var/obj/docking_port/mobile/M in SSshuttle.mobile_docking_ports)
			if(M.get_docked() == dock)
				occupied = TRUE
				break
		if(dock.current_docking_ticket)
			occupied = TRUE
		if(!occupied)
			available_docks += dock

	return available_docks

/datum/orbital_object/planet/proc/pre_docked(datum/orbital_object/shuttle/dock_requester, obj/docking_port/stationary/override_dock = null)
	if(!planet_level && !generate_level())
		return new /datum/docking_ticket(null, src, dock_requester, "[src] cannot be generated.")

	var/obj/docking_port/stationary/dock_to_use = override_dock

	if(!dock_to_use)
		for(var/obj/docking_port/stationary/dock as anything in reserve_docks)
			var/occupied = FALSE
			for(var/obj/docking_port/mobile/M in SSshuttle.mobile_docking_ports)
				if(M.get_docked() == dock)
					occupied = TRUE
					break
			if(!occupied && !dock.current_docking_ticket)
				dock_to_use = dock
				break

	if(!dock_to_use)
		return new /datum/docking_ticket(null, src, dock_requester, "[src] does not have any free landing zones. Aborting docking.")

	return new /datum/docking_ticket(dock_to_use, src, dock_requester)

/datum/orbital_object/planet/get_map_data()
	var/list/data = ..()
	if(orbit_center)
		data["orbit_center_id"] = orbit_center.unique_id
		data["orbit_radius"] = orbit_radius
		data["orbit_inclination"] = orbit_inclination
		data["orbit_ascension"] = orbit_ascension
	data["landable"] = landable
	return data

/datum/orbital_object/planet/process(seconds_per_tick)
	if(!orbit_center)
		return

	orbit_angle = MODULUS(orbit_angle + (orbit_speed * seconds_per_tick), 360)
	var/base_x = orbit_radius * cos(orbit_angle)
	var/base_y = orbit_radius * sin(orbit_angle)

	var/inc_y = base_y * cos(orbit_inclination)
	var/inc_z = base_y * sin(orbit_inclination)

	var/final_x = base_x * cos(orbit_ascension) - inc_y * sin(orbit_ascension)
	var/final_y = base_x * sin(orbit_ascension) + inc_y * cos(orbit_ascension)
	var/final_z = inc_z

	position.Set(orbit_center.position.x + final_x, orbit_center.position.y + final_y, orbit_center.position.z + final_z)

	var/d_omega = orbit_speed * (PI / 180)
	var/vx = -orbit_radius * sin(orbit_angle) * d_omega * cos(orbit_ascension) - (orbit_radius * cos(orbit_angle) * cos(orbit_inclination) * sin(orbit_ascension)) * d_omega
	var/vy = orbit_radius * cos(orbit_angle) * d_omega * sin(orbit_ascension) - (orbit_radius * sin(orbit_angle) * cos(orbit_inclination) * cos(orbit_ascension)) * d_omega
	var/vz = (orbit_radius * sin(orbit_angle) * sin(orbit_inclination)) * d_omega

	velocity.Set(vx, vy, vz)

/datum/orbital_object/planet/interact(datum/orbital_object/shuttle/interacting_shuttle, mob/user, obj/machinery/computer/shuttle_flight/flight_console = null)
	if(!istype(interacting_shuttle))
		return "Only shuttles can interact with planets"

	if(!landable)
		to_chat(user, span_warning("[name] is not suitable for landing. [description]"))
		return "Not landable"

	to_chat(user, span_notice("You initiate landing procedures on [name]."))

	if(!planet_level)
		to_chat(user, span_notice("Generating planet surface..."))
		if(!generate_level())
			to_chat(user, span_warning("ERROR: Failed to generate planet surface!"))
			return "Failed to generate planet surface"
		to_chat(user, span_boldnotice("Planet surface generated!"))

	if(flight_console)
		var/obj/machinery/computer/camera_advanced/shuttle_docker/orbital/docker = new()
		if(!docker.launch(user, flight_console, src))
			qdel(docker)
			return "Failed to launch navigation camera"
		return null

	return list_based_dock(interacting_shuttle, user)

/datum/orbital_object/planet/proc/list_based_dock(datum/orbital_object/shuttle/interacting_shuttle, mob/user)
	var/list/available = get_dockable_locations()
	if(!length(available))
		to_chat(user, span_warning("All landing zones are currently occupied or reserved!"))
		return "No available landing zones"

	to_chat(user, span_info("[length(available)]/[length(reserve_docks)] landing zones available."))
	var/obj/docking_port/stationary/selected_dock = tgui_input_list(user, "Select landing zone:", "Planet Landing", available)
	if(!selected_dock)
		to_chat(user, span_notice("Landing procedure cancelled."))
		return "Cancelled"

	if(!interacting_shuttle.shuttle_port)
		to_chat(user, span_warning("ERROR: Shuttle has no docking port!"))
		return "Shuttle has no docking port"

	var/datum/docking_ticket/ticket = pre_docked(interacting_shuttle, selected_dock)
	if(!ticket || ticket.docking_error)
		var/error_msg = ticket?.docking_error || "Unknown error"
		to_chat(user, span_warning("ERROR: Landing clearance denied! [error_msg]"))
		if(ticket)
			qdel(ticket)
		return "Ticket error: [error_msg]"

	var/docking_result = interacting_shuttle.shuttle_port.initiate_docking(ticket.target_port)
	if(docking_result != DOCKING_SUCCESS)
		to_chat(user, span_warning("ERROR: Landing failed! ([docking_result])"))
		qdel(ticket)
		return "Docking failed: [docking_result]"

	to_chat(user, span_boldnotice("Landing successful! Welcome to [name]."))
	interacting_shuttle.docked_at = src
	qdel(ticket)
	interacting_shuttle.docked_offset = interacting_shuttle.position.Subtract(position)
	return null

/datum/orbital_object/planet/proc/undock_shuttle(datum/orbital_object/shuttle/target_shuttle)
	if(!target_shuttle)
		return "Invalid shuttle"
	target_shuttle.docked_at = null
	post_undocked(target_shuttle)
	return null

/datum/orbital_object/planet/proc/post_undocked(datum/orbital_object/shuttle/dock_requester)
	if(preserve_level)
		return
	addtimer(CALLBACK(src, PROC_REF(check_and_unload)), 10 SECONDS)

/datum/orbital_object/planet/proc/check_and_unload()
	if(!can_unload_planet())
		return
	unload_planet()

/datum/orbital_object/planet/proc/can_unload_planet()
	if(!planet_level)
		return FALSE

	var/list/mind_mobs = planet_level.get_mind_mobs()
	if(length(mind_mobs))
		return FALSE

	for(var/obj/docking_port/stationary/dock as anything in reserve_docks)
		if(dock.get_docked())
			return FALSE

	return TRUE

/datum/orbital_object/planet/proc/unload_planet()
	if(!planet_level)
		return

	for(var/obj/docking_port/stationary/dock as anything in reserve_docks)
		qdel(dock, TRUE)
	reserve_docks = null

	// Очищаем поверхность
	planet_level.clear_reservation()
	SSmapping.destroy_planet_zlevel(planet_level)
	qdel(planet_level)
	planet_level = null

	// Очищаем пещеры, если они есть
	if(cave_level)
		cave_level.clear_reservation()
		SSmapping.destroy_planet_zlevel(cave_level)
		qdel(cave_level)
		cave_level = null

	src.star_system.generate_planets(1)
	qdel(src)

/datum/orbital_object/planet/proc/emergency_dock(datum/orbital_object/shuttle/dock_requester)
	if(!istype(dock_requester) || !landable)
		return FALSE

	if(!planet_level)
		generate_level()

	var/list/available = get_dockable_locations()
	if(!length(available))
		return FALSE

	var/obj/docking_port/stationary/dock_to_use = pick(available)
	var/datum/docking_ticket/ticket = pre_docked(dock_requester, dock_to_use)

	if(!ticket || ticket.docking_error)
		if(ticket) qdel(ticket)
		return FALSE

	var/docking_result = dock_requester.shuttle_port.initiate_docking(ticket.target_port)
	if(docking_result != DOCKING_SUCCESS)
		qdel(ticket)
		return FALSE

	dock_requester.docked_offset = dock_requester.position.Subtract(position)
	dock_requester.docked_at = src

	qdel(ticket)
	return TRUE
