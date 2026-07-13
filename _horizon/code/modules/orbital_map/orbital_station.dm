/**
 * # Orbital Station
 */
/datum/orbital_object/station
	name = "Space Station"
	render_mode = "station"
	radius = 15
	supercruise_color = "#1e5ac1"
	static_object = TRUE

	var/list/obj/docking_port/stationary/docking_ports = list()
	var/docking_range = 20
	var/max_altitude_difference = 10
	var/occupied = FALSE

/datum/orbital_object/station/New(x_pos = 0, y_pos = 0, z_pos = 0, name_override, datum/overmap_star_system/spawn_system = null)
	. = ..(x_pos, y_pos, z_pos, spawn_system)
	if(name_override)
		name = name_override

/datum/orbital_object/station/get_map_data()
	var/list/data = ..()
	data["priority"] = 5
	data["station_name"] = name
	data["docking_range"] = docking_range
	data["occupied"] = occupied
	return data

/datum/orbital_object/station/proc/in_docking_range(datum/orbital_object/shuttle/target_shuttle)
	if(!target_shuttle)
		return FALSE
	return position.DistanceTo(target_shuttle.position) <= docking_range

/datum/orbital_object/station/proc/dock_shuttle(datum/orbital_object/shuttle/target_shuttle)
	if(!target_shuttle)
		return "Invalid shuttle"
	if(occupied)
		return "Station docking port occupied"
	if(!in_docking_range(target_shuttle))
		return "Out of docking range ([docking_range]km)"

	if(length(docking_ports))
		var/found_available = FALSE
		for(var/obj/docking_port/port in docking_ports)
			found_available = TRUE
			break
		if(!found_available)
			return "No available docking ports"

	occupied = TRUE
	return null

/datum/orbital_object/station/proc/undock_shuttle(datum/orbital_object/shuttle/target_shuttle)
	if(!target_shuttle)
		return "Invalid shuttle"
	occupied = FALSE
	return null

/datum/orbital_object/station/interact(datum/orbital_object/shuttle/interacting_shuttle, mob/user)
	if(!istype(interacting_shuttle))
		return "Only shuttles can dock with stations"
	var/dock_result = interacting_shuttle.dock_at_station(src)
	if(dock_result)
		return dock_result
	if(user)
		to_chat(user, span_notice("Docking successful at [name]"))
	return null

/datum/orbital_object/station/proc/add_docking_port(obj/docking_port/stationary/port)
	if(!port || (port in docking_ports))
		return
	docking_ports += port

/datum/orbital_object/station/proc/find_or_create_for_port(obj/docking_port/stationary/port, datum/overmap_star_system/target_system)
	for(var/system_id in SSsupercruise.star_systems)
		var/datum/overmap_star_system/system = SSsupercruise.star_systems[system_id]
		for(var/datum/orbital_object/station/existing_station in system.get_stations())
			if(port in existing_station.docking_ports)
				return existing_station

	var/datum/orbital_object/station/new_station = new()
	new_station.name = port.name || "Docking Port [port.shuttle_id]"
	new_station.add_docking_port(port)
	new_station.position.Set(port.x * 0.5, port.y * 0.5, port.z * 0.5)

	if(!target_system)
		target_system = SSsupercruise.get_default_system()
	target_system.add_object(new_station)
	return new_station
