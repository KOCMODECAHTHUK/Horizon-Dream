// В начале файла orbital_shuttle.dm
#define SAS_OFF 0
#define SAS_PROGRADE 1
#define SAS_RETROGRADE 2
#define SAS_TARGET 3
#define SAS_HOLD 4

#define RCS_OFF 0
#define RCS_TRANSLATE 1
#define RCS_HOLD_POS 2

#define AUTOPILOT_OFF 0
#define AUTOPILOT_TRAVEL 1
#define AUTOPILOT_ORBIT 2
#define AUTOPILOT_HOLD 3

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

	var/sas_mode = 0
	var/rcs_mode = 0
	var/datum/orbital_vector/rcs_target_velocity = new()

/datum/orbital_object/shuttle/process(seconds_per_tick)
	var/obj/docking_port/stationary/current_dock = shuttle_port?.get_docked()
	var/is_in_transit = istype(current_dock, /obj/docking_port/stationary/transit)
	var/is_docked = (docked_at != null) || (current_dock && !is_in_transit)

	if(is_docked)
		velocity.Set(0, 0, 0)
		thrust.Set(0, 0, 0)
		thrust_power = 0
		autopilot_mode = AUTOPILOT_OFF
		sas_mode = SAS_OFF
		rcs_mode = RCS_OFF
		has_target_position = FALSE
		has_pending_target = FALSE
		rcs_power = 0
		return

	// История для следа
	position_history += list(position.x, position.y, position.z)
	if(length(position_history) > max_history)
		position_history.Cut(1, 4)

	// 1. Ручное вращение (только если нет SAS)
	if(sas_mode == 0 && autopilot_mode == 0)
		handle_manual_rotation(seconds_per_tick)

	// 2. SAS — стабилизация ориентации (высший приоритет над ручным курсом)
	if(sas_mode > 0)
		update_sas(seconds_per_tick)

	// 3. Автопилот — навигация и тяга
	if(autopilot_mode > 0)
		handle_autopilot(seconds_per_tick)

	// 4. RCS — маневровые двигатели
	if(rcs_power > 0 && rcs_mode > 0)
		handle_rcs(seconds_per_tick)

	// 5. Основная тяга
	if(thrust_power > 0)
		var/dir_mag = thrust.Length()
		if(dir_mag > 0.001)
			var/datum/orbital_vector/norm_thrust = thrust.GetNormalized()
			var/effective_accel = (thrust_power / 100) * acceleration
			velocity.AddSelf(norm_thrust.ScaleSelf(effective_accel * seconds_per_tick))

	// 6. Гравитация и коллизии
	. = ..(seconds_per_tick)

	// 7. Лимит скорости
	var/current_speed = velocity.Length()
	if(current_speed > max_speed && current_speed > 0)
		velocity.ScaleSelf(max_speed / current_speed)

	check_collisions()

/datum/orbital_object/shuttle/proc/handle_manual_rotation(seconds_per_tick)
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


/datum/orbital_object/shuttle/proc/update_sas(seconds_per_tick)
	var/target_yaw = heading
	var/target_pitch = heading_pitch

	switch(sas_mode)
		if(SAS_PROGRADE)
			if(velocity.Length() > 0.5)
				var/datum/orbital_vector/n = velocity.GetNormalized()
				target_yaw = ATAN2(n.y, n.x)
				if(target_yaw < 0) target_yaw += 360
				target_pitch = ATAN2(n.z, sqrt(n.x*n.x + n.y*n.y))
		if(SAS_RETROGRADE)
			if(velocity.Length() > 0.5)
				var/datum/orbital_vector/n = velocity.GetNormalized()
				target_yaw = ATAN2(-n.y, -n.x)
				if(target_yaw < 0) target_yaw += 360
				target_pitch = ATAN2(-n.z, sqrt(n.x*n.x + n.y*n.y))
		if(SAS_TARGET)
			if(target_object_id)
				var/datum/orbital_object/T = SSsupercruise.find_object(target_object_id, star_system)
				if(T)
					var/datum/orbital_vector/d = T.position.Subtract(position)
					var/datum/orbital_vector/n = d.GetNormalized()
					target_yaw = ATAN2(n.y, n.x)
					if(target_yaw < 0) target_yaw += 360
					target_pitch = ATAN2(n.z, sqrt(n.x*n.x + n.y*n.y))
		if(SAS_HOLD)
			return // не меняем курс

	// Плавный поворот (SAS в 3 раза быстрее ручного)
	var/yaw_diff = MODULUS(target_yaw - heading, 360)
	if(yaw_diff > 180) yaw_diff -= 360
	var/pitch_diff = target_pitch - heading_pitch
	var/max_turn = rotation_rate * seconds_per_tick * 3

	if(abs(yaw_diff) > 0.1)
		heading += clamp(yaw_diff, -max_turn, max_turn)
		heading = MODULUS(heading, 360)
	if(abs(pitch_diff) > 0.1)
		heading_pitch += clamp(pitch_diff, -max_turn, max_turn)
		heading_pitch = clamp(heading_pitch, -90, 90)

	// Синхронизируем двигатель с носом (пока нет gimbal)
	thrust_angle = heading
	thrust_pitch = heading_pitch
	var/hc = cos(heading_pitch)
	thrust.Set(cos(heading) * hc, sin(heading) * hc, sin(heading_pitch))

