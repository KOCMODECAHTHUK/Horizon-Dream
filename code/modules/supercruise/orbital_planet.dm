/**
 * # Orbital Planet
 *
 * Represents a planet in orbital space.
 * Planets are large, non-moving objects that can be interacted with.
 */
/datum/orbital_object/planet
	render_mode = "planet"
	radius = 8  // Larger than shuttles and stations
	/// Whether this planet can be landed on
	var/landable = TRUE
	/// Description shown when examining
	var/description = "A distant celestial body."
	/// The map generator type to use for this planet
	var/map_generator_type = /datum/map_generator/planet_generator/rocky
	/// Reference to the generated virtual level
	var/datum/virtual_level/planet_level
	/// List of docking ports for ship landing
	var/list/obj/docking_port/stationary/reserve_docks
	/// Size of the planet surface (square dimensions)
	var/planet_size = 100
	/// Base turf type for this planet
	var/baseturf_type = /turf/open/space/basic
	/// If TRUE, planet will not be unloaded when all players leave (default FALSE)
	var/preserve_level = FALSE

/datum/orbital_object/planet/New(x_pos, y_pos, planet_name, set_type = /datum/orbital_object/planet/rocky, datum/overmap_star_system/spawn_system = null)
	. = ..(x_pos, y_pos, spawn_system)
	name = planet_name

/**
 * Generate the planet level lazily (when first needed)
 */
/datum/orbital_object/planet/proc/generate_level()
	if(planet_level)
		return TRUE // Already generated

	if(!map_generator_type)
		log_world("ERROR: Planet [name] has no map generator type!")
		return FALSE

	var/datum/map_generator/planet_generator/generator = new map_generator_type()

	var/list/result = generator.generate_planet_level(name, planet_size, baseturf_type, null)

	if(!result || !length(result))
		log_world("ERROR: Failed to generate planet level for [name]")
		return FALSE

	planet_level = result[1]
	reserve_docks = result[2]

	if(!planet_level)
		log_world("ERROR: Invalid planet level generated for [name]")
		return FALSE

	log_world("Planet [name] successfully generated with [length(reserve_docks)] docking ports")
	return TRUE

/**
 * Get available docking locations on this planet
 * Now checks for both occupied docks AND reserved docks (via tickets)
 */
/datum/orbital_object/planet/proc/get_dockable_locations()
	if(!planet_level && !generate_level())
		return list()

	var/list/available_docks = list()
	for(var/obj/docking_port/stationary/dock as anything in reserve_docks)
		// Check if dock is occupied OR has a reservation ticket
		var/occupied = FALSE
		for(var/obj/docking_port/mobile/M in SSshuttle.mobile_docking_ports)
			if(M.get_docked() == dock)
				occupied = TRUE
				break

		// Also check for ticket reservation
		if(dock.current_docking_ticket)
			occupied = TRUE

		if(!occupied)
			available_docks += dock

	return available_docks

/**
 * Issue a docking ticket for a shuttle to land on this planet
 * This reserves a docking port and prevents double-booking
 *
 * Arguments:
 * * dock_requester - The shuttle requesting to dock
 * * override_dock - Optional specific dock to use, otherwise auto-selects
 *
 * Returns a docking ticket datum (check ticket.docking_error for errors)
 */
/datum/orbital_object/planet/proc/pre_docked(datum/orbital_object/shuttle/dock_requester, obj/docking_port/stationary/override_dock = null)
	// Ensure planet is generated
	if(!planet_level && !generate_level())
		return new /datum/docking_ticket(null, src, dock_requester, "[src] cannot be generated.")

	var/obj/docking_port/stationary/dock_to_use = override_dock

	// Auto-select a dock if none specified
	if(!dock_to_use)
		for(var/obj/docking_port/stationary/dock as anything in reserve_docks)
			// Check if dock is free (not occupied and no ticket)
			var/occupied = FALSE
			for(var/obj/docking_port/mobile/M in SSshuttle.mobile_docking_ports)
				if(M.get_docked() == dock)
					occupied = TRUE
					break

			if(!occupied && !dock.current_docking_ticket)
				dock_to_use = dock
				break

	// No available docks
	if(!dock_to_use)
		return new /datum/docking_ticket(null, src, dock_requester, "[src] does not have any free landing zones. Aborting docking.")

	// Create and return the ticket (this automatically reserves the port)
	return new /datum/docking_ticket(dock_to_use, src, dock_requester)

