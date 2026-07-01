/**
 * Used to get the virtual z-level.
 * Will give unique values to each shuttle while it is in a transit level.
 * Note: If the user teleports to another virtual z on the same z-level they will need to have reset_virtual_z called. (Teleportations etc.)
 */

/// Virtual Z is optimized lookup of the virtual level for comparisons, but it doesn't pass the reference
/atom/proc/virtual_z()
	return

/atom/movable/virtual_z()
	var/turf/my_turf = get_turf(src)
	if(!my_turf)
		return 0
	return my_turf.virtual_z

/turf/virtual_z() //Just read the variable if you access a turf already, please
	return virtual_z // Some day put a stack trace and figure out all use cases of this and change them to .virtual_level instead

/area/virtual_z()
	var/turf/my_turf = locate(x,y,z)
	if(!my_turf)
		return 0
	return my_turf.virtual_z

/atom/proc/get_virtual_level()
	RETURN_TYPE(/datum/virtual_level)
	return

/atom/movable/get_virtual_level()
	var/turf/my_turf = get_turf(src)
	if(!my_turf)
		return
	return my_turf.get_virtual_level()

/area/get_virtual_level()
	var/turf/my_turf = locate(x,y,z)
	if(!my_turf)
		return
	return my_turf.get_virtual_level()

/turf/get_virtual_level()
	return SSmapping.virtual_z_translation["[virtual_z]"]

/atom/proc/get_map_zone()
	var/datum/virtual_level/vlevel = get_virtual_level()
	if(vlevel)
		return vlevel.parent_map_zone

/atom/proc/get_relative_location()
	var/datum/virtual_level/vlevel = get_virtual_level()
	return vlevel?.get_relative_coords(src)

/atom/proc/get_overmap_location()
	//var/datum/map_zone/our_zone = get_map_zone()
	// This would need SSovermap implementation if you're using overmap
	// For now just return null
	return null

/// Helper proc to get turf below, handling virtual levels and reservations
/proc/get_turf_below_helper(location)
	var/turf/T = get_turf(location)
	if(!T)
		return null

	// Check for virtual level first
	if(T.virtual_z)
		var/datum/virtual_level/vlevel = SSmapping.virtual_z_translation["[T.virtual_z]"]
		if(vlevel)
			return vlevel.get_below_turf(T)
		return null

	// Check for reservation
	if(T.turf_flags & RESERVATION_TURF)
		var/datum/turf_reservation/reservation = SSmapping.get_reservation_from_turf(T)
		if(reservation)
			return reservation.get_turf_below(T)
		return null

	// Fall back to standard multiz
	if(length(SSmapping.multiz_levels) && SSmapping.multiz_levels[T.z][Z_LEVEL_DOWN])
		return get_step(T, DOWN)

	return null

/// Helper proc to get turf above, handling virtual levels and reservations
/proc/get_turf_above_helper(location)
	var/turf/T = get_turf(location)
	if(!T)
		return null

	// Check for virtual level first
	if(T.virtual_z)
		var/datum/virtual_level/vlevel = SSmapping.virtual_z_translation["[T.virtual_z]"]
		if(vlevel)
			return vlevel.get_above_turf(T)
		return null

	// Check for reservation
	if(T.turf_flags & RESERVATION_TURF)
		var/datum/turf_reservation/reservation = SSmapping.get_reservation_from_turf(T)
		if(reservation)
			return reservation.get_turf_above(T)
		return null

	// Fall back to standard multiz
	if(length(SSmapping.multiz_levels) && SSmapping.multiz_levels[T.z][Z_LEVEL_UP])
		return get_step(T, UP)

	return null