/datum/orbital_object/shuttle/proc/handle_rcs(seconds_per_tick)
	if(rcs_mode == RCS_TRANSLATE)
		var/yaw = TORADIANS(heading)
		var/pitch = TORADIANS(heading_pitch)
		var/cy = cos(yaw), sy = sin(yaw)
		var/cp = cos(pitch), sp = sin(pitch)

		// Локальные оси корабля
		var/datum/orbital_vector/fwd = new(cy*cp, sy*cp, sp)
		var/datum/orbital_vector/right = new(sy, -cy, 0)
		var/datum/orbital_vector/up = new(-cy*sp, -sy*sp, cp)

		var/datum/orbital_vector/rcs_world = new()
		rcs_world.AddSelf(right.Scale(rcs_strafe.x))
		rcs_world.AddSelf(up.Scale(rcs_strafe.y))
		rcs_world.AddSelf(fwd.Scale(rcs_strafe.z))

		var/mag = rcs_world.Length()
		if(mag > 0.001)
			var/acc = (rcs_power / 100) * acceleration * 0.35 * seconds_per_tick
			velocity.AddSelf(rcs_world.Scale(acc / mag))

	else if(rcs_mode == RCS_HOLD_POS)
		if(!target_object_id) return
		var/datum/orbital_object/target = SSsupercruise.find_object(target_object_id, star_system)
		if(!target) return

		var/datum/orbital_vector/desired_vel = target.velocity.Copy()
		var/datum/orbital_vector/err_vel = desired_vel.Subtract(velocity)
		var/ev_mag = err_vel.Length()
		if(ev_mag > 0.2)
			var/datum/orbital_vector/n = err_vel.GetNormalized()
			var/acc = acceleration * 0.4 * seconds_per_tick
			velocity.AddSelf(n.Scale(min(ev_mag, acc)))

/**
 * Полностью векторный автопилот. Без арктангенсов и спагетти.
 */
