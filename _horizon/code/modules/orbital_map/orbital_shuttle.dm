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
	/// thrust_x/y/z magnitude = thrust power fraction
	/// thrust_x/y/z direction = thrust direction in 3D
	var/thrust_x = 0
	var/thrust_y = 0
	var/thrust_z = 0

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

	/// Pending autopilot target coordinates (set by right-click, requires confirmation)
	var/pending_target_x = 0
	var/pending_target_y = 0
	var/pending_target_z = 0
	var/has_pending_target = FALSE
	/// Confirmed autopilot target coordinates (x, y, z) — engaged after confirmation
	var/target_pos_x = 0
	var/target_pos_y = 0
	var/target_pos_z = 0
	var/has_target_position = FALSE
	/// Autopilot enabled (confirmed and flying)
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

	/// Оффсет позиции относительно станции/планеты при стыковке (чтобы двигаться вместе с ними)
	var/docked_offset_x = 0
	var/docked_offset_y = 0
	var/docked_offset_z = 0

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

	/// Маневровые двигатели (RCS) - мощность (0-10)
	var/rcs_power = 0
	/// Вектор стрейфа
	var/rcs_strafe_x = 0
	var/rcs_strafe_y = 0
	var/rcs_strafe_z = 0

/datum/orbital_object/shuttle/process(seconds_per_tick)
	// Don't process movement if docked
	var/obj/docking_port/stationary/current_dock = shuttle_port?.get_docked()
	var/is_in_transit = istype(current_dock, /obj/docking_port/stationary/transit)
	var/is_docked = (docked_at != null) || (current_dock && !is_in_transit)

	if(is_docked)
		set_velocity(0, 0, 0)
		thrust_x = 0
		thrust_y = 0
		thrust_z = 0
		thrust_power = 0
		thrust_angle = 0
		thrust_pitch = 0
		autopilot_enabled = FALSE
		has_target_position = FALSE
		has_pending_target = FALSE
		rcs_power = 0
		rcs_strafe_x = 0
		rcs_strafe_y = 0
		rcs_strafe_z = 0
		return

	// Record position history for trail
	position_history += list(pos_x, pos_y, pos_z)
	if(length(position_history) > max_history)
		position_history.Cut(1, 4)

	// === Handle continuous rotation (manual only, skip if autopilot is on) ===
	if(!autopilot_enabled)
		var/is_rotating = FALSE
		if(rotating_left)
			thrust_angle = MODULUS(thrust_angle + rotation_rate * seconds_per_tick, 360)
			is_rotating = TRUE
		if(rotating_right)
			thrust_angle = MODULUS(thrust_angle - rotation_rate * seconds_per_tick, 360)
			is_rotating = TRUE
		if(rotating_pitch_up)
			thrust_pitch += rotation_rate * seconds_per_tick
			is_rotating = TRUE
		if(rotating_pitch_down)
			thrust_pitch -= rotation_rate * seconds_per_tick
			is_rotating = TRUE
		if(thrust_pitch > 90)
			thrust_pitch = 180 - thrust_pitch
			thrust_angle = MODULUS(thrust_angle + 180, 360)
		else if(thrust_pitch < -90)
			thrust_pitch = -180 - thrust_pitch
			thrust_angle = MODULUS(thrust_angle + 180, 360)

		// Пересчитываем вектор тяги, даже если thrust_power = 0, чтобы компас вращался
		if(is_rotating)
			var/horizontal_component = cos(thrust_pitch)
			var/tx = cos(thrust_angle) * horizontal_component
			var/ty = sin(thrust_angle) * horizontal_component
			var/tz = sin(thrust_pitch)
			var/mag = sqrt(tx*tx + ty*ty + tz*tz)
			if(mag > 0.001)
				thrust_x = tx / mag
				thrust_y = ty / mag
				thrust_z = tz / mag
			else
				thrust_x = 0
				thrust_y = 0
				thrust_z = 0

			// Обновляем направление носа корабля
			heading = thrust_angle
			heading_pitch = thrust_pitch

	// === Determine thrust direction and power ===
	var/thrust_dir_x = 0
	var/thrust_dir_y = 0
	var/thrust_dir_z = 0
	var/effective_thrust_power = 0

	// Handle autopilot to target position
	if(autopilot_enabled && has_target_position)
		var/target_x = target_pos_x
		var/target_y = target_pos_y
		var/target_z = target_pos_z

		var/dx = target_x - pos_x
		var/dy = target_y - pos_y
		var/dz = target_z - pos_z
		var/distance = sqrt(dx*dx + dy*dy + dz*dz)

		if(distance > arrival_threshold)
			var/dir_x = dx / distance
			var/dir_y = dy / distance
			var/dir_z = dz / distance

			var/desired_speed = max_speed
			if(distance < slowdown_distance)
				desired_speed = max_speed * (distance / slowdown_distance)
				desired_speed = max(desired_speed, 2)

			var/current_speed = sqrt(vel_x*vel_x + vel_y*vel_y + vel_z*vel_z)
			var/dot_vel_dir = vel_x*dir_x + vel_y*dir_y + vel_z*dir_z

			if(dot_vel_dir >= 0 && current_speed > desired_speed)
				if(current_speed > 0.01)
					thrust_dir_x = -vel_x/current_speed
					thrust_dir_y = -vel_y/current_speed
					thrust_dir_z = -vel_z/current_speed
				effective_thrust_power = 100
			else
				thrust_dir_x = dir_x
				thrust_dir_y = dir_y
				thrust_dir_z = dir_z
				var/speed_diff = desired_speed - dot_vel_dir
				effective_thrust_power = clamp(speed_diff / max_speed * 100, 10, 100)
			var/horiz_mag = sqrt(thrust_dir_x*thrust_dir_x + thrust_dir_y*thrust_dir_y)
			if(horiz_mag > 0.001)
				heading = MODULUS(ATAN2(thrust_dir_x, thrust_dir_y), 360)
				heading_pitch = ATAN2(horiz_mag, thrust_dir_z)
			else
				heading = 0
				heading_pitch = thrust_dir_z > 0 ? 90 : -90

			thrust_x = thrust_dir_x
			thrust_y = thrust_dir_y
			thrust_z = thrust_dir_z
			thrust_power = effective_thrust_power
			thrust_angle = heading
			thrust_pitch = heading_pitch
		else
			autopilot_enabled = FALSE
			has_target_position = FALSE

	// Handle manual thrust (срабатывает, если автопилот выключен)
	else if(thrust_power > 0)
		thrust_dir_x = thrust_x
		thrust_dir_y = thrust_y
		thrust_dir_z = thrust_z
		effective_thrust_power = thrust_power
		// Если мы даём ручную тягу, нос смотрит туда же (только если не вращаемся кнопками,
		// чтобы не перетирать heading, который уже обновлён в блоке вращения выше)
		if(!rotating_left && !rotating_right && !rotating_pitch_up && !rotating_pitch_down)
			heading = thrust_angle
			heading_pitch = thrust_pitch

	// === Применение тяги RCS (стрейф) ===
	if(rcs_power > 0)
		// Лкальные векторы ориентации корабля
		var/cos_pitch = cos(thrust_pitch)
		var/sin_pitch = sin(thrust_pitch)
		var/cos_yaw = cos(thrust_angle)
		var/sin_yaw = sin(thrust_angle)
		// Локальный "вперед" (Z)
		var/fwd_x = cos_yaw * cos_pitch
		var/fwd_y = sin_yaw * cos_pitch
		var/fwd_z = sin_pitch
		// Локальный "вправо" (X)
		var/loc_x = sin_yaw * cos_pitch
		var/loc_y = -cos_yaw * cos_pitch
		// Складываем векторы с учетом нажатых кнопок стрейфа
		var/target_vx = (loc_x * rcs_strafe_x) + (fwd_x * rcs_strafe_z)
		var/target_vy = (loc_y * rcs_strafe_x) + (fwd_y * rcs_strafe_z)
		var/target_vz = rcs_strafe_y + (fwd_z * rcs_strafe_z)
		var/mag = sqrt(target_vx*target_vx + target_vy*target_vy + target_vz*target_vz)
		if(mag > 0.001)
			var/rcs_accel = (rcs_power / 100) * acceleration * 0.5 // RCS в 2 раза слабее главных двигателей
			vel_x += (target_vx / mag) * rcs_accel * seconds_per_tick
			vel_y += (target_vy / mag) * rcs_accel * seconds_per_tick
			vel_z += (target_vz / mag) * rcs_accel * seconds_per_tick

	// === Apply acceleration ===
	if(effective_thrust_power > 0)
		var/dir_mag = sqrt(thrust_dir_x*thrust_dir_x + thrust_dir_y*thrust_dir_y + thrust_dir_z*thrust_dir_z)
		if(dir_mag > 0.001)
			thrust_dir_x /= dir_mag
			thrust_dir_y /= dir_mag
			thrust_dir_z /= dir_mag

		var/effective_accel = (effective_thrust_power / 100) * acceleration
		var/dv_x = thrust_dir_x * effective_accel * seconds_per_tick
		var/dv_y = thrust_dir_y * effective_accel * seconds_per_tick
		var/dv_z = thrust_dir_z * effective_accel * seconds_per_tick

		vel_x += dv_x
		vel_y += dv_y
		vel_z += dv_z
	else
		var/current_speed = sqrt(vel_x*vel_x + vel_y*vel_y + vel_z*vel_z)
		if(current_speed > 0.01)
			var/drag = space_drag * seconds_per_tick
			if(drag >= current_speed)
				vel_x = 0
				vel_y = 0
				vel_z = 0
			else
				var/drag_ratio = 1 - (drag / current_speed)
				vel_x *= drag_ratio
				vel_y *= drag_ratio
				vel_z *= drag_ratio

	// ГРАВИТАЦИЯ ЗВЕЗДЫ
	if(star_system && star_system.central_star)
		var/datum/orbital_object/star/S = star_system.central_star
		var/dx = S.pos_x - pos_x
		var/dy = S.pos_y - pos_y
		var/dz = S.pos_z - pos_z
		var/dist_sq = dx*dx + dy*dy + dz*dz
		var/dist = sqrt(dist_sq)

		// S.gravity_mass = масса звезды (сейчас 5000 в orbital_star.dm)
		// Можно изменить делитель (1000) ниже, чтобы сделать гравитацию слабее/сильнее.
		if(dist > 0.01 && dist < 1000) // Гравитация работает только в радиусе 1000 км
			var/pull_strength = (S.gravity_mass / max(dist_sq, 1)) / 1000
			vel_x += (dx / dist) * pull_strength * seconds_per_tick
			vel_y += (dy / dist) * pull_strength * seconds_per_tick
			vel_z += (dz / dist) * pull_strength * seconds_per_tick

	// Enforce speed limit
	var/current_speed = sqrt(vel_x*vel_x + vel_y*vel_y + vel_z*vel_z)
	if(current_speed > max_speed && current_speed > 0)
		var/scale = max_speed / current_speed
		vel_x *= scale
		vel_y *= scale
		vel_z *= scale

	..()

