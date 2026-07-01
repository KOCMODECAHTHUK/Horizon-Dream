/**
 * # Orbital Object
 *
 * Represents an object in orbital space (supercruise).
 * Has a position and velocity, gets updated by SSsupercruise.
 */
/datum/orbital_object
	/// Unique identifier
	var/unique_id = ""
	/// Display name
	var/name = "Unknown Object"
	/// Radius for rendering/collision (in arbitrary units)
	var/radius = 1
	/// Position X (in kilometers)
	var/position_x = 0
	/// Position Y (in kilometers)
	var/position_y = 0
	/// Position Z / altitude (in kilometers)
	var/position_z = 0
	/// Velocity X (in kilometers per second)
	var/velocity_x = 0
	/// Velocity Y (in kilometers per second)
	var/velocity_y = 0
	/// Velocity Z (in kilometers per second)
	var/velocity_z = 0
	/// Render mode for UI (default, planet, shuttle, etc)
	var/render_mode = "default"
	/// Color for rendering
	var/supercruise_color = "#c17a23"
	///how can a ship interact with the datum TODO!!!!!
	var/list/interaction_options = list()
	/// The star system this object belongs to
	var/datum/overmap_star_system/star_system = null

/datum/orbital_object/New(x_pos = 0, y_pos = 0, datum/overmap_star_system/spawn_system = null)
	. = ..()
	unique_id = "\ref[src]"
	position_x = x_pos
	position_y = y_pos
	// Add to the specified system, or the default system if none specified
	if(!spawn_system)
		spawn_system = SSsupercruise.get_default_system()
	if(spawn_system)
		spawn_system.add_object(src)

/datum/orbital_object/Destroy()
	// Remove from star system if we belong to one
	if(star_system)
		star_system.remove_object(src)
	return ..()

/**
 * Called by SSsupercruise to update position based on velocity
 * seconds_per_tick is in seconds (from delta_time / 10)
 */
/datum/orbital_object/process(seconds_per_tick)
	// Update position: position += velocity * time
	position_x += velocity_x * seconds_per_tick
	position_y += velocity_y * seconds_per_tick

/**
 * Get data for UI display
 */
/datum/orbital_object/proc/get_map_data()
	return list(
		"id" = unique_id,
		"name" = name,
		"position_x" = position_x,
		"position_y" = position_y,
		"position_z" = position_z,
		"velocity_x" = velocity_x,
		"velocity_y" = velocity_y,
		"velocity_z" = velocity_z,
		"radius" = radius,
		"render_mode" = render_mode,
		"vel_mult" = 1, // Velocity multiplier for UI interpolation
		"priority" = 0, // For UI sorting
		"supercruise_color"	= supercruise_color,
		"system_id" = star_system?.system_id
	)

/**
 * Called when a shuttle tries to interact with this object
 * Override in child classes to provide specific functionality
 * Returns null on success, or an error message string on failure
 */
/datum/orbital_object/proc/interact(datum/orbital_object/shuttle/interacting_shuttle, mob/user)
	to_chat(user, span_notice("You examine [name] from a distance. Nothing happens."))
	return null
