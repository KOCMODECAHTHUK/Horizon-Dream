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
	/// Mass of the object in solar masses
	var/mass = 0
	/// Radius of the object in ~~parsecs~~ arbitary space units
	var/radius = 1
	/// Position
	var/pos_x = 0
	var/pos_y = 0
	var/pos_z = 0
	/// Velocity
	var/vel_x = 0
	var/vel_y = 0
	var/vel_z = 0
	/// Render mode for UI (default, planet, shuttle, etc)
	var/render_mode = RENDER_MODE_DEFAULT
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
	if(!spawn_system)
		spawn_system = SSsupercruise.get_default_system()
	if(spawn_system)
		spawn_system.add_object(src)

/datum/orbital_object/proc/set_position(x = 0, y = 0, z = 0)
	pos_x = x
	pos_y = y
	pos_z = z

/datum/orbital_object/proc/set_velocity(vx = 0, vy = 0, vz = 0)
	vel_x = vx
	vel_y = vy
	vel_z = vz

/datum/orbital_object/Destroy()
	// Remove from star system if we belong to one
	if(star_system)
		star_system.remove_object(src)
	return ..()

/datum/orbital_object/process(seconds_per_tick)
	pos_x += vel_x * seconds_per_tick
	pos_y += vel_y * seconds_per_tick
	pos_z += vel_z * seconds_per_tick

/datum/orbital_object/proc/get_map_data()
	return list(
		"id" = unique_id,
		"name" = name,
		"position_x" = pos_x,
		"position_y" = pos_y,
		"position_z" = pos_z,
		"velocity_x" = vel_x,
		"velocity_y" = vel_y,
		"velocity_z" = vel_z,
		"radius" = radius,
		"render_mode" = render_mode,
		"vel_mult" = 1,
		"priority" = 0,
		"supercruise_color" = supercruise_color,
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
