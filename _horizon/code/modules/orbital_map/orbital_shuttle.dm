/**
 * # Orbital Shuttle
 */
/datum/orbital_object/shuttle
	render_mode = "shuttle"
	radius = 5
	velocity_multiplier = 3

	var/max_speed = 50
	var/heading = 0
	var/heading_pitch = 0
	var/acceleration = 10
	var/space_drag = 0

	var/datum/orbital_vector/thrust = new()
	var/thrust_power = 0
	var/thrust_angle = 0
	var/thrust_pitch = 0

	var/datum/orbital_vector/pending_target = new()
	var/has_pending_target = FALSE

	var/datum/orbital_vector/target_pos = new()
	var/has_target_position = FALSE
	var/autopilot_enabled = FALSE
	var/autopilot_mode = 0
	var/target_object_id = null
	var/target_orbit_radius = 0

	var/datum/orbital_vector/rcs_strafe = new()
	var/rcs_power = 0

	var/datum/orbital_vector/docked_offset = new()
	var/obj/docking_port/mobile/shuttle_port = null
	var/datum/orbital_object/station/docked_at = null
	var/obj/docking_port/stationary/original_dock = null
	var/is_docking = FALSE

	var/list/position_history = list()
	var/max_history = 40

	var/slowdown_distance = 100
	var/arrival_threshold = 5

	var/has_jump_drive = TRUE
	var/jump_cooldown = 60 SECONDS
	var/last_jump_time = 0
	var/is_jumping = FALSE

	var/rotating_left = FALSE
	var/rotating_right = FALSE
	var/rotating_pitch_up = FALSE
	var/rotating_pitch_down = FALSE
	var/rotation_rate = 30

/datum/orbital_object/shuttle/process(seconds_per_tick)
	var/obj/docking_port/stationary/current_dock = shuttle_port?.get_docked()
	var/is_in_transit = istype(current_dock, /obj/docking_port/stationary/transit)
	var/is_docked = (docked_at != null) || (current_dock && !is_in_transit)

	if(is_docked)
		velocity.Set(0, 0, 0)
		thrust.Set(0, 0, 0)
		thrust_power = 0
		autopilot_enabled = FALSE
		has_target_position = FALSE
		has_pending_target = FALSE
		rcs_power = 0
		return

	// Record position history for trail
	position_history += list(position.x, position.y, position.z)
	if(length(position_history) > max_history)
		position_history.Cut(1, 4)

	// --- РУЧНОЕ УПРАВЛЕНИЕ ---
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

		if(is_rotating)
			var/horizontal_component = cos(thrust_pitch)
			var/tx = cos(thrust_angle) * horizontal_component
			var/ty = sin(thrust_angle) * horizontal_component
			var/tz = sin(thrust_pitch)
			var/mag = sqrt(tx*tx + ty*ty + tz*tz)
			if(mag > 0.001)
				thrust.Set(tx / mag, ty / mag, tz / mag)

			heading = thrust_angle
			heading_pitch = thrust_pitch

	// --- AUTOPILOT (SAS) ---
	if(autopilot_mode > 0)
		handle_autopilot(seconds_per_tick)
	else if(thrust_power > 0)
		heading = thrust_angle
		heading_pitch = thrust_pitch

	// --- THRUST ---
	if(thrust_power > 0)
		var/dir_mag = thrust.Length()
		if(dir_mag > 0.001)
			var/datum/orbital_vector/norm_thrust = thrust.GetNormalized()
			var/effective_accel = (thrust_power / 100) * acceleration
			velocity.AddSelf(norm_thrust.ScaleSelf(effective_accel * seconds_per_tick))

	// --- RCS ---
	if(rcs_power > 0)
		var/cos_pitch = cos(thrust_pitch)
		var/sin_pitch = sin(thrust_pitch)
		var/cos_yaw = cos(thrust_angle)
		var/sin_yaw = sin(thrust_angle)

		var/fwd_x = cos_yaw * cos_pitch
		var/fwd_y = sin_yaw * cos_pitch
		var/fwd_z = sin_pitch
		var/loc_x = sin_yaw * cos_pitch
		var/loc_y = -cos_yaw * cos_pitch

		var/target_vx = (loc_x * rcs_strafe.x) + (fwd_x * rcs_strafe.z)
		var/target_vy = (loc_y * rcs_strafe.x) + (fwd_y * rcs_strafe.z)
		var/target_vz = rcs_strafe.y + (fwd_z * rcs_strafe.z)

		var/datum/orbital_vector/target_v = new(target_vx, target_vy, target_vz)
		var/mag = target_v.Length()

		if(mag > 0.001)
			var/datum/orbital_vector/norm_rcs = target_v.GetNormalized()
			var/rcs_accel = (rcs_power / 100) * acceleration * 0.5
			velocity.AddSelf(norm_rcs.ScaleSelf(rcs_accel * seconds_per_tick))

	// --- КОЛЛИЗИИ И ГРАВИТАЦИЯ ---
	. = ..(seconds_per_tick)

	// Ограничение максимальной скорости
	var/current_speed = velocity.Length()
	if(current_speed > max_speed && current_speed > 0)
		velocity.ScaleSelf(max_speed / current_speed)

	check_collisions()

