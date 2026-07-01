/**
 * # Orbital Shuttle
 *
 * A shuttle object in supercruise that can be controlled by the player.
 * Uses full 3D thrust vector control for movement in orbital space.
 * Inspired by Homeworld-style 3D movement.
 */
/datum/orbital_object/shuttle
	render_mode = "shuttle"
	radius = 5

	/// 3D thrust vector: normalized direction scaled by power (0-1)
	/// thrust_vector magnitude = thrust power fraction
	/// thrust_vector direction = thrust direction in 3D
	var/list/thrust_vector = list(0, 0, 0)

	/// Thrust power (0-100) for UI display convenience
	var/thrust_power = 0
	/// Thrust heading angle (0-360 degrees, horizontal plane) for UI display
	var/thrust_angle = 0
	/// Thrust pitch angle (-90 to 90 degrees, vertical) for UI display
	var/thrust_pitch = 0

	/// Ship facing heading (0-360 degrees, horizontal plane)
	/// Persists even when thrust is 0 — shows which way the nose points
	var/heading = 0
	/// Ship facing pitch (-90 to 90 degrees)
	/// Persists even when thrust is 0
	var/heading_pitch = 0

	/// Maximum speed in km/s
	var/max_speed = 50
	/// Acceleration rate (km/s per second)
	var/acceleration = 10
	/// Deceleration rate (km/s per second) - for active braking
	var/deceleration = 20
	/// Space drag coefficient (km/s per second) - set to 0 for true inertia
	/// Ships coast at constant speed when no thrust is applied (Newtonian physics)
	var/space_drag = 0

	/// Target position for autopilot (list: x, y, z)
	var/list/target_position = null
	/// Autopilot enabled
	var/autopilot_enabled = FALSE

	/// Position history for trail rendering (list of position lists)
	var/list/position_history = list()
	/// Maximum number of trail positions to track
	var/max_history = 40

	/// Distance at which to start slowing down (km)
	var/slowdown_distance = 100
	/// Minimum arrival distance (km)
	var/arrival_threshold = 5

	/// Reference to the actual shuttle docking port
	var/obj/docking_port/mobile/shuttle_port = null
	/// The station we're currently docked at (if any)
	var/datum/orbital_object/station/docked_at = null
	/// Are we currently in the process of docking?
	var/is_docking = FALSE
	/// The original stationary port where the shuttle was docked before entering supercruise
	var/obj/docking_port/stationary/original_dock = null

	/// Does this shuttle have a jump drive installed?
	var/has_jump_drive = TRUE
	/// Cooldown between jumps in seconds
	var/jump_cooldown = 60 SECONDS
	/// World time of the last jump
	var/last_jump_time = 0
	/// Is the shuttle currently jumping between systems?
	var/is_jumping = FALSE

	/// Toggle states for continuous rotation controls
	var/rotating_left = FALSE
	var/rotating_right = FALSE
	var/rotating_pitch_up = FALSE
	var/rotating_pitch_down = FALSE
	/// Rotation rate for continuous rotation (degrees per second)
	var/rotation_rate = 30

