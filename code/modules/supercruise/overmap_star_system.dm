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
	var/star_z = 0
	/// Star color (for rendering)
	var/star_color = "#ffff88"
	/// System bounds (for rendering limits)
	var/min_height = -300
	var/max_height = 600
	/// Whether this system can be jumped to
	var/can_jump = TRUE
	// Central star object (for future star rendering)
	var/datum/orbital_object/star/central_star = null

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
 * Генерируем планеты с 3D-орбитами
 */
/datum/overmap_star_system/proc/generate_planets(num_planets = 8)
	var/list/planet_types = GLOB.planet_types

	// Если центральной звезды нет — создаем её
	if(!central_star)
		central_star = new(star_x, star_y, star_z, "[system_name] Star", src)
		central_star.supercruise_color = star_color

	for(var/i in 1 to num_planets)
		var/planet_type = pick(planet_types)
		var/planet_name = gen_planet_name()

		// Создаем планету (пока в центре, позицию пересчитает process())
		var/datum/orbital_object/planet/new_planet = new planet_type(star_x, star_y, star_z, planet_name, planet_type, src)

		// Назначаем центр орбиты
		new_planet.orbit_center = central_star

		// Случайные 3D параметры
		new_planet.orbit_radius = rand(100, 500) // Разброс расстояний
		new_planet.orbit_angle = rand(0, 360) // Случайная стартовая фаза
		new_planet.orbit_speed = (10 / new_planet.orbit_radius) * 10 // Кеплеровская зависимость (дальше = медленнее)

		// Полноценный 3D наклон!
		new_planet.orbit_inclination = rand(-75, 75)
		new_planet.orbit_ascension = rand(0, 360)

		// Вызываем первый тик, чтобы планета сразу встала на свою 3D-орбиту
		new_planet.process(0)

		log_world("Generated planet: [planet_name] orbiting [central_star.name] at R:[new_planet.orbit_radius] Inc:[new_planet.orbit_inclination] Asc:[new_planet.orbit_ascension]")

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
	data["star_z"] = star_z
	data["star_color"] = star_color
	data["map_objects"] = list()

	for(var/datum/orbital_object/obj in orbital_objects)
		data["map_objects"] += list(obj.get_map_data())

	return data