/datum/orbital_object/shuttle/get_map_data()
	var/list/data = ..()
	data["priority"] = 10
	data["position_history"] = position_history
	data["thrust_x"] = thrust_x
	data["thrust_y"] = thrust_y
	data["thrust_z"] = thrust_z
	data["thrust_angle"] = thrust_angle
	data["thrust_pitch"] = thrust_pitch
	data["thrust_power"] = thrust_power
	data["heading"] = heading
	data["heading_pitch"] = heading_pitch
	data["max_speed"] = max_speed
	data["autopilot_enabled"] = autopilot_enabled
	if(has_pending_target)
		data["pendingTargetX"] = pending_target_x
		data["pendingTargetY"] = pending_target_y
		data["pendingTargetZ"] = pending_target_z
		data["hasPendingTarget"] = TRUE
	else
		data["hasPendingTarget"] = FALSE
	return data

/**
 * Set thrust using 3D vector (for full 3D control from UI)
 * tx, ty, tz - thrust direction components (will be normalized)
 * power - thrust power 0-100
 */
/datum/orbital_object/shuttle/proc/set_thrust_3d(tx, ty, tz, power)
	thrust_power = clamp(power, 0, 100)
	if(thrust_power == 0)
		thrust_x = 0
		thrust_y = 0
		thrust_z = 0
		return

		// Normalize the direction
		var/mag = sqrt(tx*tx + ty*ty + tz*tz)
		if(mag < 0.001)
			thrust_x = 0
			thrust_y = 0
			thrust_z = 0
			thrust_power = 0
			return

		tx /= mag
		ty /= mag
		tz /= mag

		thrust_x = tx
		thrust_y = ty
		thrust_z = tz
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
		thrust_x = 0
		thrust_y = 0
		thrust_z = 0
		return

	// Convert spherical coordinates to 3D direction vector
	var/horizontal_component = cos(thrust_pitch)
	var/tx = cos(thrust_angle) * horizontal_component
	var/ty = sin(thrust_angle) * horizontal_component
	var/tz = sin(thrust_pitch)

	// Normalize
	var/mag = sqrt(tx*tx + ty*ty + tz*tz)
	if(mag > 0.001)
		thrust_x = tx / mag
		thrust_y = ty / mag
		thrust_z = tz / mag
	else
		thrust_x = 0
		thrust_y = 0
		thrust_z = 0