/datum/orbital_object/shuttle/process(seconds_per_tick)
	// Don't process movement if docked
	// Check both: docked at a station object OR not in transit dock
	var/obj/docking_port/stationary/current_dock = shuttle_port?.get_docked()
	var/is_in_transit = istype(current_dock, /obj/docking_port/stationary/transit)
	var/is_docked = (docked_at != null) || (current_dock && !is_in_transit)

	if(is_docked)
		// Reset all movement when docked
		set_velocity(0, 0, 0)
		thrust_vector = list(0, 0, 0)
		thrust_power = 0
		thrust_angle = 0
		thrust_pitch = 0
		autopilot_enabled = FALSE
		target_position = null
		return

	// Record position history for trail
	position_history += list(position.Copy())
	if(length(position_history) > max_history)
		position_history.Cut(1, 2)

	// Handle continuous rotation (only when not on autopilot)
	if(!autopilot_enabled)
		if(rotating_left)
			thrust_angle = MODULUS(thrust_angle + rotation_rate * seconds_per_tick, 360)
		if(rotating_right)
			thrust_angle = MODULUS(thrust_angle - rotation_rate * seconds_per_tick, 360)
		if(rotating_pitch_up)
			thrust_pitch = clamp(thrust_pitch + rotation_rate * seconds_per_tick, -90, 90)
		if(rotating_pitch_down)
			thrust_pitch = clamp(thrust_pitch - rotation_rate * seconds_per_tick, -90, 90)

		// Rebuild thrust vector if rotating (even if thrust_power = 0, for UI display)
		if(rotating_left || rotating_right || rotating_pitch_up || rotating_pitch_down)
			// Convert spherical coordinates to 3D direction vector
			var/horizontal_component = cos(thrust_pitch)
			var/tx = cos(thrust_angle) * horizontal_component
			var/ty = sin(thrust_angle) * horizontal_component
			var/tz = sin(thrust_pitch)
			var/mag = sqrt(tx*tx + ty*ty + tz*tz)
			if(mag > 0.001)
				thrust_vector = list(tx / mag, ty / mag, tz / mag)
			else
				thrust_vector = list(0, 0, 0)

	// Update heading when thrust is applied (or when rotating)
	if(thrust_power > 0 || rotating_left || rotating_right || rotating_pitch_up || rotating_pitch_down)
		// Update facing direction to match thrust direction
		heading = thrust_angle
		heading_pitch = thrust_pitch

	// Calculate target velocity based on control mode
	var/list/target_velocity = list(0, 0, 0)
	var/target_speed = 0

	// Handle autopilot to target position
	if(autopilot_enabled && target_position)
		thrust_vector = list(0, 0, 0) // Disable manual thrust while on autopilot
		thrust_power = 0
		stop_all_rotation() // Disable rotation while on autopilot

		var/target_x = target_position[1]
		var/target_y = target_position[2]
		var/target_z = target_position[3]

		// Calculate direction and distance to target (full 3D)
		var/dx = target_x - position[1]
		var/dy = target_y - position[2]
		var/dz = target_z - position[3]
		var/distance = sqrt(dx*dx + dy*dy + dz*dz)

		if(distance > arrival_threshold)
			// Normalize direction
			var/dir_x = dx / distance
			var/dir_y = dy / distance
			var/dir_z = dz / distance

			// Update heading to face the target
			heading = MODULUS(ATAN2(dir_y, dir_x), 360)
			var/horizontal_mag = sqrt(dir_x * dir_x + dir_y * dir_y)
			if(horizontal_mag > 0.001)
				heading_pitch = ATAN2(dir_z, horizontal_mag)
			else
				heading_pitch = dir_z > 0 ? 90 : -90

			// Calculate desired speed based on distance (slow down as we approach)
			if(distance > slowdown_distance)
				target_speed = max_speed
			else
				// Linear interpolation: speed decreases from max_speed to 0
				target_speed = max_speed * (distance / slowdown_distance)
				target_speed = max(target_speed, 5) // Minimum speed to avoid crawling

			// Set target velocity in the direction of target
			target_velocity[1] = dir_x * target_speed
			target_velocity[2] = dir_y * target_speed
			target_velocity[3] = dir_z * target_speed
		else
			// Arrived!
			autopilot_enabled = FALSE
			target_position = null

	// Handle manual 3D thrust vector control
	else if(thrust_power > 0)
		var/thrust_speed = (thrust_power / 100) * max_speed
		// thrust_vector is already a normalized direction * power fraction
		// Multiply by max_speed to get target velocity
		target_velocity[1] = thrust_vector[1] * max_speed
		target_velocity[2] = thrust_vector[2] * max_speed
		target_velocity[3] = thrust_vector[3] * max_speed
		target_speed = thrust_speed

	// No thrust and no autopilot - pure inertia (no target velocity change)
	// Ships maintain their current velocity indefinitely in space

	// Apply velocity changes only if we have a target velocity (thrust or autopilot)
	if(target_speed > 0 || (autopilot_enabled && target_position))
		// Smoothly adjust current velocity toward target velocity
		var/vel_diff_x = target_velocity[1] - velocity[1]
		var/vel_diff_y = target_velocity[2] - velocity[2]
		var/vel_diff_z = target_velocity[3] - velocity[3]
		var/vel_diff_mag = sqrt(vel_diff_x*vel_diff_x + vel_diff_y*vel_diff_y + vel_diff_z*vel_diff_z)

		if(vel_diff_mag > 0.1)
			// Determine if we're accelerating or decelerating
			var/current_speed = sqrt(velocity[1]*velocity[1] + velocity[2]*velocity[2] + velocity[3]*velocity[3])
			var/is_decelerating = (target_speed < current_speed) || (target_speed == 0)

			// Use appropriate rate
			var/change_rate = is_decelerating ? deceleration : acceleration
			var/max_change = change_rate * seconds_per_tick

			if(vel_diff_mag <= max_change)
				// Can reach target velocity this tick
				velocity[1] = target_velocity[1]
				velocity[2] = target_velocity[2]
				velocity[3] = target_velocity[3]
			else
				// Move toward target velocity at change_rate
				var/change_ratio = max_change / vel_diff_mag
				velocity[1] += vel_diff_x * change_ratio
				velocity[2] += vel_diff_y * change_ratio
				velocity[3] += vel_diff_z * change_ratio

	// Enforce speed limit
	var/current_speed = sqrt(velocity[1]*velocity[1] + velocity[2]*velocity[2] + velocity[3]*velocity[3])
	if(current_speed > max_speed && current_speed > 0)
		var/scale = max_speed / current_speed
		velocity[1] *= scale
		velocity[2] *= scale
		velocity[3] *= scale

	..()

