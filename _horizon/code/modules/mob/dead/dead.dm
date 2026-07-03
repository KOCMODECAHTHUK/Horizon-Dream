/**
 * Updates virtual z-level tracking for dead mobs
 * Handles dead_players_by_virtual_z list maintenance
 *
 * * new_virtual_z - The new virtual z ID (or null to unregister)
 * * old_virtual_z - The old virtual z ID
 */
/mob/dead/on_virtual_z_change(new_virtual_z, old_virtual_z)
	. = ..()
	if(!client)
		return

	// Remove from old virtual z tracking
	if(old_virtual_z)
		LAZYREMOVE(SSmobs.dead_players_by_virtual_z["[old_virtual_z]"], src)

	// Add to new virtual z tracking
	if(new_virtual_z)
		LAZYADD(SSmobs.dead_players_by_virtual_z["[new_virtual_z]"], src)
