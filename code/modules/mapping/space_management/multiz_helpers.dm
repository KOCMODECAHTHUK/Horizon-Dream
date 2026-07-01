/proc/get_step_multiz(ref, dir)
	var/turf/us = get_turf(ref)
	if(dir & UP)
		dir &= ~UP
		return get_step(GET_TURF_ABOVE(us), dir)
	if(dir & DOWN)
		dir &= ~DOWN
		return get_step(GET_TURF_BELOW(us), dir)
	return get_step(ref, dir)

/proc/get_dir_multiz(turf/us, turf/them)
	us = get_turf(us)
	them = get_turf(them)
	if(!us || !them)
		return NONE

	// Check if we're in the same virtual level first
	var/our_vz = us.virtual_z()
	var/their_vz = them.virtual_z()

	if(our_vz && their_vz && our_vz != their_vz)
		// Different virtual levels - use virtual level linkage
		var/datum/virtual_level/our_vlevel = us.get_virtual_level()
		if(our_vlevel?.up_linkage?.id == their_vz)
			return (UP | get_dir(us, them))
		else if(our_vlevel?.down_linkage?.id == their_vz)
			return (DOWN | get_dir(us, them))
		// Not linked, return planar direction
		return get_dir(us, them)

	if(us.z == them.z)
		return get_dir(us, them)
	else
		var/turf/T = GET_TURF_ABOVE(us)
		var/dir = NONE
		if(T && (T.virtual_z == them.virtual_z))
			dir = UP
		else
			T = GET_TURF_BELOW(us)
			if(T && (T.virtual_z == them.virtual_z))
				dir = DOWN
			else
				return get_dir(us, them)
		return (dir | get_dir(us, them))

/proc/get_lowest_turf(atom/ref)
	var/turf/us = get_turf(ref)
	var/turf/next = GET_TURF_BELOW(us)
	while(next)
		us = next
		next = GET_TURF_BELOW(us)
	return us

// I wish this was lisp
/proc/get_highest_turf(atom/ref)
	var/turf/us = get_turf(ref)
	var/turf/next = GET_TURF_ABOVE(us)
	while(next)
		us = next
		next = GET_TURF_ABOVE(us)
	return us