/datum/orbital_object/shuttle/get_map_data()
	var/list/data = ..()
	data["priority"] = 10 // Shuttles render on top
	data["position_history"] = position_history.Copy()
	data["thrust_vector"] = thrust_vector.Copy()
	data["thrust_angle"] = thrust_angle
	data["thrust_pitch"] = thrust_pitch
	data["thrust_power"] = thrust_power
	data["heading"] = heading
	data["heading_pitch"] = heading_pitch
	data["max_speed"] = max_speed
	// Add separate position/velocity fields for tgui
	data["position_x"] = position[1]
	data["position_y"] = position[2]
	data["position_z"] = position[3]
	data["velocity_x"] = velocity[1]
	data["velocity_y"] = velocity[2]
	data["velocity_z"] = velocity[3]
	return data

/**
 * Set thrust using 3D vector (for full 3D control from UI)
 * tx, ty, tz - thrust direction components (will be normalized)
 * power - thrust power 0-100
 */
/datum/orbital_object/shuttle/proc/set_thrust_3d(tx, ty, tz, power)
	thrust_power = clamp(power, 0, 100)
	if(thrust_power == 0)
		thrust_vector = list(0, 0, 0)
		return

	// Normalize the direction
	var/mag = sqrt(tx*tx + ty*ty + tz*tz)
	if(mag < 0.001)
		thrust_vector = list(0, 0, 0)
		thrust_power = 0
		return

	tx /= mag
	ty /= mag
	tz /= mag

	thrust_vector = list(tx, ty, tz)

	// Update display angles and heading from direction
	thrust_angle = MODULUS(ATAN2(ty, tx), 360)
	heading = thrust_angle
	// Pitch: -90 (straight down) to 90 (straight up)
	var/horizontal_mag = sqrt(tx*tx + ty*ty)
	if(horizontal_mag < 0.001)
		thrust_pitch = tz > 0 ? 90 : -90
		heading_pitch = thrust_pitch
	else
		thrust_pitch = ATAN2(tz, horizontal_mag)
		heading_pitch = thrust_pitch

/**
 * Set thrust using heading angle and pitch (for 2D+ control from UI)
 * angle - horizontal heading (0-360 degrees)
 * pitch - vertical angle (-90 to 90)
 * power - thrust power 0-100
 */
/datum/orbital_object/shuttle/proc/set_thrust(angle, power, pitch)
	thrust_angle = MODULUS(angle, 360)
	if(thrust_angle < 0)
		thrust_angle += 360
	thrust_pitch = isnull(pitch) ? thrust_pitch : clamp(pitch, -90, 90)
	thrust_power = clamp(power, 0, 100)

	// Update heading to match thrust direction
	heading = thrust_angle
	heading_pitch = thrust_pitch

	if(thrust_power == 0)
		thrust_vector = list(0, 0, 0)
		return

	// Convert spherical coordinates to 3D direction vector
	var/horizontal_component = cos(thrust_pitch)
	var/tx = cos(thrust_angle) * horizontal_component
	var/ty = sin(thrust_angle) * horizontal_component
	var/tz = sin(thrust_pitch)

	// Normalize
	var/mag = sqrt(tx*tx + ty*ty + tz*tz)
	if(mag > 0.001)
		thrust_vector = list(tx / mag, ty / mag, tz / mag)
	else
		thrust_vector = list(0, 0, 0)

/**
 * Set thrust direction toward a target point in 3D space
 * power - thrust power 0-100
 */