/**
 * Полностью векторный автопилот. Без арктангенсов и спагетти.
 */
/datum/orbital_object/shuttle/proc/handle_autopilot(seconds_per_tick)
	var/datum/orbital_object/target = null
	if(target_object_id)
		target = SSsupercruise.find_object(target_object_id, star_system)
		if(!target)
			autopilot_mode = 0
			target_object_id = null
			return

	if(!target && !(autopilot_mode == 1 && has_target_position))
		autopilot_mode = 0
		return

	// Получаем вектор до цели
	var/datum/orbital_vector/t_pos = target ? target.position : target_pos
	var/datum/orbital_vector/delta = t_pos.Subtract(position)
	var/distance = delta.Length()

	if(autopilot_mode == 1) // TRAVEL TO
		if(distance < arrival_threshold)
			autopilot_mode = 3 // Переходим в режим удержания
			target_orbit_radius = max((target ? target.radius : 50) + 20, 50)
			return

		var/desired_speed = clamp(distance * 0.5, 0, max_speed)
		var/datum/orbital_vector/norm_delta = delta.GetNormalized()

		// Добавляем скорость цели, чтобы догонять движущиеся станции/планеты
		var/datum/orbital_vector/target_vel = target ? target.velocity : new()
		var/datum/orbital_vector/desired_velocity = norm_delta.Scale(desired_speed)
		desired_velocity.AddSelf(target_vel)

		// Вектор разницы (куда нужно толкать корабль)
		var/datum/orbital_vector/steer = desired_velocity.Subtract(velocity)
		var/steer_mag = steer.Length()

		if(steer_mag > 0.5)
			var/datum/orbital_vector/norm_steer = steer.GetNormalized()
			set_thrust_3d(norm_steer.x, norm_steer.y, norm_steer.z, 100)
		else
			kill_thrust()

	else if(autopilot_mode == 3) // HOLD POSITION
		var/datum/orbital_vector/norm_delta = delta.GetNormalized()

		// Точка, которую мы хотим занять
		var/datum/orbital_vector/desired_pos = t_pos.Subtract(norm_delta.Scale(target_orbit_radius))
		var/datum/orbital_vector/error = desired_pos.Subtract(position)
		var/err_mag = error.Length()

		// Убиваем скорость относительно цели
		var/datum/orbital_vector/target_vel = target ? target.velocity : new()
		var/datum/orbital_vector/rvel = velocity.Subtract(target_vel)
		var/rvel_mag = rvel.Length()

		if(rvel_mag > 2)
			var/datum/orbital_vector/norm_rvel = rvel.GetNormalized()
			set_thrust_3d(-norm_rvel.x, -norm_rvel.y, -norm_rvel.z, 50)
		else if(err_mag > 5)
			var/datum/orbital_vector/norm_err = error.GetNormalized()
			set_thrust_3d(norm_err.x, norm_err.y, norm_err.z, 30)
		else
			kill_thrust()

