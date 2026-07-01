/**
 * # Supercruise Subsystem
 *
 * Handles orbital object movement and updates UIs.
 * Based on BeeStation's SSorbits but simplified.
 */
SUBSYSTEM_DEF(supercruise)
	name = "Supercruise"
	ss_flags = SS_KEEP_TIMING
	wait = 5 // Update every 0.5 seconds (5 deciseconds) for smoother client interpolation
	priority = FIRE_PRIORITY_DEFAULT

	/// All star systems indexed by system_id
	var/list/datum/overmap_star_system/star_systems = list()

	/// Open UIs that need to be updated
	var/list/open_orbital_maps = list()

	/// The default system ID for new objects
	var/default_system_id = "sol_system"

/datum/controller/subsystem/supercruise/Initialize()
	// Create the first star system (Sol System)
	var/datum/overmap_star_system/sol_system = new("sol_system", "Sol System", "The home system of humanity.")
	sol_system.star_x = 0
	sol_system.star_y = 0
	sol_system.star_color = "#ffff88"

	// Create a test station in Sol at coordinates (100, 50)
	var/datum/orbital_object/station/test_station = new(100, 50, "Test Station Alpha", sol_system)

	// Generate planets for Sol system
	sol_system.generate_planets(rand(8, 12))

	// Create a second test system (Alpha Centauri)
	var/datum/overmap_star_system/alpha_system = new("alpha_centauri", "Alpha Centauri", "The closest star system to Sol.")
	alpha_system.star_x = 0
	alpha_system.star_y = 0
	alpha_system.star_color = "#ffaa44"

	// Create a test station in Alpha Centauri at different coordinates
	var/datum/orbital_object/station/alpha_station = new(150, -100, "Alpha Station One", alpha_system)

	// Generate planets for Alpha Centauri system
	alpha_system.generate_planets(rand(5, 8))

	// Both systems can be jumped to (can_jump defaults to TRUE)
	log_world("Supercruise: Initialized [length(star_systems)] star systems")

	return SS_INIT_SUCCESS

/datum/controller/subsystem/supercruise/fire(resumed)
	// Update all orbital objects in all systems
	// Convert wait (deciseconds) to seconds for the process call
	var/seconds_per_tick = wait / 10
	for(var/system_id in star_systems)
		var/datum/overmap_star_system/system = star_systems[system_id]
		system.process_objects(seconds_per_tick)

	// Update all open UIs
	for(var/datum/tgui/ui in open_orbital_maps)
		// Check if UI is still valid and has a user
		if(!ui || !ui.user || !ui.user.client)
			open_orbital_maps -= ui
			continue
		ui.send_update()

/**
 * Get data for rendering the orbital map
 * If system_id is provided, returns data for that system only
 * If system_id is null, returns data for the default system
 */
/datum/controller/subsystem/supercruise/proc/get_orbital_map_data(system_id = null)
	if(!system_id)
		system_id = default_system_id

	var/datum/overmap_star_system/system = star_systems[system_id]
	if(!system)
		// Fall back to first available system
		if(length(star_systems))
			system = star_systems[star_systems[1]]
		else
			return list("error" = "No systems available")

	var/list/data = system.get_map_data()
	data["update_index"] = times_fired
	return data

/**
 * Get a list of all available star systems for UI selection
 */
/datum/controller/subsystem/supercruise/proc/get_systems_list()
	var/list/systems = list()
	for(var/system_id in star_systems)
		var/datum/overmap_star_system/system = star_systems[system_id]
		systems += list(list(
			"id" = system.system_id,
			"name" = system.system_name,
			"description" = system.system_description
		))
	return systems

/**
 * Get the default system (usually where the main station is)
 */
/datum/controller/subsystem/supercruise/proc/get_default_system()
	return star_systems[default_system_id]

/**
 * Get a system by ID
 */
/datum/controller/subsystem/supercruise/proc/get_system(system_id)
	return star_systems[system_id]

/**
 * Find an orbital object by its unique ID
 * If system is specified, searches only that system
 * If system is null, searches the default system
 */
/datum/controller/subsystem/supercruise/proc/find_object(object_id, datum/overmap_star_system/system = null)
	if(!system)
		system = get_default_system()
	if(!system)
		return null

	for(var/datum/orbital_object/obj in system.orbital_objects)
		if(obj.unique_id == object_id)
			return obj
	return null

/**
 * Get the current system an orbital object is in
 */
/datum/controller/subsystem/supercruise/proc/get_current_system(datum/orbital_object/obj)
	return obj?.star_system

/**
 * Move an orbital object to a different star system
 * Returns TRUE on success, FALSE on failure
 */
/datum/controller/subsystem/supercruise/proc/move_to_system(datum/orbital_object/obj, datum/overmap_star_system/new_system, x_pos = 0, y_pos = 0)
	if(!obj || !new_system)
		return FALSE

	// Don't move if object is a docked/docking shuttle
	if(istype(obj, /datum/orbital_object/shuttle))
		var/datum/orbital_object/shuttle/shuttle = obj
		if(shuttle.docked_at || shuttle.is_docking)
			return FALSE

	// Remove from current system
	if(obj.star_system)
		obj.star_system.remove_object(obj)

	// Add to new system
	new_system.add_object(obj)

	// Set new position
	obj.position_x = x_pos
	obj.position_y = y_pos

	// Reset movement for shuttles
	if(istype(obj, /datum/orbital_object/shuttle))
		var/datum/orbital_object/shuttle/shuttle = obj
		shuttle.velocity_x = 0
		shuttle.velocity_y = 0
		shuttle.autopilot_enabled = FALSE
		shuttle.target_position = null

	return TRUE
