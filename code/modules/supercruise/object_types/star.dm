/**
 * # Orbital Star
 * Central celestial object that emits gravity and light.
 */
/datum/orbital_object/star
	render_mode = "star"
	radius = 40
	supercruise_color = "#ffff88"
	name = "Star"
	/// Масса звезды для расчета гравитации
	var/gravity_mass = 5000

/datum/orbital_object/star/New(x_pos = 0, y_pos = 0, z_pos = 0, star_name = "Star", datum/overmap_star_system/spawn_system = null)
	. = ..(x_pos, y_pos, z_pos, spawn_system)
	name = star_name

/datum/orbital_object/star/process(seconds_per_tick)
	return

/datum/orbital_object/star/interact(datum/orbital_object/shuttle/interacting_shuttle, mob/user)
	return "Cannot dock with a star"