/datum/orbital_object/shuttle/check_collisions()
	if(!star_system)
		return

	var/list/nearby_objects = star_system.get_nearby_objects_for_collision(src)

	for(var/datum/orbital_object/obj in nearby_objects)
		if(obj == src || !obj.mass)
			continue

		var/datum/orbital_vector/delta = obj.position.Subtract(position)
		var/dist_sq = delta.Dot(delta)

		if(istype(obj, /datum/orbital_object/planet))
			var/datum/orbital_object/planet/P = obj
			var/coll_radius = P.radius + 5
			if(dist_sq < coll_radius * coll_radius)
				if(P.emergency_dock(src))
					return

				var/dist = sqrt(dist_sq)
				if(dist > 0.01)
					var/datum/orbital_vector/norm = delta.ScaleSelf(-1 / dist)
					position.Set(P.position.x + norm.x * coll_radius, P.position.y + norm.y * coll_radius, P.position.z + norm.z * coll_radius)

					var/vdotn = velocity.Dot(norm)
					if(vdotn < 0)
						velocity.AddSelf(norm.ScaleSelf(-vdotn))

		else if(istype(obj, /datum/orbital_object/star))
			var/datum/orbital_object/star/S = obj
			var/coll_radius = S.collision_radius || S.radius
			if(dist_sq < coll_radius * coll_radius)
				velocity.ScaleSelf(-0.8)

/datum/orbital_object/shuttle/Destroy()
	QDEL_NULL(position)
	QDEL_NULL(velocity)
	QDEL_NULL(thrust)
	QDEL_NULL(pending_target)
	QDEL_NULL(target_pos)
	QDEL_NULL(rcs_strafe)
	QDEL_NULL(docked_offset)
	return ..()

/datum/orbital_object/shuttle/get_map_data()
	var/list/data = ..()
	data["priority"] = 10
	data["position_history"] = position_history
	data["thrust_x"] = thrust.x
	data["thrust_y"] = thrust.y
	data["thrust_z"] = thrust.z
	data["thrust_angle"] = thrust_angle
	data["thrust_pitch"] = thrust_pitch
	data["thrust_power"] = thrust_power
	data["heading"] = heading
	data["heading_pitch"] = heading_pitch
	data["max_speed"] = max_speed
	data["autopilot_enabled"] = autopilot_enabled
	if(has_pending_target)
		data["pendingTargetX"] = pending_target.x
		data["pendingTargetY"] = pending_target.y
		data["pendingTargetZ"] = pending_target.z
		data["hasPendingTarget"] = TRUE
	else
		data["hasPendingTarget"] = FALSE
	return data

/datum/orbital_object/shuttle/proc/set_thrust_3d(tx, ty, tz, power)
	thrust_power = clamp(power, 0, 100)
	if(thrust_power == 0)
		thrust.Set(0, 0, 0)
		return

	var/mag = sqrt(tx*tx + ty*ty + tz*tz)
	if(mag < 0.001)
		thrust.Set(0, 0, 0)
		thrust_power = 0
		return

	thrust.Set(tx / mag, ty / mag, tz / mag)
	heading = thrust_angle

	var/horizontal_mag = sqrt(tx*tx + ty*ty)
	if(horizontal_mag < 0.001)
		thrust_pitch = tz > 0 ? 90 : -90
		heading_pitch = thrust_pitch
	else
		thrust_pitch = ATAN2(tz, horizontal_mag)
		heading_pitch = thrust_pitch