/datum/orbital_object/planet/get_map_data()
	var/list/data = ..()
	data["landable"] = landable
	return data

/**
 * Planets don't move - override the process to do nothing
 */
/datum/orbital_object/planet/process(seconds_per_tick)
	return

/**
 * Override interact to handle planet-specific interactions
 * Now uses the docking ticket system for proper port reservation
 */
/datum/orbital_object/planet/interact(datum/orbital_object/shuttle/interacting_shuttle, mob/user)
	if(!istype(interacting_shuttle))
		return "Only shuttles can interact with planets"

	// Planet-specific interaction
	if(!landable)
		to_chat(user, span_warning("[name] is not suitable for landing. [description]"))
		return "Not landable"

	to_chat(user, span_notice("You initiate landing procedures on [name]."))

	// Generate the planet level if not already generated
	if(!planet_level)
		to_chat(user, span_notice("Generating planet surface..."))
		if(!generate_level())
			to_chat(user, span_warning("ERROR: Failed to generate planet surface!"))
			return "Failed to generate planet surface"

		to_chat(user, span_boldnotice("Planet surface generated! Landing coordinates acquired."))

	// Get available docking locations (excludes occupied AND reserved ports)
	var/list/available = get_dockable_locations()

	if(!length(available))
		to_chat(user, span_warning("All landing zones are currently occupied or reserved!"))
		return "No available landing zones"

	to_chat(user, span_info("[length(available)]/[length(reserve_docks)] landing zones available."))

	// Show available landing zones
	to_chat(user, span_info("Available landing zones:"))
	for(var/obj/docking_port/stationary/dock as anything in available)
		to_chat(user, span_info("  - [dock.name] at ([dock.x], [dock.y], [dock.z])"))

	// Prompt user to select a landing zone
	var/obj/docking_port/stationary/selected_dock = tgui_input_list(user, "Select landing zone:", "Planet Landing", available)

	if(!selected_dock)
		to_chat(user, span_notice("Landing procedure cancelled."))
		return "Cancelled"

	// Check if the shuttle has a docking port
	if(!interacting_shuttle.shuttle_port)
		to_chat(user, span_warning("ERROR: Shuttle has no docking port!"))
		return "Shuttle has no docking port"

	to_chat(user, span_notice("Requesting landing clearance at [selected_dock.name]..."))

	// Issue a docking ticket to reserve the port
	var/datum/docking_ticket/ticket = pre_docked(interacting_shuttle, selected_dock)

	// Check for errors in the ticket
	if(!ticket || ticket.docking_error)
		var/error_msg = ticket?.docking_error || "Unknown error"
		to_chat(user, span_warning("ERROR: Landing clearance denied! [error_msg]"))
		if(ticket)
			qdel(ticket)
		return "Ticket error: [error_msg]"

	to_chat(user, span_notice("Landing clearance granted! Initiating landing at [selected_dock.name]..."))

	// Initiate docking using the reserved port from the ticket
	var/docking_result = interacting_shuttle.shuttle_port.initiate_docking(ticket.target_port)

	if(docking_result != DOCKING_SUCCESS)
		to_chat(user, span_warning("ERROR: Landing failed! ([docking_result])"))
		// Clean up the ticket since docking failed
		qdel(ticket)
		return "Docking failed: [docking_result]"

	to_chat(user, span_boldnotice("Landing successful! Welcome to [name]."))

	// Mark shuttle as docked
	interacting_shuttle.docked_at = src

	// Clean up the ticket now that docking is complete
	qdel(ticket)

	return null // Success