/datum/orbital_object/shuttle/proc/set_thrust_toward(target_x, target_y, target_z, power)
	var/dx = target_x - position[1]
	var/dy = target_y - position[2]
	var/dz = target_z - position[3]
	var/mag = sqrt(dx*dx + dy*dy + dz*dz)
	if(mag < 0.001)
		return
	set_thrust_3d(dx / mag, dy / mag, dz / mag, power)

/**
 * Kill thrust and begin coasting (inertia — velocity is preserved, only thrust is removed)
 */
/datum/orbital_object/shuttle/proc/kill_thrust()
	thrust_vector = list(0, 0, 0)
	thrust_power = 0
	// heading and heading_pitch are preserved
	// velocity is preserved for inertia
	stop_all_rotation()

/**
 * Toggle continuous rotation left/right
 */
/datum/orbital_object/shuttle/proc/toggle_rotate_left(enable)
	rotating_left = enable

/datum/orbital_object/shuttle/proc/toggle_rotate_right(enable)
	rotating_right = enable

/**
 * Toggle continuous pitch up/down
 */
/datum/orbital_object/shuttle/proc/toggle_rotate_pitch_up(enable)
	rotating_pitch_up = enable

/datum/orbital_object/shuttle/proc/toggle_rotate_pitch_down(enable)
	rotating_pitch_down = enable

/**
 * Set all rotation toggles to off
 */
/datum/orbital_object/shuttle/proc/stop_all_rotation()
	rotating_left = FALSE
	rotating_right = FALSE
	rotating_pitch_up = FALSE
	rotating_pitch_down = FALSE

/**
 * Adjust altitude by adding vertical velocity impulse
 * dz - vertical velocity to add (positive = up, negative = down)
 */
/datum/orbital_object/shuttle/proc/adjust_altitude(dz)
	if(!dz)
		return null

	// Disallow altitude control while docked
	var/obj/docking_port/stationary/current_dock = shuttle_port?.get_docked()
	var/is_in_transit = istype(current_dock, /obj/docking_port/stationary/transit)
	var/is_docked = (docked_at != null) || (current_dock && !is_in_transit)
	if(is_docked)
		return "Cannot change altitude while docked"

	// Add vertical velocity impulse
	velocity[3] += dz
	return null

/**
 * Attempt to dock at a station
 * Modified to work with Pentest-style transit dock system.
 * Shuttles move from their assigned_transit dock to the station dock.
 */
/datum/orbital_object/shuttle/proc/dock_at_station(datum/orbital_object/station/target_station)
	if(!target_station)
		return "No target station specified"

	if(docked_at)
		return "Already docked at [docked_at.station_name]"

	if(is_docking)
		return "Already docking"

	// Check if we have a shuttle port
	if(!shuttle_port)
		return "Shuttle has no docking port"

	// Attempt to dock at the station
	var/dock_error = target_station.dock_shuttle(src)
	if(dock_error)
		return dock_error

	is_docking = TRUE

	// Stop all movement
	autopilot_enabled = FALSE
	target_position = null
	set_velocity(0, 0, 0)
	thrust_vector = list(0, 0, 0)
	thrust_power = 0

	var/obj/docking_port/stationary/target_dock = null

	if(original_dock)
		target_dock = original_dock
	// Otherwise, try to find a docking port from the station
	else if(length(target_station.docking_ports))
		for(var/obj/docking_port/stationary/port in target_station.docking_ports)
			target_dock = port
			break

	if(!target_dock)
		target_station.undock_shuttle(src)
		is_docking = FALSE
		return "No docking port available at station"

	// Move the shuttle from its transit dock back to the station
	var/docking_result = shuttle_port.initiate_docking(target_dock)
	if(docking_result != DOCKING_SUCCESS)
		target_station.undock_shuttle(src)
		is_docking = FALSE
		return "Failed to dock shuttle ([docking_result])"
	// Set docked status
	docked_at = target_station
	is_docking = FALSE

	return null // Success

/**
 * Undock from the current station (or launch into supercruise for the first time)
 * Shuttles get a persistent assigned_transit
 * that is reused every time they undock, instead of creating a new virtual level each time.
 */
