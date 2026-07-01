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
	/// Unified 3D vectors for position and velocity
	var/list/position = list(0, 0, 0)
	var/list/velocity = list(0, 0, 0)
	/// Render mode for UI (default, planet, shuttle, etc)
	var/render_mode = "default"
	/// Color for rendering
	var/supercruise_color = "#c17a23"
	///how can a ship interact with the datum TODO!!!!!
	var/list/interaction_options = list()
	/// The star system this object belongs to
	var/datum/overmap_star_system/star_system = null

/datum/orbital_object/New(x_pos = 0, y_pos = 0, z_pos = 0, datum/overmap_star_system/spawn_system = null)
	. = ..()
	unique_id = "\ref[src]"
	set_position(x_pos, y_pos, z_pos)
	set_velocity(0, 0, 0)
	// Add to the specified system, or the default system if none specified
	if(!spawn_system)
		spawn_system = SSsupercruise.get_default_system()
	if(spawn_system)
		spawn_system.add_object(src)

/datum/orbital_object/proc/set_position(x_pos = 0, y_pos = 0, z_pos = 0)
	position = list(x_pos, y_pos, z_pos)

/datum/orbital_object/proc/set_velocity(x_vel = 0, y_vel = 0, z_vel = 0)
	velocity = list(x_vel, y_vel, z_vel)

/datum/orbital_object/proc/get_position()
	return position.Copy()

/datum/orbital_object/proc/get_velocity()
	return velocity.Copy()

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
	// Update position using unified vector math
	position[1] += velocity[1] * seconds_per_tick
	position[2] += velocity[2] * seconds_per_tick
	position[3] += velocity[3] * seconds_per_tick

/**
 * Get data for UI display
 */
/datum/orbital_object/proc/get_map_data()
	return list(
		"id" = unique_id,
		"name" = name,
		"position" = position.Copy(),
		"velocity" = velocity.Copy(),
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
