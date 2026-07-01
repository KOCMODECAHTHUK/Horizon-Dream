/**
 * # Overmap Star System
 *
 * Represents a star system containing planets, stations, and other orbital objects.
 * Each system is isolated - shuttles can only interact with objects in their current system.
 */
/datum/overmap_star_system
	/// Unique identifier for this system
	var/system_id = ""
	/// Display name of the system
	var/system_name = "Unknown System"
	/// Description of the system
	var/system_description = "A distant star system."
	/// All orbital objects in this system
	var/list/datum/orbital_object/orbital_objects = list()
	/// Central star position (for future star rendering)
	var/star_x = 0
	var/star_y = 0
	/// Star color (for rendering)
	var/star_color = "#ffff88"
	/// System bounds (for rendering limits)
	var/min_x = -300
	var/max_x = 600
	var/min_y = -300
	var/max_y = 600
	/// Whether this system can be jumped to
	var/can_jump = TRUE

/datum/overmap_star_system/New(id, name, description)
	. = ..()
	system_id = id || "system_[time2text(world.realtime, "YYYY-MM-DD_hh:mm:ss")]_[rand(1000, 9999)]"
	system_name = name || "System [system_id]"
	system_description = description || "A mysterious star system."

	// Add this system to the global registry
	SSsupercruise.star_systems[system_id] = src

/datum/overmap_star_system/Destroy()
	// Remove all orbital objects
	for(var/datum/orbital_object/obj in orbital_objects)
		obj.star_system = null
		qdel(obj)
	orbital_objects.Cut()

	// Remove from global registry
	SSsupercruise.star_systems -= system_id
	return ..()

/**
 * Add an orbital object to this system
 */
/datum/overmap_star_system/proc/add_object(datum/orbital_object/obj)
	if(!obj)
		return FALSE

	// Remove from old system if it has one
	if(obj.star_system && obj.star_system != src)
		obj.star_system.remove_object(obj)

	obj.star_system = src
	orbital_objects |= obj
	return TRUE

/**
 * Remove an orbital object from this system
 */
/datum/overmap_star_system/proc/remove_object(datum/orbital_object/obj)
	if(!obj)
		return FALSE

	orbital_objects -= obj
	if(obj.star_system == src)
		obj.star_system = null
	return TRUE

/**
 * Generate planets for this system
 */
/datum/overmap_star_system/proc/generate_planets(num_planets = 8)
	var/list/planet_types = GLOB.planet_types
	var/list/used_positions = list()

	for(var/i in 1 to num_planets)
		// Random planet type
		var/planet_type = pick(planet_types)

		// Generate position - spread planets around the system
		// Try to avoid overlapping
		var/x_pos
		var/y_pos
		var/attempts = 0
		var/valid_position = FALSE

		while(!valid_position && attempts < 20)
			attempts++
			// Random position within system bounds
			x_pos = rand(min_x, max_x)
			y_pos = rand(min_y, max_y)

			// Check if too close to any existing object in this system
			valid_position = TRUE
			for(var/datum/orbital_object/obj in orbital_objects)
				var/dist = sqrt((obj.position_x - x_pos)**2 + (obj.position_y - y_pos)**2)
				if(dist < 50)  // Minimum 50km separation
					valid_position = FALSE
					break

			// Also check against other positions we've generated this loop
			for(var/list/pos in used_positions)
				var/dist = sqrt((pos["x"] - x_pos)**2 + (pos["y"] - y_pos)**2)
				if(dist < 50)
					valid_position = FALSE
					break

		if(valid_position)
			used_positions += list(list("x" = x_pos, "y" = y_pos))
			var/planet_name = gen_planet_name()
			new planet_type(x_pos, y_pos, planet_name, planet_type, src)
			// Planet is automatically added to this system via its New() method
			log_world("Generated planet: [planet_name] ([planet_type]) at ([x_pos], [y_pos]) in system [system_name]")

/datum/overmap_star_system/proc/gen_planet_name()
	. = ""
	switch(rand(1,10))
		if(1 to 4)
			for(var/i in 1 to rand(2,3))
				. += capitalize(pick(GLOB.alphabet))
			. += "-"
			. += "[pick(rand(1,999))]"
		if(4 to 9)
			. += "[pick(GLOB.planet_names)] \Roman[rand(1,9)]"
		if(10)
			. += "[pick(GLOB.planet_prefixes)] [pick(GLOB.planet_names)]"
	return .
/**
 * Get all objects of a specific type in this system
 */
/datum/overmap_star_system/proc/get_objects_by_type(type_path)
	var/list/result = list()
	for(var/datum/orbital_object/obj in orbital_objects)
		if(istype(obj, type_path))
			result += obj
	return result

/**
 * Get all shuttles in this system
 */
/datum/overmap_star_system/proc/get_shuttles()
	return get_objects_by_type(/datum/orbital_object/shuttle)

/**
 * Get all stations in this system
 */
/datum/overmap_star_system/proc/get_stations()
	return get_objects_by_type(/datum/orbital_object/station)

/**
 * Get all planets in this system
 */
/datum/overmap_star_system/proc/get_planets()
	return get_objects_by_type(/datum/orbital_object/planet)

/**
 * Process all objects in this system
 */
/datum/overmap_star_system/proc/process_objects(seconds_per_tick)
	for(var/datum/orbital_object/obj in orbital_objects)
		obj.process(seconds_per_tick)

/**
 * Get map data for all objects in this system
 */
/datum/overmap_star_system/proc/get_map_data()
	var/list/data = list()
	data["system_id"] = system_id
	data["system_name"] = system_name
	data["system_description"] = system_description
	data["star_x"] = star_x
	data["star_y"] = star_y
	data["star_color"] = star_color
	data["map_objects"] = list()

	for(var/datum/orbital_object/obj in orbital_objects)
		data["map_objects"] += list(obj.get_map_data())

	return data