/datum/orbital_object/shuttle/proc/undock_from_station()
	if(is_docking)
		return "Currently docking, please wait"

	if(!shuttle_port)
		return "Shuttle has no docking port"

	// If we're docked at a station object, undock from it
	if(docked_at)
		var/undock_error = docked_at.undock_shuttle(src)
		if(undock_error)
			return undock_error

	// Store the current dock location so we can return to it
	var/obj/docking_port/stationary/current_dock = shuttle_port.get_docked()
	if(!current_dock)
		if(docked_at)
			docked_at = null
		return "Error: Shuttle not physically docked"

	// Save this as the original dock if we don't have one yet
	if(!original_dock)
		original_dock = current_dock

	// If shuttle doesn't have an assigned transit dock yet, generate one
	if(!shuttle_port.assigned_transit)
		var/success = SSshuttle.generate_transit_dock(shuttle_port)
		if(!success)
			docked_at = null
			return "Error: Failed to generate transit dock"
	var/docking_result = shuttle_port.initiate_docking(shuttle_port.assigned_transit)
	if(docking_result != DOCKING_SUCCESS)
		// Don't clean up assigned_transit - it's persistent and should be reused
		docked_at = null
		stack_trace("Failed to move shuttle [shuttle_port.shuttle_id] to transit dock. Error code: [docking_result]")
		return "Error: Failed to move shuttle to transit ([docking_result])"

	docked_at = null

	return null

/**
 * Get nearby stations that are in docking range
 */
/datum/orbital_object/shuttle/proc/get_nearby_stations()
	var/list/nearby = list()
	if(!star_system)
		return nearby

	for(var/datum/orbital_object/station/station in star_system.get_stations())
		if(station.in_docking_range(src))
			nearby += station
	return nearby

/**
 * Get nearby objects that can be interacted with (generic version)
 * Returns all objects within interaction range in the same system (full 3D distance)
 */
/datum/orbital_object/shuttle/proc/get_nearby_objects(interaction_range = 30)
	var/list/nearby = list()
	if(!star_system)
		return nearby

	for(var/datum/orbital_object/obj in star_system.orbital_objects)
		if(obj == src)
			continue // Don't include ourselves
		var/dx = obj.position[1] - position[1]
		var/dy = obj.position[2] - position[2]
		var/dz = obj.position[3] - position[3]
		var/dist = sqrt(dx*dx + dy*dy + dz*dz)
		if(dist <= interaction_range)
			nearby += obj
	return nearby

/**
 * Initiate a jump to another star system
 * Returns null on success, error message string on failure
 */
/datum/orbital_object/shuttle/proc/jump_to_system(system_id, mob/user)
	// Check if we have a jump drive
	if(!has_jump_drive)
		return "This shuttle does not have a jump drive installed"

	// Check if we're currently jumping
	if(is_jumping)
		return "Jump drive is already charging"

	// Check if docked
	if(docked_at || is_docking)
		return "Cannot jump while docked - undock first"

	// Check cooldown
	var/time_since_jump = (world.time - last_jump_time)
	if(time_since_jump < jump_cooldown)
		var/remaining = jump_cooldown - time_since_jump
		return "Jump drive is cooling down - [round(remaining)] seconds remaining"

	// Check if we're in a system
	if(!star_system)
		return "Error: Shuttle is not in a star system"

	// Get target system
	var/datum/overmap_star_system/target_system = SSsupercruise.get_system(system_id)
	if(!target_system)
		return "Error: Target system not found"

	// Don't allow jumping to the same system
	if(target_system == star_system)
		return "Already in target system"

	// Start jump sequence
	is_jumping = TRUE

	// Announce jump
	if(user)
		to_chat(user, span_notice("Initiating jump to [target_system.system_name]..."))

	// Execute jump using SSsupercruise (preserve Z position)
	var/jump_result = SSsupercruise.move_to_system(src, target_system, position[1], position[2], position[3])

	if(!jump_result)
		is_jumping = FALSE
		return "Error: Failed to execute jump"

	// Update jump time and status
	last_jump_time = world.time
	is_jumping = FALSE

	if(user)
		to_chat(user, span_notice("Jump complete! Now in [target_system.system_name]."))

	return null // Success

/**
 * Get available jump destinations from current system
 */
/datum/orbital_object/shuttle/proc/get_jump_destinations()
	if(!star_system)
		return list()

	var/list/destinations = list()
	// Get all systems that allow jumping (except the current system)
	for(var/system_id in SSsupercruise.star_systems)
		var/datum/overmap_star_system/system = SSsupercruise.star_systems[system_id]
		// Don't show current system or systems that can't be jumped to
		if(system == star_system || !system.can_jump)
			continue
		destinations += list(list(
			"id" = system.system_id,
			"name" = system.system_name,
			"description" = system.system_description
		))

	return destinations