/**
 * Set thrust direction toward a target point in 3D space
 * power - thrust power 0-100
 */
/datum/orbital_object/shuttle/proc/set_thrust_toward(target_x, target_y, target_z, power)
	var/dx = target_x - pos_x
	var/dy = target_y - pos_y
	var/dz = target_z - pos_z
	var/mag = sqrt(dx*dx + dy*dy + dz*dz)
	if(mag < 0.001)
		return
	set_thrust_3d(dx / mag, dy / mag, dz / mag, power)

/**
 * Kill thrust and begin coasting (inertia — velocity is preserved, only thrust is removed)
 */
/datum/orbital_object/shuttle/proc/kill_thrust()
	thrust_x = 0
	thrust_y = 0
	thrust_z = 0
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
	vel_z += dz
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
	has_target_position = FALSE
	set_velocity(0, 0, 0)
	thrust_x = 0
	thrust_y = 0
	thrust_z = 0
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

	// Сохраняем оффсет
	docked_offset_x = pos_x - target_station.pos_x
	docked_offset_y = pos_y - target_station.pos_y
	docked_offset_z = pos_z - target_station.pos_z

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
		var/new_pos_x = docked_at.pos_x + docked_offset_x
		var/new_pos_y = docked_at.pos_y + docked_offset_y
		var/new_pos_z = docked_at.pos_z + docked_offset_z

		var/undock_error = docked_at.undock_shuttle(src)
		if(undock_error)
			return undock_error

		pos_x = new_pos_x
		pos_y = new_pos_y
		pos_z = new_pos_z

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
		var/dx = obj.pos_x - pos_x
		var/dy = obj.pos_y - pos_y
		var/dz = obj.pos_z - pos_z
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
	var/jump_result = SSsupercruise.move_to_system(src, target_system, pos_x, pos_y, pos_z)

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
