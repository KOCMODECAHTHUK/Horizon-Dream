/obj/docking_port/stationary
	/// Moves docking port around in its "box" so that any ship can land in this "box"
	var/adjust_dock_for_landing = FALSE
	/// Is set to TRUE when we are adjusting the dock for landing, prevents concurrent adjustments
	var/is_adjusting_now = FALSE
	/// The docking ticket of the ship docking to this port (prevents double-booking)
	var/datum/docking_ticket/current_docking_ticket
	/// Reference to the planet generator creating this planet (used to check if generation is complete)
	var/datum/map_generator/planet_generator/planet_generator

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
