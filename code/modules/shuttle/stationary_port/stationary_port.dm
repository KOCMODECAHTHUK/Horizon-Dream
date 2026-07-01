
/obj/docking_port/stationary
	name = "dock"

	var/last_dock_time

	/// Map template to load when the dock is loaded
	var/datum/map_template/shuttle/roundstart_template
	/// The shuttle template id to use after roundstart
	var/shuttle_template_id
	/// Used to check if the shuttle template is enabled in the config file
	var/json_key
	/// If true, the shuttle can always dock at this docking port, despite its area checks, or if something is already docked
	var/override_can_dock_checks = FALSE
	/// Moves docking port around in its "box" so that any ship can land in this "box"
	var/adjust_dock_for_landing = FALSE
	/// Is set to TRUE when we are adjusting the dock for landing, prevents concurrent adjustments
	var/is_adjusting_now = FALSE
	/// The docking ticket of the ship docking to this port (prevents double-booking)
	var/datum/docking_ticket/current_docking_ticket
	/// Reference to the planet generator creating this planet (used to check if generation is complete)
	var/datum/map_generator/planet_generator/planet_generator
	// Our initial roundstart coordinates
	var/initial_x = -1
	var/initial_y = -1
	var/initial_z = -1

/obj/docking_port/stationary/get_save_vars()
	return ..() + NAMEOF(src, roundstart_template)

/obj/docking_port/stationary/Initialize(mapload)
	. = ..()
	register()
	if(!area_type)
		var/area/place = get_area(src)
		area_type = place?.type // We might be created in nullspace

	if(mapload)
		for(var/turf/T in return_turfs())
			T.turf_flags |= NO_RUINS

	initial_x = x
	initial_y = y
	initial_z = z

	if(SSshuttle.initialized)
		return INITIALIZE_HINT_LATELOAD

/obj/docking_port/stationary/LateInitialize()
	INVOKE_ASYNC(SSshuttle, TYPE_PROC_REF(/datum/controller/subsystem/shuttle, setup_shuttles), list(src))

#ifdef TESTING
	highlight("#f00")
#endif

/obj/docking_port/stationary/Destroy(force)
	if(force)
		unregister()
	return ..()

/obj/docking_port/stationary/register(replace = FALSE)
	. = ..()
	if(!shuttle_id)
		shuttle_id = "dock"
	else
		port_destinations = shuttle_id

	if(!name)
		name = "dock"

	var/counter = SSshuttle.assoc_stationary[shuttle_id]
	if(!replace || !counter)
		if(counter)
			counter++
			SSshuttle.assoc_stationary[shuttle_id] = counter
			shuttle_id = "[shuttle_id]_[counter]"
			name = "[name] [counter]"
		else
			SSshuttle.assoc_stationary[shuttle_id] = 1

	if(!port_destinations)
		port_destinations = shuttle_id

	SSshuttle.stationary_docking_ports += src

/obj/docking_port/stationary/unregister()
	. = ..()
	SSshuttle.stationary_docking_ports -= src

/obj/docking_port/stationary/Moved(atom/old_loc, movement_dir, forced, list/old_locs, momentum_change = TRUE)
	. = ..()
	if(area_type) // We already have one
		return
	var/area/newarea = get_area(src)
	area_type = newarea?.type

/obj/docking_port/stationary/proc/load_roundstart()
	if(json_key)
		var/sid = SSmapping.current_map.shuttles[json_key]
		shuttle_template_id = SSmapping.shuttle_templates[sid]
		if(!shuttle_template_id)
			CRASH("json_key:[json_key] value \[[sid]\] resulted in a null shuttle template for [src]")
	else if(roundstart_template) // passed a PATH
		var/sid = "[initial(roundstart_template.port_id)]_[initial(roundstart_template.suffix)]"

		shuttle_template_id = SSmapping.shuttle_templates[sid]
		if(!shuttle_template_id)
			CRASH("Invalid path ([sid]/[shuttle_template_id]) passed to docking port.")

	if(shuttle_template_id)
		SSshuttle.action_load(shuttle_template_id, src)

//returns first-found touching shuttleport
/obj/docking_port/stationary/get_docked()
	. = locate(/obj/docking_port/mobile) in loc