/datum/orbital_object/shuttle/proc/handle_autopilot(seconds_per_tick)
	var/datum/orbital_object/target = null
	if(target_object_id)
		target = SSsupercruise.find_object(target_object_id, star_system)
		if(!target)
			autopilot_mode = AUTOPILOT_OFF
			target_object_id = null
			kill_thrust()
			return

	var/datum/orbital_vector/t_pos = target ? target.position : target_pos
	var/datum/orbital_vector/delta = t_pos.Subtract(position)
	var/distance = delta.Length()

	switch(autopilot_mode)
		if(AUTOPILOT_TRAVEL) // 1
			if(distance < arrival_threshold)
				autopilot_mode = AUTOPILOT_HOLD
				kill_thrust()
				return

			var/current_speed = velocity.Length()
			// Тормозной путь с запасом
			var/brake_dist = (current_speed * current_speed) / (2 * acceleration * 0.5)
			var/desired_speed = max_speed
			if(distance < brake_dist + arrival_threshold * 3)
				desired_speed = max(2, (distance / max(brake_dist, 1)) * max_speed * 0.2)

			var/datum/orbital_vector/norm_delta = delta.GetNormalized()
			var/datum/orbital_vector/target_vel = target ? target.velocity.Copy() : new()
			var/datum/orbital_vector/desired_velocity = norm_delta.Scale(desired_speed)
			desired_velocity.AddSelf(target_vel)

			// Упреждение гравитации (простое)
			if(star_system?.central_star)
				var/datum/orbital_vector/gdir = star_system.central_star.position.Subtract(position)
				var/gdist = gdir.Length()
				if(gdist > 0.1)
					var/gpull = star_system.central_star.mass / (gdist * gdist)
					desired_velocity.AddSelf(gdir.GetNormalized().Scale(gpull * 3))

			var/datum/orbital_vector/steer = desired_velocity.Subtract(velocity)
			var/steer_mag = steer.Length()

			if(steer_mag > 0.2)
				var/datum/orbital_vector/ns = steer.GetNormalized()
				var/power = clamp((steer_mag / acceleration) * 70 + 30, 20, 100)
				set_thrust_3d(ns.x, ns.y, ns.z, power)
				// Автопилот сам управляет ориентацией
				heading = thrust_angle
				heading_pitch = thrust_pitch
			else
				kill_thrust()

		if(AUTOPILOT_ORBIT) // 2 — НОВЫЙ РЕЖИМ
			if(!target)
				autopilot_mode = AUTOPILOT_OFF
				return

			var/datum/orbital_vector/to_target = target.position.Subtract(position)
			var/dist = to_target.Length()
			var/datum/orbital_vector/radial = to_target.GetNormalized()

			// Тангенциальный вектор (перпендикуляр в XY)
			var/inc = 0
			var/datum/orbital_vector/tangential = new(-radial.y, radial.x, 0)
			if(istype(target, /datum/orbital_object/planet))
				var/datum/orbital_object/planet/P = target
				inc = TORADIANS(P.orbit_inclination)
				tangential.z = sin(inc) * 0.3

			// Орбитальная скорость: v = sqrt(GM/r). У вас нет G, подбираем коэффициент:
			var/orbital_speed = sqrt(target.mass / max(target_orbit_radius, 1)) * 3.5

			// Коррекция радиуса
			var/alt_error = dist - target_orbit_radius
			var/datum/orbital_vector/desired_vel = target.velocity.Copy()
			desired_vel.AddSelf(tangential.Scale(orbital_speed))
			desired_vel.AddSelf(radial.Scale(-clamp(alt_error * 0.4, -8, 8)))

			var/datum/orbital_vector/steer = desired_vel.Subtract(velocity)
			var/steer_mag = steer.Length()

			if(steer_mag > 0.3)
				var/datum/orbital_vector/ns = steer.GetNormalized()
				var/power = clamp((steer_mag / acceleration) * 60 + 20, 15, 100)
				set_thrust_3d(ns.x, ns.y, ns.z, power)
				heading = thrust_angle
				heading_pitch = thrust_pitch
			else
				kill_thrust()
				sas_mode = SAS_PROGRADE // в орбите стабилизируемся

		if(AUTOPILOT_HOLD) // 3
			var/datum/orbital_vector/norm_delta = delta.GetNormalized()
			var/datum/orbital_vector/desired_pos = target ? t_pos.Subtract(norm_delta.Scale(target_orbit_radius)) : t_pos.Copy()

			var/datum/orbital_vector/error = desired_pos.Subtract(position)
			var/err_mag = error.Length()

			var/datum/orbital_vector/target_vel = target ? target.velocity.Copy() : new()
			var/datum/orbital_vector/rvel = velocity.Subtract(target_vel)
			var/rvel_mag = rvel.Length()

			// Двухфазный: сначала гасим скорость, потом дрейфуем к точке
			if(rvel_mag > 1.5)
				var/datum/orbital_vector/nr = rvel.GetNormalized()
				set_thrust_3d(-nr.x, -nr.y, -nr.z, 40)
			else if(err_mag > 2)
				var/datum/orbital_vector/ne = error.GetNormalized()
				set_thrust_3d(ne.x, ne.y, ne.z, 25)
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
	thrust_angle = ATAN2(thrust.y, thrust.x)
	if(thrust_angle < 0) thrust_angle += 360

	var/horizontal_mag = sqrt(thrust.x*thrust.x + thrust.y*thrust.y)
	if(horizontal_mag < 0.001)
		thrust_pitch = thrust.z > 0 ? 90 : -90
	else
		thrust_pitch = ATAN2(thrust.z, horizontal_mag)

	if(sas_mode == 0 && autopilot_mode == 0 && !rotating_left && !rotating_right && !rotating_pitch_up && !rotating_pitch_down)
		heading = thrust_angle
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