/**
 * Undock a shuttle from this planet
 */
/datum/orbital_object/planet/proc/undock_shuttle(datum/orbital_object/shuttle/target_shuttle)
	if(!target_shuttle)
		return "Invalid shuttle"

	// Mark shuttle as no longer docked
	target_shuttle.docked_at = null

	// Check if we should deload the planet after undocking
	post_undocked(target_shuttle)

	return null // Success

/**
 * Called after a shuttle undocks from the planet.
 * Checks if the planet should be deloaded (cleaned up).
 * Ported from PentestSS13's dynamic encounter system.
 */
/datum/orbital_object/planet/proc/post_undocked(datum/orbital_object/shuttle/dock_requester)
	log_world("PLANET UNDOCK: [name] - post_undocked() called by [dock_requester]")

	// Check if we should preserve this planet
	if(preserve_level)
		log_world("PLANET UNDOCK: [name] - preserve_level is TRUE, not unloading")
		return

	// Wait a bit longer for the shuttle to actually physically leave
	// The shuttle is called undock_shuttle() BEFORE it moves to transit
	// So we need to wait for the docking process to complete
	log_world("PLANET UNDOCK: [name] - scheduling unload check in 10 seconds")
	addtimer(CALLBACK(src, PROC_REF(check_and_unload)), 10 SECONDS)

/**
 * Check if planet should unload and do so if safe
 */
/datum/orbital_object/planet/proc/check_and_unload()
	// Don't deload if there are still players on the planet
	if(!can_unload_planet())
		log_world("PLANET UNDOCK: [name] - can_unload_planet() returned FALSE")
		return

	log_world("PLANET UNDOCK: [name] - initiating cleanup")
	// Do the actual cleanup
	unload_planet()

/**
 * Check if the planet can be safely unloaded.
 * Returns TRUE if planet can be cleaned up, FALSE otherwise.
 */
/datum/orbital_object/planet/proc/can_unload_planet()
	if(!planet_level)
		log_world("Planet [name] cannot unload: Already unloaded")
		return FALSE // Already unloaded

	// Check if any player minds are still on the planet
	var/list/mind_mobs = planet_level.get_mind_mobs()
	if(length(mind_mobs))
		log_world("Planet [name] cannot unload: [length(mind_mobs)] player(s) still present")
		return FALSE

	// Check if any shuttles are still docked
	for(var/obj/docking_port/stationary/dock as anything in reserve_docks)
		if(dock.get_docked())
			log_world("Planet [name] cannot unload: Shuttle [dock.get_docked()] still docked at [dock]")
			return FALSE

	log_world("Planet [name] CAN unload - all checks passed!")
	return TRUE

/**
 * Unload (cleanup) the planet level.
 * This clears all atoms from the reservation and frees the space.
 * Ported from PentestSS13's reset_dynamic() system.
 */
/datum/orbital_object/planet/proc/unload_planet()
	if(!planet_level)
		return

	log_world("PLANET UNLOAD: [name] at [REF(src)] - cleaning up level")

	// Clear all docking ports first
	for(var/obj/docking_port/stationary/dock as anything in reserve_docks)
		qdel(dock, TRUE)
	reserve_docks = null

	// Clear the entire virtual level
	planet_level.clear_reservation()

	// CRITICAL: Delete the virtual_level datum to free the space for reuse by SSmapping
	// Without this, the virtual level is never truly freed and cannot be reallocated
	qdel(planet_level)

	// Null out our reference
	planet_level = null

	log_world("PLANET UNLOAD: [name] cleanup complete - deleting planet object")
	///FOR TESTING ONLY
	src.star_system.generate_planets(1)
	// Delete the planet's supercruise object itself (like PentestSS13 does)
	// This removes it from the overmap and frees all references
	qdel(src)
