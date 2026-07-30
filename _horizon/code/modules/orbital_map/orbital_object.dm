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
	/// Position of the object (0,0,0) is the center of the map.
	var/datum/orbital_vector/position
	/// Velocity of the object
	var/datum/orbital_vector/velocity
	/// Render mode for UI (default, planet, shuttle, etc)
	var/render_mode = RENDER_MODE_DEFAULT
	/// Color for rendering
	var/supercruise_color = "#c17a23"
	/// The star system this object belongs to
	var/datum/overmap_star_system/star_system = null

	var/velocity_multiplier = 1
	var/static_object = FALSE
	var/ignore_gravity = FALSE

	/// TODO: Интеракции с объектом
	//var/list/interaction_options = list()

/datum/orbital_object/New(x_pos = 0, y_pos = 0, z_pos = 0, datum/overmap_star_system/spawn_system = null)
	. = ..()
	unique_id = "\ref[src]"
	position = new(x_pos, y_pos, z_pos)
	velocity = new()

	if(!spawn_system)
		spawn_system = SSsupercruise.get_default_system()
	if(spawn_system)
		spawn_system.add_object(src)

/datum/orbital_object/Destroy()
	if(star_system)
		star_system.remove_object(src)
	QDEL_NULL(position)
	QDEL_NULL(velocity)
	return ..()

/datum/orbital_object/process(seconds_per_tick)
	if(static_object || ignore_gravity || !star_system)
		return

	var/datum/orbital_vector/total_accel = new()
	var/datum/orbital_object/dominant_body = null
	var/max_pull = 0

	// Находим доминирующее тело (SOI)
	for(var/datum/orbital_object/body in star_system.orbital_objects)
		if(!body.mass || body == src) continue
		var/datum/orbital_vector/delta = body.position.Subtract(position)
		var/dist_sq = delta.Dot(delta)
		if(dist_sq > 1000000) continue // увеличили cut-off
		var/pull = body.mass / max(dist_sq, 1)
		if(pull > max_pull)
			max_pull = pull
			dominant_body = body

	// Ускорение от доминанта
	if(dominant_body)
		var/datum/orbital_vector/delta = dominant_body.position.Subtract(position)
		var/dist = max(delta.Length(), 0.1)
		var/pull = dominant_body.mass / (dist * dist)
		var/datum/orbital_vector/norm = delta.GetNormalized()
		total_accel.AddSelf(norm.Scale(pull))

	// Слабое влияние центральной звезды (для долгосрочной стабильности)
	if(star_system.central_star && dominant_body != star_system.central_star)
		var/datum/orbital_vector/delta = star_system.central_star.position.Subtract(position)
		var/dist = max(delta.Length(), 0.1)
		var/pull = star_system.central_star.mass / (dist * dist) * 0.05 // 5% от силы
		var/datum/orbital_vector/norm = delta.GetNormalized()
		total_accel.AddSelf(norm.Scale(pull))

	velocity.AddSelf(total_accel.ScaleSelf(seconds_per_tick))
	position.AddSelf(velocity.Scale(seconds_per_tick * velocity_multiplier))
	check_collisions()

/datum/orbital_object/proc/check_collisions()
	return

/datum/orbital_object/proc/get_map_data()
	return list(
		"id" = unique_id,
		"name" = name,
		"position_x" = position.x,
		"position_y" = position.y,
		"position_z" = position.z,
		"velocity_x" = velocity.x,
		"velocity_y" = velocity.y,
		"velocity_z" = velocity.z,
		"radius" = radius,
		"render_mode" = render_mode,
		"vel_mult" = velocity_multiplier,
		"priority" = 0,
		"supercruise_color" = supercruise_color,
		"system_id" = star_system?.system_id
	)

/datum/orbital_object/proc/interact(datum/orbital_object/shuttle/interacting_shuttle, mob/user, obj/machinery/computer/shuttle_flight/flight_console = null)
	to_chat(user, span_notice("You examine [name] from a distance. Nothing happens."))
	return null