/datum/orbital_object/shuttle/proc/set_thrust(angle, power, pitch)
	thrust_angle = MODULUS(angle, 360)
	if(thrust_angle < 0)
		thrust_angle += 360
	thrust_pitch = isnull(pitch) ? thrust_pitch : clamp(pitch, -90, 90)
	thrust_power = clamp(power, 0, 100)

	heading = thrust_angle
	heading_pitch = thrust_pitch

	if(thrust_power == 0)
		thrust.Set(0, 0, 0)
		return

	var/horizontal_component = cos(thrust_pitch)
	var/tx = cos(thrust_angle) * horizontal_component
	var/ty = sin(thrust_angle) * horizontal_component
	var/tz = sin(thrust_pitch)

	var/mag = sqrt(tx*tx + ty*ty + tz*tz)
	if(mag > 0.001)
		thrust.Set(tx / mag, ty / mag, tz / mag)
	else
		thrust.Set(0, 0, 0)

/datum/orbital_object/shuttle/proc/set_thrust_toward(target_x, target_y, target_z, power)
	var/datum/orbital_vector/delta = new(target_x - position.x, target_y - position.y, target_z - position.z)
	var/mag = delta.Length()
	if(mag < 0.001)
		return
	set_thrust_3d(delta.x / mag, delta.y / mag, delta.z / mag, power)

/datum/orbital_object/shuttle/proc/kill_thrust()
	thrust.Set(0, 0, 0)
	thrust_power = 0
	rcs_power = 0
	rcs_strafe.Set(0, 0, 0)
	stop_all_rotation()
	autopilot_mode = 0
	target_object_id = null

/datum/orbital_object/shuttle/proc/toggle_rotate_left(enable)
	rotating_left = enable

/datum/orbital_object/shuttle/proc/toggle_rotate_right(enable)
	rotating_right = enable

/datum/orbital_object/shuttle/proc/toggle_rotate_pitch_up(enable)
	rotating_pitch_up = enable

/datum/orbital_object/shuttle/proc/toggle_rotate_pitch_down(enable)
	rotating_pitch_down = enable

/datum/orbital_object/shuttle/proc/stop_all_rotation()
	rotating_left = FALSE
	rotating_right = FALSE
	rotating_pitch_up = FALSE
	rotating_pitch_down = FALSE

/datum/orbital_object/shuttle/proc/adjust_altitude(dz)
	if(!dz)
		return null

	var/obj/docking_port/stationary/current_dock = shuttle_port?.get_docked()
	var/is_in_transit = istype(current_dock, /obj/docking_port/stationary/transit)
	var/is_docked = (docked_at != null) || (current_dock && !is_in_transit)
	if(is_docked)
		return "Cannot change altitude while docked"

	velocity.z += dz
	return null

/datum/orbital_object/shuttle/proc/dock_at_station(datum/orbital_object/station/target_station)
	if(!target_station)
		return "No target station specified"
	if(docked_at)
		return "Already docked at [docked_at.name]"
	if(is_docking)
		return "Already docking"
	if(!shuttle_port)
		return "Shuttle has no docking port"

	var/dock_error = target_station.dock_shuttle(src)
	if(dock_error)
		return dock_error

	is_docking = TRUE
	autopilot_enabled = FALSE
	has_target_position = FALSE
	velocity.Set(0, 0, 0)
	kill_thrust()

	var/obj/docking_port/stationary/target_dock = null
	if(original_dock)
		target_dock = original_dock
	else if(length(target_station.docking_ports))
		for(var/obj/docking_port/stationary/port in target_station.docking_ports)
			target_dock = port
			break

	if(!target_dock)
		target_station.undock_shuttle(src)
		is_docking = FALSE
		return "No docking port available at station"

	var/docking_result = shuttle_port.initiate_docking(target_dock)
	if(docking_result != DOCKING_SUCCESS)
		target_station.undock_shuttle(src)
		is_docking = FALSE
		return "Failed to dock shuttle ([docking_result])"

	docked_at = target_station
	is_docking = FALSE
	var/datum/orbital_vector/new_offset = position.Subtract(target_station.position)
	docked_offset.Set(new_offset.x, new_offset.y, new_offset.z)
	return null

