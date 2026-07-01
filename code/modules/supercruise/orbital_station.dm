/**
 * # Orbital Station
 *
 * A stationary object in supercruise that shuttles can dock with.
 * Represents space stations, outposts, or any dockable structure.
 */
/datum/orbital_object/station
	render_mode = "station"
	radius = 15

	/// The docking port(s) associated with this station
	var/list/obj/docking_port/stationary/docking_ports = list()
	/// The name of the station for UI display
	var/station_name = "Space Station"
	/// Maximum docking range in km
	var/docking_range = 20
	/// Maximum allowed altitude difference for docking
	var/max_altitude_difference = 10
	/// Is the station currently occupied by a docked shuttle?
	var/occupied = FALSE
	supercruise_color = "#1e5ac1"

/datum/orbital_object/station/New(x_pos = 0, y_pos = 0, name_override, datum/overmap_star_system/spawn_system = null)
	. = ..(x_pos, y_pos, spawn_system)
	if(name_override)
		station_name = name_override
		name = name_override

/datum/orbital_object/station/get_map_data()
	var/list/data = ..()
	data["priority"] = 5 // Stations render below shuttles but above background
	data["station_name"] = station_name
	data["docking_range"] = docking_range
	data["occupied"] = occupied
	return data

/**
 * Check if a shuttle is in range to dock
 */
/datum/orbital_object/station/proc/in_docking_range(datum/orbital_object/shuttle/target_shuttle)
	if(!target_shuttle)
		return FALSE
	var/dx = target_shuttle.position_x - position_x
	var/dy = target_shuttle.position_y - position_y
	var/distance = sqrt(dx*dx + dy*dy)
	if(distance > docking_range)
		return FALSE

	var/dz = abs(target_shuttle.position_z - position_z)
	if(dz > max_altitude_difference)
		return FALSE

	return TRUE

/**
 * Attempt to dock a shuttle at this station
 */
/datum/orbital_object/station/proc/dock_shuttle(datum/orbital_object/shuttle/target_shuttle)
	if(!target_shuttle)
		return "Invalid shuttle"

	if(occupied)
		return "Station docking port occupied"

	if(!in_docking_range(target_shuttle))
		return "Out of docking range ([docking_range]km)"

	// Check if we have docking ports available
	if(length(docking_ports))
		var/found_available = FALSE
		for(var/obj/docking_port/port in docking_ports)
			// Just check if port exists for now
			// TODO: Check actual docking compatibility when implementing virtual_z
			found_available = TRUE
			break

		if(!found_available)
			return "No available docking ports"
	// If no ports defined, allow docking anyway (for testing)

	occupied = TRUE
	return null // Success

/**
 * Undock a shuttle from this station
 */
/datum/orbital_object/station/proc/undock_shuttle(datum/orbital_object/shuttle/target_shuttle)
	if(!target_shuttle)
		return "Invalid shuttle"

	occupied = FALSE
	return null // Success

/**
 * Interaction for stations - handles docking
 */
/datum/orbital_object/station/interact(datum/orbital_object/shuttle/interacting_shuttle, mob/user)
	if(!istype(interacting_shuttle))
		return "Only shuttles can dock with stations"

	var/dock_result = interacting_shuttle.dock_at_station(src)

	if(dock_result)
		// Error occurred
		return dock_result

	// Success - show message to user
	if(user)
		to_chat(user, span_notice("Docking successful at [station_name]"))

	return null // Success

/**
 * Link a docking port to this station
 */
/datum/orbital_object/station/proc/add_docking_port(obj/docking_port/stationary/port)
	if(!port || (port in docking_ports))
		return
	docking_ports += port

/**
 * Find or create a station object for a given docking port
 * This is used to automatically link stations when shuttles undock
 */
/datum/orbital_object/station/proc/find_or_create_for_port(obj/docking_port/stationary/port, datum/overmap_star_system/target_system)
	// Check if a station already exists for this port in any system
	for(var/system_id in SSsupercruise.star_systems)
		var/datum/overmap_star_system/system = SSsupercruise.star_systems[system_id]
		for(var/datum/orbital_object/station/existing_station in system.get_stations())
			if(port in existing_station.docking_ports)
				return existing_station

	// No existing station, create a new one
	var/datum/orbital_object/station/new_station = new()
	new_station.station_name = port.name || "Docking Port [port.shuttle_id]"
	new_station.add_docking_port(port)

	// Position the station based on the port's location (convert to supercruise coordinates)
	// This is a simple conversion - you may want to adjust the scaling
	new_station.position_x = port.x * 0.5
	new_station.position_y = port.y * 0.5

	// Add to the target system (or default system if none specified)
	if(!target_system)
		target_system = SSsupercruise.get_default_system()
	target_system.add_object(new_station)

	return new_station
