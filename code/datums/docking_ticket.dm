/**
 * Docking Ticket Datum
 *
 * Tracks the state and authorization of a docking operation.
 */
/datum/docking_ticket
	/// The stationary docking port we're trying to dock at
	var/obj/docking_port/stationary/target_port
	/// The target orbital object (station, ship, etc.) we're docking to
	var/datum/orbital_object/target
	/// The orbital object (shuttle) that issued this ticket
	var/datum/orbital_object/shuttle/issuer
	/// Error code if docking failed validation
	var/docking_error

/datum/docking_ticket/New(_target_port, _target, _issuer, _docking_error)
	. = ..()
	target_port = _target_port
	target = _target
	issuer = _issuer
	if(_docking_error)
		docking_error = _docking_error

	// Reserve the port if no error and port exists
	if(!docking_error && target_port)
		if(target_port.current_docking_ticket)
			docking_error = "[target_port] is already reserved for docking!"
		else
			target_port.current_docking_ticket = src

/datum/docking_ticket/Destroy(force)
	// Release port reservation
	if(target_port)
		target_port.current_docking_ticket = null
		target_port = null
	if(issuer)
		issuer = null
	if(target)
		target = null
	return ..()

/**
 * Check if this ticket is still valid
 * Returns TRUE if valid, FALSE if expired or invalidated
 */
/datum/docking_ticket/proc/is_valid()
	// Check if target port still exists
	if(QDELETED(target_port))
		return FALSE

	// Check if issuer still exists
	if(QDELETED(issuer))
		return FALSE

	// Check if there's a docking error
	if(docking_error)
		return FALSE

	return TRUE

/datum/docking_ticket/proc/get_status_message()
	if(!is_valid())
		if(docking_error)
			return "Docking denied: [docking_error]"
		if(QDELETED(target_port))
			return "Docking denied: Target port no longer exists"
		if(QDELETED(issuer))
			return "Docking denied: Issuer no longer exists"
		return "Docking denied: Unknown error"

	return "Docking authorized"

/datum/docking_ticket/proc/invalidate(error_message)
	docking_error = error_message