/**
 * Helper proc for docking. Alters the position and orientation of a stationary docking port
 * to ensure that any mobile port small enough can dock within its bounds.
 * Based on PentestSS13's implementation.
 */
/obj/docking_port/stationary/proc/adjust_dock_to_shuttle(obj/docking_port/mobile/shuttle)
	if(!adjust_dock_for_landing || is_adjusting_now)
		return
	is_adjusting_now = TRUE

	if(!istype(shuttle))
		is_adjusting_now = FALSE
		CRASH("Invalid docking port ([shuttle]) passed to adjust_dock_to_shuttle().")

	// Store original values in case we need to revert
	var/oldloc = loc
	var/olddir = dir
	var/olddheight = dheight
	var/olddwidth = dwidth
	var/oldheight = height
	var/oldwidth = width

	// Get the shuttle's "true" dimensions (accounting for port direction)
	var/shuttle_true_height = shuttle.height
	var/shuttle_true_width = shuttle.width

	// If the port's location is perpendicular to the shuttle's fore, swap dimensions
	if(shuttle.port_direction == EAST || shuttle.port_direction == WEST)
		shuttle_true_height = shuttle.width
		shuttle_true_width = shuttle.height

	// Calculate the direction the stationary port should face (points inward)
	var/final_facing_dir = angle2dir(dir2angle(shuttle_true_height > shuttle_true_width ? EAST : NORTH) + dir2angle(shuttle.port_direction) + 180)

	// Get current corners of the dock's covered area
	var/list/old_corners = return_coords()
	var/list/new_dock_location

	// Determine new corner position based on direction change
	if(final_facing_dir == dir)
		new_dock_location = list(old_corners[1], old_corners[2]) // Don't move the corner
	else if(final_facing_dir == angle2dir(dir2angle(dir) + 180))
		new_dock_location = list(old_corners[3], old_corners[4]) // Flip to opposite corner
	else
		var/combined_dirs = final_facing_dir | dir
		if(combined_dirs == (NORTH|EAST) || combined_dirs == (SOUTH|WEST))
			new_dock_location = list(old_corners[1], old_corners[4]) // Move vertically
		else
			new_dock_location = list(old_corners[3], old_corners[2]) // Move horizontally

		// Need to flip height and width
		var/dock_height_store = height
		height = width
		width = dock_height_store

	dir = final_facing_dir

	// Check if shuttle fits in our bounds
	if(shuttle.height > height || shuttle.width > width)
		// Revert changes - shuttle too big
		forceMove(oldloc)
		dir = olddir
		dheight = olddheight
		dwidth = olddwidth
		height = oldheight
		width = oldwidth
		is_adjusting_now = FALSE
		return

	// Calculate offset for the dock within its area to center the shuttle
	var/new_dheight = round((height - shuttle.height) / 2) + shuttle.dheight
	var/new_dwidth = round((width - shuttle.width) / 2) + shuttle.dwidth

	// Apply the offset based on direction
	switch(final_facing_dir)
		if(NORTH)
			new_dock_location[1] += new_dwidth
			new_dock_location[2] += new_dheight
		if(SOUTH)
			new_dock_location[1] -= new_dwidth
			new_dock_location[2] -= new_dheight
		if(EAST)
			new_dock_location[1] += new_dheight
			new_dock_location[2] -= new_dwidth
		if(WEST)
			new_dock_location[1] -= new_dheight
			new_dock_location[2] += new_dwidth

	// Move the dock to the new position
	forceMove(locate(new_dock_location[1], new_dock_location[2], z))
	dheight = new_dheight
	dwidth = new_dwidth

	// Verify we didn't end up in an edge turf (virtual border)
	for(var/turf/closed/indestructible/edgeturf as anything in return_turfs())
		if(!istype(edgeturf))
			continue
		// Found an edge turf - this is bad, revert!
		WARNING("[src] adjusted to fit [shuttle] but ended up in an edge tile! Reverting.")
		forceMove(oldloc)
		dir = olddir
		dheight = olddheight
		dwidth = olddwidth
		height = oldheight
		width = oldwidth
		break

	is_adjusting_now = FALSE