/datum/orbital_object/shuttle/proc/undock_from_station()
	if(is_docking)
		return "Currently docking, please wait"
	if(!shuttle_port)
		return "Shuttle has no docking port"

	if(docked_at)
		var/datum/orbital_vector/new_pos = docked_at.position.Add(docked_offset)
		var/undock_error = docked_at.undock_shuttle(src)
		if(undock_error)
			return undock_error
		position.Set(new_pos.x, new_pos.y, new_pos.z)

	var/obj/docking_port/stationary/current_dock = shuttle_port.get_docked()
	if(!current_dock)
		if(docked_at)
			docked_at = null
		return "Error: Shuttle not physically docked"

	if(!original_dock)
		original_dock = current_dock

	if(!shuttle_port.assigned_transit)
		var/success = SSshuttle.generate_transit_dock(shuttle_port)
		if(!success)
			docked_at = null
			return "Error: Failed to generate transit dock"

	var/docking_result = shuttle_port.initiate_docking(shuttle_port.assigned_transit)
	if(docking_result != DOCKING_SUCCESS)
		docked_at = null
		stack_trace("Failed to move shuttle [shuttle_port.shuttle_id] to transit dock. Error code: [docking_result]")
		return "Error: Failed to move shuttle to transit ([docking_result])"

	docked_at = null
	return null

/datum/orbital_object/shuttle/proc/get_nearby_stations()
	var/list/nearby = list()
	if(!star_system)
		return nearby
	for(var/datum/orbital_object/station/station in star_system.get_stations())
		if(station.in_docking_range(src))
			nearby += station
	return nearby

/datum/orbital_object/shuttle/proc/get_nearby_objects(interaction_range = 30)
	var/list/nearby = list()
	if(!star_system)
		return nearby
	for(var/datum/orbital_object/obj in star_system.orbital_objects)
		if(obj == src)
			continue
		if(position.DistanceTo(obj.position) <= interaction_range)
			nearby += obj
	return nearby

/datum/orbital_object/shuttle/proc/jump_to_system(system_id, mob/user)
	if(!has_jump_drive)
		return "This shuttle does not have a jump drive installed"
	if(is_jumping)
		return "Jump drive is already charging"
	if(docked_at || is_docking)
		return "Cannot jump while docked - undock first"

	var/time_since_jump = (world.time - last_jump_time)
	if(time_since_jump < jump_cooldown)
		var/remaining = jump_cooldown - time_since_jump
		return "Jump drive is cooling down - [round(remaining)] seconds remaining"

	if(!star_system)
		return "Error: Shuttle is not in a star system"

	var/datum/overmap_star_system/target_system = SSsupercruise.get_system(system_id)
	if(!target_system)
		return "Error: Target system not found"
	if(target_system == star_system)
		return "Already in target system"

	is_jumping = TRUE
	if(user)
		to_chat(user, span_notice("Initiating jump to [target_system.system_name]..."))

	var/jump_result = SSsupercruise.move_to_system(src, target_system, position.x, position.y, position.z)
	if(!jump_result)
		is_jumping = FALSE
		return "Error: Failed to execute jump"

	last_jump_time = world.time
	is_jumping = FALSE

	if(user)
		to_chat(user, span_notice("Jump complete! Now in [target_system.system_name]."))
	return null

/datum/orbital_object/shuttle/proc/get_jump_destinations()
	if(!star_system)
		return list()
	var/list/destinations = list()
	for(var/system_id in SSsupercruise.star_systems)
		var/datum/overmap_star_system/system = SSsupercruise.star_systems[system_id]
		if(system == star_system || !system.can_jump)
			continue
		destinations += list(list(
			"id" = system.system_id,
			"name" = system.system_name,
			"description" = system.system_description
		))
	return destinations
